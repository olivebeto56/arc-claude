/**
 * ble_service.cpp — BLE GATT service implementation
 *
 * Implements the four-characteristic GATT service.
 * CONFIG_CHAR allows the Flutter app to override the automatic activity
 * detection and force a specific sample rate.
 */

#include "ble_service.h"

// ─── UUIDs ────────────────────────────────────────────────────────────────────
#define SERVICE_UUID      "19B10000-E8F2-537E-4F6C-D104768A1214"
#define SENSOR_CHAR_UUID  "19B10001-E8F2-537E-4F6C-D104768A1214"
#define BATTERY_CHAR_UUID "19B10002-E8F2-537E-4F6C-D104768A1214"
#define CONFIG_CHAR_UUID  "19B10003-E8F2-537E-4F6C-D104768A1214"
#define STATUS_CHAR_UUID  "19B10004-E8F2-537E-4F6C-D104768A1214"

// ─── GATT objects ─────────────────────────────────────────────────────────────
static BLEService sensorService(SERVICE_UUID);

// 16 bytes: packed BLEPacket (orientation + acceleration)
static BLECharacteristic sensorChar(SENSOR_CHAR_UUID,
                                    BLERead | BLENotify, 16);

// 1 byte: battery percentage
static BLEByteCharacteristic batteryChar(BATTERY_CHAR_UUID, BLERead);

// 1 byte: config/override written by Flutter app
static BLEByteCharacteristic configChar(CONFIG_CHAR_UUID, BLEWrite);

// 1 byte: current mode (0=IDLE, 1=ACTIVE) — notified on change
static BLEByteCharacteristic statusChar(STATUS_CHAR_UUID,
                                        BLERead | BLENotify);

// ─── Module-private state ─────────────────────────────────────────────────────
static uint8_t _lastConfigByte = CONFIG_MODE_AUTO;

// ─── Helpers ──────────────────────────────────────────────────────────────────

static inline int16_t floatToQ(float v) {
  return (int16_t)(v * 10000.0f);
}

static inline int16_t accelToMg(float mps2) {
  // 1 m/s² = 101.97 mg — approximate to 102 for speed
  return (int16_t)(mps2 * 102.0f);
}

// ─── Public API ───────────────────────────────────────────────────────────────

bool initBLE(const char* deviceName) {
  if (!BLE.begin()) {
    Serial.println("[ble] ERROR: BLE init failed");
    return false;
  }

  BLE.setLocalName(deviceName);
  BLE.setAdvertisedService(sensorService);

  sensorService.addCharacteristic(sensorChar);
  sensorService.addCharacteristic(batteryChar);
  sensorService.addCharacteristic(configChar);
  sensorService.addCharacteristic(statusChar);

  BLE.addService(sensorService);

  // Set initial values so central can read them immediately on connect
  batteryChar.writeValue((uint8_t)0);
  statusChar.writeValue((uint8_t)MODE_ACTIVE);
  _lastConfigByte = CONFIG_MODE_AUTO;

  BLE.advertise();

  Serial.print("[ble] Advertising as: ");
  Serial.println(deviceName);
  return true;
}

uint8_t bleLoop() {
  BLE.poll();  // process BLE stack events (required every loop)

  // Check for a new write on CONFIG_CHAR from the app
  if (configChar.written()) {
    uint8_t val = configChar.value();
    if (val != _lastConfigByte) {
      _lastConfigByte = val;
      Serial.print("[ble] CONFIG_CHAR written: 0x");
      Serial.println(val, HEX);
      return val;
    }
  }

  return _lastConfigByte;
}

void bleSendSensorData(const SensorAngles& angles, uint32_t sessionStart) {
  if (!BLE.connected()) return;

  BLEPacket pkt;
  pkt.timestamp_ms = (uint16_t)((millis() - sessionStart) & 0xFFFF);
  pkt.qw      = floatToQ(angles.qw);
  pkt.qx      = floatToQ(angles.qx);
  pkt.qy      = floatToQ(angles.qy);
  pkt.qz      = floatToQ(angles.qz);
  pkt.accel_x = accelToMg(angles.accel_x);
  pkt.accel_y = accelToMg(angles.accel_y);
  pkt.accel_z = accelToMg(angles.accel_z);

  sensorChar.writeValue((uint8_t*)&pkt, sizeof(pkt));
}

void bleSendBattery(uint8_t percent) {
  batteryChar.writeValue(percent);
}

void bleSendStatus(ActivityMode mode) {
  statusChar.writeValue((uint8_t)mode);

  Serial.print("[ble] Status notified: ");
  Serial.println(mode == MODE_ACTIVE ? "ACTIVE (100 Hz)" : "IDLE (25 Hz)");
}

bool bleConnected() {
  return BLE.connected();
}
