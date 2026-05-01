/**
 * sensor.cpp
 *
 * BNO085 driver implementation for the wearable sport monitor.
 * Implements the sensor.h interface.
 *
 * Key design decisions:
 *   - Uses SH2_ARVR_STABILIZED_RV (9-axis, includes magnetometer).
 *     This prevents Z-axis (yaw) drift over long sessions.
 *     NEVER use SH2_GAME_ROTATION_VECTOR — it omits the magnetometer.
 *   - I2C Fast Mode (400 kHz) is required at 100 Hz.
 *   - Linear acceleration (gravity-removed) is enabled for cadence detection.
 *   - Battery is read via P0_14-gated voltage divider on PIN_VBAT.
 */

#include "sensor.h"
#include <Adafruit_BNO08x.h>
#include <Wire.h>
#include <math.h>
#include <Arduino.h>

// ─── CONSTANTS ────────────────────────────────────────────────────────────────

// BNO085 I2C address — Adafruit breakout #4754 has SA0 tied to GND → 0x4A
#define BNO085_I2C_ADDR   0x4A

// Sample rate in microseconds (100 Hz = 10,000 µs)
#define REPORT_INTERVAL_US  10000

// Battery ADC pin (defined in the Seeed nRF52840 BSP)
// PIN_VBAT is the ADC input; P0_14 gates the voltage divider
#ifndef PIN_VBAT
  #define PIN_VBAT  A0   // Fallback if BSP doesn't define it
#endif

// ─── MODULE STATE ─────────────────────────────────────────────────────────────

// BNO085 driver instance (-1 = no hardware reset pin connected)
static Adafruit_BNO08x bno085(-1);

// Shared sensor event buffer reused on every loop
static sh2_SensorValue_t _sensorEvent;

// Linear acceleration values cached from the last getSensorEvent call
static float _lastAccelX = 0.0f;
static float _lastAccelY = 0.0f;
static float _lastAccelZ = 0.0f;

// ─── PRIVATE HELPERS ──────────────────────────────────────────────────────────

/**
 * _enableReports()
 * Activates the two sensor reports we need:
 *   1. ARVR Stabilized Rotation Vector (9-axis quaternion, 100 Hz)
 *   2. Linear Acceleration (gravity-removed, 100 Hz) — for cadence / impact
 *
 * Separated from begin_I2C so it can be called again after a sensor reset.
 */
static bool _enableReports() {
  // Primary: 9-axis rotation vector with AR/VR stabilization filter
  if (!bno085.enableReport(SH2_ARVR_STABILIZED_RV, REPORT_INTERVAL_US)) {
    Serial.println("ERROR: Cannot enable SH2_ARVR_STABILIZED_RV");
    return false;
  }

  // Secondary: linear acceleration without gravity (for step detection)
  // Non-critical — ignore return value; main functionality still works
  bno085.enableReport(SH2_LINEAR_ACCELERATION, REPORT_INTERVAL_US);

  return true;
}

// ─── PUBLIC IMPLEMENTATION ────────────────────────────────────────────────────

bool initSensor() {
  // I2C must already be started (Wire.begin() called in setup)
  // Add a small delay to ensure the BNO085 has completed its internal boot
  delay(100);

  if (!bno085.begin_I2C(BNO085_I2C_ADDR)) {
    Serial.println("ERROR: BNO085 not found at I2C address 0x4A");
    Serial.println("  Check: SDA→D4, SCL→D5, VCC→3.3V, GND→GND");
    return false;
  }

  // Wait for the sensor's internal firmware to finish loading
  delay(500);

  return _enableReports();
}

void enableSensorReports() {
  // Called after sensorWasReset() to re-arm reports without re-init
  _enableReports();
}

