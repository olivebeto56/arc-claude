/**
 * ble_service.h — BLE GATT service for the running wearable node
 *
 * Service UUID:   19B10000-E8F2-537E-4F6C-D104768A1214
 * Characteristics:
 *   SENSOR_CHAR  (Notify, 14 bytes) — packed orientation + acceleration
 *   BATTERY_CHAR (Read,   1 byte)   — battery % (0-100)
 *   CONFIG_CHAR  (Write,  1 byte)   — activity mode override
 *                                     0x00 = auto (default)
 *                                     0x01 = force ACTIVE (100 Hz)
 *                                     0x02 = force IDLE (25 Hz)
 *   STATUS_CHAR  (Read | Notify, 1 byte) — current mode (0=IDLE, 1=ACTIVE)
 */

#ifndef BLE_SERVICE_H
#define BLE_SERVICE_H

#include <Arduino.h>
#include <ArduinoBLE.h>
#include "sensor.h"
#include "activity_detector.h"

// ─── BLE packet ───────────────────────────────────────────────────────────────
/**
 * BLEPacket — 14 bytes, fits in a single BLE 4.2 default MTU of 20 bytes.
 * All multi-byte fields are little-endian (native on ARM Cortex-M4).
 *
 * Quaternion components are scaled ×10000 and stored as int16_t.
 * Linear acceleration is stored in milli-g (mg) as int16_t.
 */
struct __attribute__((packed)) BLEPacket {
  uint16_t timestamp_ms;  // relative ms since session start (wraps ~65 s)
  int16_t  qw;            // quaternion ×10000
  int16_t  qx;
  int16_t  qy;
  int16_t  qz;
  int16_t  accel_x;       // linear accel in mg (1g = 1000 mg)
  int16_t  accel_y;
  int16_t  accel_z;
  // Total: 16 bytes
};

// ─── Config byte values ───────────────────────────────────────────────────────
#define CONFIG_MODE_AUTO   0x00
#define CONFIG_MODE_FORCE_ACTIVE 0x01
#define CONFIG_MODE_FORCE_IDLE   0x02

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * initBLE()
 * Initialises ArduinoBLE, registers the service and all characteristics,
 * starts advertising.
 *
 * @param deviceName  e.g. "SportBand-L" or "SportBand-R"
 * @return true on success.
 */
bool initBLE(const char* deviceName);

/**
 * bleLoop()
 * Must be called in the main loop().  Handles BLE stack events and
 * reads any incoming writes on CONFIG_CHAR.
 *
 * @return  CONFIG_MODE_AUTO / FORCE_ACTIVE / FORCE_IDLE as written by the
 *          remote app, or CONFIG_MODE_AUTO if nothing changed.
 */
uint8_t bleLoop();

/**
 * bleSendSensorData()
 * Packs a SensorAngles struct into a BLEPacket and notifies connected central.
 *
 * @param angles        Latest sensor reading.
 * @param sessionStart  millis() value at session start, for relative timestamp.
 */
void bleSendSensorData(const SensorAngles& angles, uint32_t sessionStart);

/**
 * bleSendBattery()
 * Sends a battery percentage update (call every ~30 seconds).
 *
 * @param percent  0-100
 */
void bleSendBattery(uint8_t percent);

/**
 * bleSendStatus()
 * Sends current activity mode to STATUS_CHAR (notify).
 *
 * @param mode  MODE_IDLE or MODE_ACTIVE
 */
void bleSendStatus(ActivityMode mode);

/** Returns true if a BLE central is currently connected. */
bool bleConnected();

#endif // BLE_SERVICE_H
