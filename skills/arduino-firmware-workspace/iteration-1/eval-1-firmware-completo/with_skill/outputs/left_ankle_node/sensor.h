/**
 * sensor.h
 *
 * Sensor abstraction interface for the BNO085 IMU.
 * This interface NEVER changes — swapping the physical sensor
 * (e.g., for a custom PCB) only requires updating sensor.cpp.
 *
 * Sensor: Adafruit BNO085 breakout #4754
 * Mode:   ARVR_STABILIZED_RV (9-axis, includes magnetometer)
 * Rate:   100 Hz (configurable via enableSensorReports())
 */

#ifndef SENSOR_H
#define SENSOR_H

#include <stdint.h>
#include <stdbool.h>

// ─── DATA STRUCTURES ──────────────────────────────────────────────────────────

/**
 * SensorAngles — output of getSensorAngles().
 *
 * Contains both Euler angles (degrees) and raw quaternion components.
 * The quaternion is the primary output used for BLE transmission.
 * Euler angles are derived for debugging and local display.
 */
struct SensorAngles {
  // Euler angles (degrees, derived from quaternion)
  float roll;   // rotation around X axis  (-180 to +180 deg)
  float pitch;  // rotation around Y axis  (-90 to +90 deg)
  float yaw;    // rotation around Z axis  (-180 to +180 deg)

  // Raw quaternion (unit quaternion, range -1.0 to +1.0)
  float qw;
  float qx;
  float qy;
  float qz;

  // Linear acceleration (m/s^2, gravity removed by BNO085)
  float accel_x;
  float accel_y;
  float accel_z;

  // Timestamp from millis() at the moment the sample was received
  uint32_t timestamp_ms;

  // Calibration status (0=uncalibrated, 1=low, 2=medium, 3=full)
  uint8_t calibration_status;
};

// ─── PUBLIC API ───────────────────────────────────────────────────────────────

/**
 * initSensor()
 * Initializes I2C communication with the BNO085 and enables 9-axis
 * rotation vector reports at 100 Hz, plus linear acceleration reports.
 *
 * Must be called once in setup() after Wire.begin().
 * Returns true on success, false if the sensor is not found or
 * the reports cannot be enabled.
 */
bool initSensor();

/**
 * enableSensorReports()
 * Re-enables the BNO085 sensor reports without re-running begin_I2C().
 * Call this after sensorWasReset() returns true to recover from a
 * mid-session sensor reset (e.g., caused by strong vibration).
 */
void enableSensorReports();

/**
 * getSensorAngles(out)
 * Reads the latest sensor event from the BNO085 FIFO.
 * Populates the SensorAngles struct with quaternion, Euler angles,
 * linear acceleration, timestamp, and calibration status.
 *
 * Returns true if a new sample was available and parsed successfully.
 * Returns false if no new data is ready (call again on next loop tick).
 *
 * Non-blocking — does NOT delay().
 */
bool getSensorAngles(SensorAngles& out);

/**
 * sensorWasReset()
 * Returns true if the BNO085 has reset since the last call.
 * After a reset, sensor reports must be re-enabled via enableSensorReports().
 */
bool sensorWasReset();

// ─── BATTERY API ──────────────────────────────────────────────────────────────

/**
 * readBatteryVoltage()
 * Reads the LiPo battery voltage using the XIAO nRF52840 Sense
 * internal voltage divider and ADC.
 *
 * Returns voltage in volts (typical range: 3.2 V – 4.2 V).
 * Takes approximately 2 ms (includes voltage divider enable delay).
 */
float readBatteryVoltage();

/**
 * batteryPercent(voltage)
 * Converts a LiPo voltage reading to a percentage (0–100%).
 * Assumes LiPo chemistry: 4.2 V = 100%, 3.2 V = 0%.
 */
uint8_t batteryPercent(float voltage);

#endif // SENSOR_H
