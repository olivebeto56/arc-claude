// ble_service.h — BLE GATT service interface
// Wearable Sport Monitor — Running Node
//
// Service exposes three characteristics:
//   1. sensorChar  (NOTIFY)  — packed IMU data, 14 bytes per packet
//   2. batteryChar (READ)    — battery percentage 0–100
//   3. configChar  (WRITE)   — sample rate override from Flutter app
//
// The configChar allows the Flutter app to manually force a sample
// rate (1 byte: '1' = 25 Hz idle, '2' = 100 Hz active). The node's
// adaptive logic still runs; this just overrides the current rate.

#pragma once

#include <Arduino.h>
#include <ArduinoBLE.h>
#include "sensor.h"

// ------------------------------------------------------------------
// BLE Packed Data Packet (14 bytes — fits BLE 4.2 default MTU of 20)
// ------------------------------------------------------------------
struct __attribute__((packed)) BLEPacket {
  uint16_t timestamp_ms;  // 2 bytes — ms elapsed since session start
  int16_t  qw;            // 8 bytes — quaternion scaled x10000
  int16_t  qx;
  int16_t  qy;
  int16_t  qz;
  int16_t  accel_x;       // 6 bytes — linear accel in milli-g (1 g = 9.81 m/s²)
  int16_t  accel_y;
  int16_t  accel_z;
                          // Total: 14 bytes
};

// ------------------------------------------------------------------
// Public API
// ------------------------------------------------------------------

// Initialize BLE stack, build service, start advertising.
// deviceName: e.g., "SportBand-L" or "SportBand-R"
bool initBLE(const char* deviceName);

// Must be called every loop iteration to service BLE events and
// handle incoming configChar writes.
void pollBLE();

// Send a sensor sample over BLE NOTIFY if a central is connected.
// Returns true if the packet was delivered.
bool sendSensorData(const SensorAngles& angles, uint32_t sessionStartMs);

// Update the battery characteristic (call every ~10 seconds).
void updateBattery(uint8_t percent);

// Returns true if a BLE central (Flutter app) is currently connected.
bool isBLEConnected();

// Returns the sample rate (Hz) requested via configChar, or 0 if no
// override has been received. Caller should reset after reading.
uint8_t consumeConfigRequest();
