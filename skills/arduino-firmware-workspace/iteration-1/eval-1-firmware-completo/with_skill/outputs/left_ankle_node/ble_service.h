/**
 * ble_service.h
 *
 * BLE GATT service definition for the wearable sport monitor node.
 *
 * Service layout:
 *   - Sensor Characteristic (NOTIFY, 14 bytes):
 *       Sends packed quaternion + linear accel + timestamp at sensor rate.
 *   - Battery Characteristic (READ, 1 byte):
 *       Battery level 0–100% updated every 10 seconds.
 *   - Config Characteristic (WRITE, 1 byte):
 *       Allows the mobile app to change the sample rate at runtime.
 *
 * Packet format (14 bytes, fits in default BLE MTU of 20 bytes):
 *   [0..1]  uint16_t  timestamp_ms  — session-relative ms (wraps at 65535)
 *   [2..3]  int16_t   qw            — quaternion W × 10000
 *   [4..5]  int16_t   qx            — quaternion X × 10000
 *   [6..7]  int16_t   qy            — quaternion Y × 10000
 *   [8..9]  int16_t   qz            — quaternion Z × 10000
 *   [10..11] int16_t  accel_x       — linear accel X in milli-g
 *   [12..13] int16_t  accel_y       — linear accel Y in milli-g
 *   [14..15] int16_t  accel_z       — linear accel Z in milli-g
 *                                     Total: 16 bytes
 *
 * Note: accel fields added (+2 bytes vs SKILL.md baseline) to deliver
 * running cadence data — still under 20-byte MTU.
 */

#ifndef BLE_SERVICE_H
#define BLE_SERVICE_H

#include <ArduinoBLE.h>
#include "sensor.h"
#include <stdint.h>

// ─── GATT UUIDs ───────────────────────────────────────────────────────────────
// Generated at https://www.uuidgenerator.net/
// These UUIDs are unique to this project — do not reuse across other projects.

#define SERVICE_UUID          "19B10000-E8F2-537E-4F6C-D104768A1214"
#define SENSOR_CHAR_UUID      "19B10001-E8F2-537E-4F6C-D104768A1214"
#define BATTERY_CHAR_UUID     "19B10002-E8F2-537E-4F6C-D104768A1214"
#define CONFIG_CHAR_UUID      "19B10003-E8F2-537E-4F6C-D104768A1214"

// ─── PACKED BLE DATA PACKET ───────────────────────────────────────────────────

/**
 * BLEPacket — wire format sent in the Sensor Characteristic.
 *
 * All multi-byte integers are little-endian (native nRF52840 byte order).
 * Quaternion components are scaled × 10000 to preserve 4 decimal places
 * as signed 16-bit integers without floating-point in the app parser.
 *
 * Acceleration is in milli-g (1 g = 9.81 m/s^2; 1000 milli-g = 1 g).
 */
struct __attribute__((packed)) BLEPacket {
  uint16_t timestamp_ms;  // 2 bytes — session-relative timestamp
  int16_t  qw;            // 2 bytes — quaternion W × 10000
  int16_t  qx;            // 2 bytes — quaternion X × 10000
  int16_t  qy;            // 2 bytes — quaternion Y × 10000
  int16_t  qz;            // 2 bytes — quaternion Z × 10000
  int16_t  accel_x;       // 2 bytes — linear acceleration X, milli-g
  int16_t  accel_y;       // 2 bytes — linear acceleration Y, milli-g
  int16_t  accel_z;       // 2 bytes — linear acceleration Z, milli-g
                          // ─────────────────────────────────
                          // Total: 16 bytes (fits in 20-byte MTU)
};

// ─── CONFIG VALUES (written by mobile app to Config Characteristic) ───────────

#define CONFIG_RATE_25HZ   0x01   // 25 Hz  — idle / low activity
#define CONFIG_RATE_100HZ  0x02   // 100 Hz — running / gym (default)
#define CONFIG_RATE_200HZ  0x03   // 200 Hz — golf swing (requires SPI for BNO085)

// ─── PUBLIC API ───────────────────────────────────────────────────────────────

/**
 * initBLEService(deviceName, initialBatteryPct)
 * Sets up the BLE stack, GATT service, all characteristics, and starts
 * advertising. Must be called once in setup() after sensor is initialized.
 *
 * deviceName: BLE local name visible during scan (e.g., "SportBand-L")
 * initialBatteryPct: initial battery value to populate before first connection
 */
void initBLEService(const char* deviceName, uint8_t initialBatteryPct);

/**
 * sendSensorData(timestamp, angles)
 * Packs a SensorAngles struct into a BLEPacket and writes it to the
 * Sensor Characteristic with BLE notification.
 *
 * Only sends if a central is subscribed (has enabled notifications).
 * Non-blocking — does NOT wait for the BLE stack to confirm delivery.
 */
void sendSensorData(uint16_t timestamp, const SensorAngles& angles);

/**
 * updateBatteryCharacteristic(pct)
 * Updates the Battery Characteristic value. The central can read this
 * at any time; it is NOT notified (read-only characteristic).
 */
void updateBatteryCharacteristic(uint8_t pct);

/**
 * handleConfigWrite()
 * Checks if the central wrote a new value to the Config Characteristic.
 * If a valid config byte is received, updates the BNO085 sample rate
 * by calling enableSensorReports() with the new interval.
 *
 * Must be called on every loop iteration while a central is connected.
 */
void handleConfigWrite();

#endif // BLE_SERVICE_H
