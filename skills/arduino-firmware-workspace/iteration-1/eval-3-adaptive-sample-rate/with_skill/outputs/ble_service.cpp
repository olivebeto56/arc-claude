// ble_service.cpp — BLE GATT service implementation
// Wearable Sport Monitor — Running Node

#include "ble_service.h"

// ------------------------------------------------------------------
// UUIDs — unique to this project (generated via uuidgenerator.net)
// Change if you deploy multiple independent wearable products.
// ------------------------------------------------------------------
#define SERVICE_UUID      "19B10000-E8F2-537E-4F6C-D104768A1214"
#define SENSOR_CHAR_UUID  "19B10001-E8F2-537E-4F6C-D104768A1214"
#define BATTERY_CHAR_UUID "19B10002-E8F2-537E-4F6C-D104768A1214"
#define CONFIG_CHAR_UUID  "19B10003-E8F2-537E-4F6C-D104768A1214"

// GATT objects
static BLEService         sensorService(SERVICE_UUID);
static BLECharacteristic  sensorChar(SENSOR_CHAR_UUID, BLERead | BLENotify, sizeof(BLEPacket));
static BLEByteCharacteristic batteryChar(BATTERY_CHAR_UUID, BLERead);
static BLEByteCharacteristic configChar(CONFIG_CHAR_UUID, BLEWrite);

// Pending config request from Flutter app (0 = none pending)
static uint8_t pendingConfigHz = 0;

// ------------------------------------------------------------------
// initBLE
// ------------------------------------------------------------------
bool initBLE(const char* deviceName) {
  if (!BLE.begin()) {
    Serial.println("ERROR: BLE init failed");
    return false;
  }

  BLE.setLocalName(deviceName);
  BLE.setAdvertisedService(sensorService);

  sensorService.addCharacteristic(sensorChar);
  sensorService.addCharacteristic(batteryChar);
  sensorService.addCharacteristic(configChar);

  BLE.addService(sensorService);

  // Initial battery value
  batteryChar.writeValue((uint8_t)0);

  BLE.advertise();

  Serial.print("BLE advertising as: ");
  Serial.println(deviceName);
  return true;
}

// ------------------------------------------------------------------
// pollBLE
// ------------------------------------------------------------------
void pollBLE() {
  BLE.poll();

  // Check if the Flutter app wrote a new sample rate request
  if (configChar.written()) {
    uint8_t val = configChar.value();
    // Protocol: 1 = force 25 Hz, 2 = force 100 Hz
    if (val == 1 || val == 2) {
      pendingConfigHz = (val == 1) ? 25 : 100;
      Serial.print("Config request received: ");
      Serial.print(pendingConfigHz);
      Serial.println(" Hz");
    }
  }
}

// ------------------------------------------------------------------
// sendSensorData
// ------------------------------------------------------------------
bool sendSensorData(const SensorAngles& angles, uint32_t sessionStartMs) {
  if (!BLE.connected()) return false;

  BLEPacket pkt;

  // Relative timestamp (rolls over after ~65 seconds — sufficient for
  // a single BLE notification window; session start is tracked in app)
  pkt.timestamp_ms = (uint16_t)((millis() - sessionStartMs) & 0xFFFF);

  // Scale quaternion components to int16 (x10000 preserves 4 decimal places)
  pkt.qw = (int16_t)(angles.qw * 10000.0f);
  pkt.qx = (int16_t)(angles.qx * 10000.0f);
  pkt.qy = (int16_t)(angles.qy * 10000.0f);
  pkt.qz = (int16_t)(angles.qz * 10000.0f);

  // Convert m/s² → milli-g (1 g = 9810 mg)
  // int16 range: ±32767 mg ≈ ±3.3 g — sufficient for running (peak ~1.5 g)
  pkt.accel_x = (int16_t)(angles.accel_x * (1000.0f / 9.81f));
  pkt.accel_y = (int16_t)(angles.accel_y * (1000.0f / 9.81f));
  pkt.accel_z = (int16_t)(angles.accel_z * (1000.0f / 9.81f));

  sensorChar.writeValue((uint8_t*)&pkt, sizeof(pkt));
  return true;
}

// ------------------------------------------------------------------
// updateBattery
// ------------------------------------------------------------------
void updateBattery(uint8_t percent) {
  batteryChar.writeValue(percent);
}

// ------------------------------------------------------------------
// isBLEConnected
// ------------------------------------------------------------------
bool isBLEConnected() {
  return BLE.connected();
}

// ------------------------------------------------------------------
// consumeConfigRequest
// ------------------------------------------------------------------
uint8_t consumeConfigRequest() {
  uint8_t val = pendingConfigHz;
  pendingConfigHz = 0;
  return val;
}