bool getSensorAngles(SensorAngles& out) {
  // Poll for the next available event from the BNO085 FIFO
  if (!bno085.getSensorEvent(&_sensorEvent)) {
    return false;  // No new data ready — non-blocking
  }

  // ── Handle linear acceleration sub-report ───────────────────────────────
  // The BNO085 multiplexes both enabled reports over the same I2C bus.
  // We cache accel values whenever we see them, and attach the most recent
  // accel reading to the next quaternion output.
  if (_sensorEvent.sensorId == SH2_LINEAR_ACCELERATION) {
    _lastAccelX = _sensorEvent.un.linearAcceleration.x;
    _lastAccelY = _sensorEvent.un.linearAcceleration.y;
    _lastAccelZ = _sensorEvent.un.linearAcceleration.z;
    // Don't return true yet — wait for the quaternion report
    return false;
  }

  // ── Parse rotation vector report ────────────────────────────────────────
  if (_sensorEvent.sensorId != SH2_ARVR_STABILIZED_RV) {
    return false;  // Unexpected report ID — ignore
  }

  // Extract raw quaternion components
  out.qw = _sensorEvent.un.arvrStabilizedRV.real;
  out.qx = _sensorEvent.un.arvrStabilizedRV.i;
  out.qy = _sensorEvent.un.arvrStabilizedRV.j;
  out.qz = _sensorEvent.un.arvrStabilizedRV.k;

  // Calibration status (0=uncal, 1=low, 2=med, 3=full)
  out.calibration_status = _sensorEvent.status;

  // ── Convert quaternion to Euler angles (degrees) ─────────────────────────
  // Roll (rotation around X)
  float sinr_cosp = 2.0f * (out.qw * out.qx + out.qy * out.qz);
  float cosr_cosp = 1.0f - 2.0f * (out.qx * out.qx + out.qy * out.qy);
  out.roll = atan2f(sinr_cosp, cosr_cosp) * 180.0f / M_PI;

  // Pitch (rotation around Y) — clamp to avoid NaN at ±90°
  float sinp = 2.0f * (out.qw * out.qy - out.qz * out.qx);
  if (fabsf(sinp) >= 1.0f) {
    out.pitch = copysignf(90.0f, sinp);
  } else {
    out.pitch = asinf(sinp) * 180.0f / M_PI;
  }

  // Yaw (rotation around Z) — requires magnetometer for absolute heading
  float siny_cosp = 2.0f * (out.qw * out.qz + out.qx * out.qy);
  float cosy_cosp = 1.0f - 2.0f * (out.qy * out.qy + out.qz * out.qz);
  out.yaw = atan2f(siny_cosp, cosy_cosp) * 180.0f / M_PI;

  // Attach cached linear acceleration
  out.accel_x = _lastAccelX;
  out.accel_y = _lastAccelY;
  out.accel_z = _lastAccelZ;

  // Timestamp
  out.timestamp_ms = millis();

  return true;
}

bool sensorWasReset() {
  return bno085.wasReset();
}

// ─── BATTERY ──────────────────────────────────────────────────────────────────

float readBatteryVoltage() {
  // Enable voltage divider: P0_14 LOW activates the divider circuit
  pinMode(P0_14, OUTPUT);
  digitalWrite(P0_14, LOW);
  delay(1);  // Allow the divider to settle before sampling

  // Use 3.0V internal reference for accurate LiPo range (3.2–4.2V)
  analogReference(AR_INTERNAL_3_0);
  analogReadResolution(12);  // 12-bit ADC → 0..4095

  int raw = analogRead(PIN_VBAT);

  // Disable voltage divider to save power
  digitalWrite(P0_14, HIGH);
  pinMode(P0_14, INPUT);

  // Conversion:
  //   ADC reading / 4096 * reference (3.0V) * divider factor (2×)
  return (raw * 3.0f / 4096.0f) * 2.0f;
}

uint8_t batteryPercent(float voltage) {
  // LiPo discharge curve approximation:
  //   4.2 V = 100%,  3.2 V = 0%
  float pct = (voltage - 3.2f) / (4.2f - 3.2f) * 100.0f;
  return (uint8_t)constrain((int)pct, 0, 100);
}
