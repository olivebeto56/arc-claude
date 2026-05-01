// sensor.h — Sensor abstraction interface for BNO085 IMU
// Wearable Sport Monitor — Running Node
// Adaptive sample rate: 100Hz (active) / 25Hz (idle)
//
// This interface is hardware-independent. Swapping the BNO085 for a
// different IMU only requires changing sensor.cpp, not this header.

#pragma once

#include <Arduino.h>

// ------------------------------------------------------------------
// Sensor data struct — output of getSensorAngles()
// ------------------------------------------------------------------
struct SensorAngles {
  float roll;          // degrees — rotation around X axis
  float pitch;         // degrees — rotation around Y axis
  float yaw;           // degrees — rotation around Z axis (needs magnetometer)
  float qw, qx, qy, qz;  // raw quaternion (9-axis, ARVR stabilized)
  float accel_x;       // m/s² linear acceleration (gravity removed)
  float accel_y;
  float accel_z;
  uint32_t timestamp_ms;
};

// ------------------------------------------------------------------
// Motion state enum used by adaptive sampling
// ------------------------------------------------------------------
enum MotionState {
  MOTION_IDLE,    // Athlete is still — sample at SAMPLE_RATE_IDLE_HZ
  MOTION_ACTIVE   // Athlete is moving — sample at SAMPLE_RATE_RUNNING_HZ
};

// ------------------------------------------------------------------
// Public API
// ------------------------------------------------------------------

// Initialize I2C and BNO085. Returns true on success.
bool initSensor();

// Re-enable sensor reports without re-initializing I2C.
// Call this after bno085.wasReset() returns true.
bool reinitSensorReports(uint32_t intervalUs);

// Read the latest sensor event.
// Returns true if a new sample was available and out was populated.
bool getSensorAngles(SensorAngles& out);

// Change the BNO085 report interval on the fly (microseconds).
// Used by the adaptive rate logic to switch between 100Hz and 25Hz.
bool setSampleInterval(uint32_t intervalUs);

// Read the raw linear acceleration magnitude (m/s²) without a full
// getSensorAngles() call — used by the motion detector.
bool getLinearAccelMagnitude(float& magnitude);
