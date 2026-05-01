/**
 * sensor.cpp — BNO085 driver implementation with runtime sample-rate control
 *
 * Key design decisions:
 *  - Uses SH2_ARVR_STABILIZED_RV (9-axis) for orientation — never 6-axis.
 *  - Uses SH2_LINEAR_ACCELERATION (gravity removed) for motion detection.
 *  - setSampleRate() re-enables both reports at the new interval without
 *    calling begin_I2C() again (safe mid-session).
 *  - wasReset() is checked every loop so reports survive vibration-induced
 *    sensor reboots.
 */

#include "sensor.h"
#include <math.h>

// ─── Module-private state ─────────────────────────────────────────────────────

static Adafruit_BNO08x  _bno(-1);      // -1 = no hardware reset pin wired
static sh2_SensorValue_t _event;
static uint32_t          _currentIntervalUs = INTERVAL_ACTIVE_US;

// Last linear acceleration components (m/s²)
static float _lastAccelX = 0.0f;
static float _lastAccelY = 0.0f;
static float _lastAccelZ = 0.0f;

// ─── Private helpers ──────────────────────────────────────────────────────────

/**
 * _enableReports()
 * Enables / re-enables the two SHTP reports at the current interval.
 * Called from initSensor() and also after wasReset() or setSampleRate().
 */
static bool _enableReports(uint32_t intervalUs) {
  bool ok = true;

  // 9-axis stabilised rotation vector — includes magnetometer (no Z-drift)
  if (!_bno.enableReport(SH2_ARVR_STABILIZED_RV, intervalUs)) {
    Serial.println("[sensor] ERROR: could not enable SH2_ARVR_STABILIZED_RV");
    ok = false;
  }

  // Linear acceleration (gravity subtracted) — used for activity detection
  if (!_bno.enableReport(SH2_LINEAR_ACCELERATION, intervalUs)) {
    Serial.println("[sensor] ERROR: could not enable SH2_LINEAR_ACCELERATION");
    ok = false;
  }

  return ok;
}

// ─── Public API implementation ────────────────────────────────────────────────

bool initSensor() {
  Wire.begin();
  Wire.setClock(400000);  // I2C Fast Mode — required for 100 Hz without drops
  delay(100);             // give BNO085 time to finish its internal boot

  if (!_bno.begin_I2C(0x4A)) {
    Serial.println("[sensor] ERROR: BNO085 not found at I2C address 0x4A");
    return false;
  }

  delay(500);  // wait for internal calibration load before enabling reports

  bool ok = _enableReports(INTERVAL_ACTIVE_US);
  if (ok) {
    _currentIntervalUs = INTERVAL_ACTIVE_US;
    Serial.println("[sensor] BNO085 initialised at 100 Hz");
  }
  return ok;
}

bool getSensorAngles(SensorAngles& out) {
  // ── Recover from sensor reset (e.g. strong impact causes internal reboot) ──
  if (_bno.wasReset()) {
    Serial.println("[sensor] BNO085 reset detected — re-enabling reports");
    _enableReports(_currentIntervalUs);
  }

  if (!_bno.getSensorEvent(&_event)) {
    return false;  // no new packet ready yet
  }

  // ── 9-axis orientation report ─────────────────────────────────────────────
  if (_event.sensorId == SH2_ARVR_STABILIZED_RV) {
    out.qw = _event.un.arvrStabilizedRV.real;
    out.qx = _event.un.arvrStabilizedRV.i;
    out.qy = _event.un.arvrStabilizedRV.j;
    out.qz = _event.un.arvrStabilizedRV.k;

    // Convert quaternion → Euler angles (degrees)
    float sinr_cosp = 2.0f * (out.qw * out.qx + out.qy * out.qz);
    float cosr_cosp = 1.0f - 2.0f * (out.qx * out.qx + out.qy * out.qy);
    out.roll  = atan2f(sinr_cosp, cosr_cosp) * (180.0f / (float)M_PI);

    float sinp = 2.0f * (out.qw * out.qy - out.qz * out.qx);
    out.pitch = (fabsf(sinp) >= 1.0f)
                  ? copysignf(90.0f, sinp)
                  : asinf(sinp) * (180.0f / (float)M_PI);

    float siny_cosp = 2.0f * (out.qw * out.qz + out.qx * out.qy);
    float cosy_cosp = 1.0f - 2.0f * (out.qy * out.qy + out.qz * out.qz);
    out.yaw   = atan2f(siny_cosp, cosy_cosp) * (180.0f / (float)M_PI);

    // Carry forward the last known linear acceleration
    out.accel_x = _lastAccelX;
    out.accel_y = _lastAccelY;
    out.accel_z = _lastAccelZ;

    out.timestamp_ms = millis();
    return true;
  }

  // ── Linear acceleration report ────────────────────────────────────────────
  if (_event.sensorId == SH2_LINEAR_ACCELERATION) {
    _lastAccelX = _event.un.linearAcceleration.x;
    _lastAccelY = _event.un.linearAcceleration.y;
    _lastAccelZ = _event.un.linearAcceleration.z;
    // Not a full orientation update — caller handles this gracefully
  }

  return false;
}

void setSampleRate(uint32_t intervalUs) {
  if (intervalUs == _currentIntervalUs) return;  // no change needed

  _currentIntervalUs = intervalUs;
  _enableReports(intervalUs);

  uint32_t hz = 1000000UL / intervalUs;
  Serial.print("[sensor] Sample rate changed to ");
  Serial.print(hz);
  Serial.println(" Hz");
}

float getAccelMagnitude() {
  return sqrtf(_lastAccelX * _lastAccelX +
               _lastAccelY * _lastAccelY +
               _lastAccelZ * _lastAccelZ);
}
