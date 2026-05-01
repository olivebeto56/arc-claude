// sensor.cpp — BNO085 driver implementation
// Wearable Sport Monitor — Running Node
//
// Uses 9-axis ARVR_STABILIZED_RV for drift-free yaw (critical for
// hip rotation tracking in running). Never uses GAME_ROTATION_VECTOR.

#include "sensor.h"
#include <Wire.h>
#include <Adafruit_BNO08x.h>
#include <sh2.h>
#include <sh2_SensorValue.h>

// BNO085 I2C address (SA0 pin tied to GND on Adafruit breakout #4754)
#define BNO085_ADDR  0x4A

// Internal Adafruit driver object (-1 = no hardware reset pin wired)
static Adafruit_BNO08x bno085(-1);

// Shared sensor value buffer
static sh2_SensorValue_t sensorValue;

// Track the last interval that was sent to the sensor
static uint32_t currentIntervalUs = 10000;  // default 100 Hz

// ------------------------------------------------------------------
// Internal helper: enable both reports at a given interval
// ------------------------------------------------------------------
static bool enableReports(uint32_t intervalUs) {
  // 9-axis rotation vector with AR/VR stabilization — includes magnetometer
  // This is mandatory: provides drift-free yaw for hip/ankle rotation in running
  if (!bno085.enableReport(SH2_ARVR_STABILIZED_RV, intervalUs)) {
    Serial.println("ERROR: Could not enable SH2_ARVR_STABILIZED_RV");
    return false;
  }

  // Linear acceleration (gravity subtracted) — used for motion detection
  // and impact analysis. Allow a small tolerance: use same interval.
  if (!bno085.enableReport(SH2_LINEAR_ACCELERATION, intervalUs)) {
    Serial.println("WARN: Could not enable SH2_LINEAR_ACCELERATION");
    // Non-fatal — motion detection will still work via quaternion changes
  }

  currentIntervalUs = intervalUs;
  return true;
}

// ------------------------------------------------------------------
// initSensor
// ------------------------------------------------------------------
bool initSensor() {
  // Fast Mode I2C — required for reliable 100 Hz operation over I2C
  Wire.begin();
  Wire.setClock(400000);

  // Give BNO085 time to complete internal boot sequence
  delay(100);

  if (!bno085.begin_I2C(BNO085_ADDR)) {
    Serial.println("ERROR: BNO085 not found at 0x4A — check wiring (SDA→D4, SCL→D5)");
    return false;
  }

  // Allow sensor firmware to stabilize after begin
  delay(500);

  return enableReports(currentIntervalUs);
}

// ------------------------------------------------------------------
// reinitSensorReports — call after bno085.wasReset()
// ------------------------------------------------------------------
bool reinitSensorReports(uint32_t intervalUs) {
  Serial.println("BNO085 was reset — re-enabling reports");
  return enableReports(intervalUs);
}

// ------------------------------------------------------------------
// setSampleInterval — change report rate on the fly
// ------------------------------------------------------------------
bool setSampleInterval(uint32_t intervalUs) {
  if (intervalUs == currentIntervalUs) return true;  // no-op
  return enableReports(intervalUs);
}

// ------------------------------------------------------------------
// getSensorAngles
// ------------------------------------------------------------------
bool getSensorAngles(SensorAngles& out) {
  if (!bno085.getSensorEvent(&sensorValue)) {
    return false;  // No new data ready yet
  }

  if (sensorValue.sensorId == SH2_ARVR_STABILIZED_RV) {
    // Extract quaternion components
    out.qw = sensorValue.un.arvrStabilizedRV.real;
    out.qx = sensorValue.un.arvrStabilizedRV.i;
    out.qy = sensorValue.un.arvrStabilizedRV.j;
    out.qz = sensorValue.un.arvrStabilizedRV.k;

    // Convert quaternion to Euler angles (degrees)
    // Roll (rotation around X)
    float sinr_cosp = 2.0f * (out.qw * out.qx + out.qy * out.qz);
    float cosr_cosp = 1.0f - 2.0f * (out.qx * out.qx + out.qy * out.qy);
    out.roll = atan2f(sinr_cosp, cosr_cosp) * 180.0f / M_PI;

    // Pitch (rotation around Y)
    float sinp = 2.0f * (out.qw * out.qy - out.qz * out.qx);
    out.pitch = (fabsf(sinp) >= 1.0f)
                  ? copysignf(90.0f, sinp)
                  : asinf(sinp) * 180.0f / M_PI;

    // Yaw (rotation around Z — requires magnetometer, provided by ARVR_STABILIZED_RV)
    float siny_cosp = 2.0f * (out.qw * out.qz + out.qx * out.qy);
    float cosy_cosp = 1.0f - 2.0f * (out.qy * out.qy + out.qz * out.qz);
    out.yaw = atan2f(siny_cosp, cosy_cosp) * 180.0f / M_PI;

    out.timestamp_ms = millis();

    // Zero out accel fields; they may be overwritten by the next event
    out.accel_x = 0.0f;
    out.accel_y = 0.0f;
    out.accel_z = 0.0f;

    return true;
  }

  if (sensorValue.sensorId == SH2_LINEAR_ACCELERATION) {
    // Update accel fields on the existing out struct is not possible here
    // (no reference). This is handled separately via getLinearAccelMagnitude().
    return false;
  }

  return false;
}

// ------------------------------------------------------------------
// getLinearAccelMagnitude — lightweight read for motion detector
// ------------------------------------------------------------------
bool getLinearAccelMagnitude(float& magnitude) {
  if (!bno085.getSensorEvent(&sensorValue)) {
    return false;
  }

  if (sensorValue.sensorId == SH2_LINEAR_ACCELERATION) {
    float ax = sensorValue.un.linearAcceleration.x;
    float ay = sensorValue.un.linearAcceleration.y;
    float az = sensorValue.un.linearAcceleration.z;
    magnitude = sqrtf(ax * ax + ay * ay + az * az);
    return true;
  }

  return false;
}
