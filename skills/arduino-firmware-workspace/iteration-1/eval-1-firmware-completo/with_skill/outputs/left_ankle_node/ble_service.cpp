/**
 * ble_service.cpp
 *
 * BLE GATT service implementation for the wearable sport monitor node.
 * Implements the ble_service.h interface using ArduinoBLE.
 *
 * Architecture:
 *   - Three GATT characteristics under one custom service.
 *   - Sensor data is NOTIFY-based (push from node to phone).
 *   - Battery is READ-only (phone polls on demand).
 *   - Config is WRITE-only (phone sends new sample rate to node).
 *
 * Scaling conventions for the wire format:
 *   - Quaternion: float → int16_t by multiplying by 10000
 *     Example: qw=0.9848 → stored as 9848
 *   - Acceleration: m/s^2 → milli-g by dividing by 9.81 and multiplying by 1000
 *     Example: ax=2.5 m/s^2 → 2500/9.81 ≈ 254 milli-g
 */

#include "ble_service.h"
#include "sensor.h"
#include <ArduinoBLE.h>
#include <Arduino.h>

// ─── GATT OBJECTS ─────────────────────────────────────────────────────────────

// Primary service
static BLEService _sensorService(SERVICE_UUID);

// Characteristic 1: sensor data with BLE notifications (16 bytes payload)
static BLECharacteristic _sensorChar(
  SENSOR_CHAR_UUID,
  BLERead | BLENotify,
  sizeof(BLEPacket)
);

// Characteristic 2: battery level 0–100% (read-only, 1 byte)
static BLEByteCharacteristic _batteryChar(
  BATTERY_CHAR_UUID,
  BLERead
);

// Characteristic 3: configuration byte (write-only from central)
static BLEByteCharacteristic _configChar(
  CONFIG_CHAR_UUID,
  BLEWrite
);

// ─── MODULE STATE ─────────────────────────────────────────────────────────────

// Track the last config byte seen to avoid re-applying unchanged config
static uint8_t _lastConfigByte = CONFIG_RATE_100HZ;

// ─── PRIVATE HELPERS ──────────────────────────────────────────────────────────

/**
 * _applySampleRate(configByte)
 * Translates a CONFIG_RATE_* byte into a sensor report interval
 * and re-enables BNO085 reports at the new rate.
 *
 * Note: 200 Hz via I2C may not be achievable — BNO085 I2C practical
 * ceiling is ~250 Hz but jitter increases above 150 Hz. SPI recommended
 * for 200 Hz in a future hardware revision.
 */
static void _applySampleRate(uint8_t configByte) {
  uint32_t intervalUs = 10000;  // Default: 100 Hz

  switch (configByte) {
    case CONFIG_RATE_25HZ:
      intervalUs = 40000;  // 25 Hz (idle)
      break;
    case CONFIG_RATE_100HZ:
      intervalUs = 10000;  // 100 Hz (running)
      break;
    case CONFIG_RATE_200HZ:
      intervalUs = 5000;   // 200 Hz (golf) — may be limited by I2C
      break;
    default:
      // Unknown config byte — ignore and keep current rate
      Serial.print("BLE config: unknown byte 0x");
      Serial.println(configByte, HEX);
      return;
  }

  Serial.print("BLE config: new sample rate interval ");
  Serial.print(intervalUs);
  Serial.println(" µs");

  // enableSensorReports() re-arms the BNO085 reports at the new interval
  enableSensorReports();
  // Note: enableSensorReports() currently uses the compile-time REPORT_INTERVAL_US.
  // For dynamic rate changes, refactor enableSensorReports() to accept a parameter.
}

// ─── PUBLIC IMPLEMENTATION ────────────────────────────────────────────────────

void initBLEService(const char* deviceName, uint8_t initialBatteryPct) {
  if (!BLE.begin()) {
    Serial.println("FATAL: ArduinoBLE init failed");
    while (1);  // Halt — BLE is required for this application
  }

  // Set the device name that will appear in BLE scans
  BLE.setLocalName(deviceName);
  BLE.setDeviceName(deviceName);

  // Associate the service with the first (primary) advertised service UUID
  BLE.setAdvertisedService(_sensorService);

  // Add all characteristics to the service
  _sensorService.addCharacteristic(_sensorChar);
  _sensorService.addCharacteristic(_batteryChar);
  _sensorService.addCharacteristic(_configChar);

  // Register the service with the BLE stack
  BLE.addService(_sensorService);

  // Seed the battery characteristic with the current reading
  _batteryChar.writeValue(initialBatteryPct);

  // Pre-initialize the config characteristic with the default rate
  _configChar.writeValue(CONFIG_RATE_100HZ);
  _lastConfigByte = CONFIG_RATE_100HZ;

  // Write an initial zero-payload to the sensor characteristic
  // (some centrals require a value to be set before subscribing)
  BLEPacket zeroPkt = {};
  _sensorChar.writeValue((uint8_t*)&zeroPkt, sizeof(BLEPacket));

  // Start advertising — the central (Flutter app) will scan and connect
  BLE.advertise();

  Serial.print("BLE GATT service ready. Advertising as: ");
  Serial.println(deviceName);
  Serial.print("  Service UUID:  "); Serial.println(SERVICE_UUID);
  Serial.print("  Sensor UUID:   "); Serial.println(SENSOR_CHAR_UUID);
  Serial.print("  Battery UUID:  "); Serial.println(BATTERY_CHAR_UUID);
  Serial.print("  Config UUID:   "); Serial.println(CONFIG_CHAR_UUID);
}

void sendSensorData(uint16_t timestamp, const SensorAngles& angles) {
  // Build the compact BLE packet
  BLEPacket pkt;

  pkt.timestamp_ms = timestamp;

  // Scale quaternion from float [-1,1] to int16 [-10000, 10000]
  pkt.qw = (int16_t)(angles.qw * 10000.0f);
  pkt.qx = (int16_t)(angles.qx * 10000.0f);
  pkt.qy = (int16_t)(angles.qy * 10000.0f);
  pkt.qz = (int16_t)(angles.qz * 10000.0f);

  // Scale acceleration from m/s^2 to milli-g
  // 1 g = 9.80665 m/s^2; milli-g = (m/s^2 / 9.80665) * 1000
  const float MS2_TO_MG = 1000.0f / 9.80665f;
  pkt.accel_x = (int16_t)(angles.accel_x * MS2_TO_MG);
  pkt.accel_y = (int16_t)(angles.accel_y * MS2_TO_MG);
  pkt.accel_z = (int16_t)(angles.accel_z * MS2_TO_MG);

  // Write value — ArduinoBLE will send a BLE notification to all
  // subscribed centrals automatically when BLENotify is set
  _sensorChar.writeValue((uint8_t*)&pkt, sizeof(BLEPacket));
}

void updateBatteryCharacteristic(uint8_t pct) {
  _batteryChar.writeValue(pct);
}

void handleConfigWrite() {
  // Check if the central wrote a new value to the config characteristic
  if (_configChar.written()) {
    uint8_t newConfig = _configChar.value();

    if (newConfig != _lastConfigByte) {
      _lastConfigByte = newConfig;
      _applySampleRate(newConfig);
    }
  }
}
