/**
 * sensor.h — BNO085 sensor interface with adaptive sampling rate
 *
 * Hardware: Adafruit BNO085 breakout #4754 connected via I2C
 * MCU:      Seeed XIAO nRF52840 Sense
 *
 * This interface abstracts the BNO085 driver and exposes:
 *   - initSensor()          — initialize hardware and reports
 *   - getSensorAngles()     — read latest orientation data
 *   - setSampleRate()       — change BNO085 report interval
 *   - getAccelMagnitude()   — helper used by activity detector
 */

#ifndef SENSOR_H
#define SENSOR_H

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_BNO08x.h>

// ─── Sample rate constants ────────────────────────────────────────────────────
#define SAMPLE_RATE_ACTIVE_HZ   100   // 10,000 µs — full-motion running
#define SAMPLE_RATE_IDLE_HZ      25   // 40,000 µs — athlete standing still

// Interval in microseconds derived from the Hz values above
#define INTERVAL_ACTIVE_US   10000UL  // 100 Hz
#define INTERVAL_IDLE_US     40000UL  //  25 Hz

// ─── Data structures ──────────────────────────────────────────────────────────

/**
 * SensorAngles — canonical output of getSensorAngles().
 * The interface contract never changes even if the underlying driver does.
 */
struct SensorAngles {
  float    roll;           // degrees, X-axis rotation
  float    pitch;          // degrees, Y-axis rotation
  float    yaw;            // degrees, Z-axis rotation
  float    qw, qx, qy, qz; // raw quaternion (9-axis, ARVR-stabilised)
  float    accel_x;        // m/s² — linear acceleration (gravity removed)
  float    accel_y;
  float    accel_z;
  uint32_t timestamp_ms;   // millis() at the moment of reading
};

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * initSensor()
 * Initialises I2C bus, probes BNO085 at 0x4A, enables the 9-axis
 * ARVR-stabilised rotation-vector and linear-acceleration reports.
 *
 * @return true on success, false if sensor not found or reports fail.
 */
bool initSensor();

/**
 * getSensorAngles()
 * Reads the latest sensor event from BNO085 and populates `out`.
 * Must be called frequently (every loop iteration) so SHTP packets
 * are consumed before the internal FIFO overflows.
 *
 * @param out  Reference to a SensorAngles struct to fill.
 * @return     true if a new sample was available and populated, false otherwise.
 */
bool getSensorAngles(SensorAngles& out);

/**
 * setSampleRate()
 * Reconfigures both BNO085 reports to the requested interval.
 * Triggers a soft-reconfiguration of the SHTP reports — safe to call
 * at runtime without re-running begin_I2C().
 *
 * @param intervalUs  Report interval in microseconds.
 *                    Use INTERVAL_ACTIVE_US (10000) or INTERVAL_IDLE_US (40000).
 */
void setSampleRate(uint32_t intervalUs);

/**
 * getAccelMagnitude()
 * Returns the magnitude |a| of the last linear acceleration vector.
 * Used by the activity detector to decide active vs. idle state.
 *
 * @return  |accel| in m/s².  Returns 0.0 if no sample has been read yet.
 */
float getAccelMagnitude();

#endif // SENSOR_H
