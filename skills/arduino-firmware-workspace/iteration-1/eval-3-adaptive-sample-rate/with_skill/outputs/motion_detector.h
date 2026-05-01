// motion_detector.h — Adaptive sample rate controller
// Wearable Sport Monitor — Running Node
//
// Detects whether the athlete is idle or active based on linear
// acceleration magnitude. Drives automatic switching between:
//   - SAMPLE_RATE_IDLE_HZ    (25 Hz)  when still  → saves battery
//   - SAMPLE_RATE_RUNNING_HZ (100 Hz) when moving → full precision
//
// Hysteresis and debounce timers prevent rapid toggling at the
// activity boundary (e.g., brief pauses mid-run).

#pragma once

#include <Arduino.h>
#include "sensor.h"

// ------------------------------------------------------------------
// Configurable thresholds (tune after physical testing)
// ------------------------------------------------------------------

// Acceleration (m/s²) above which the athlete is considered active.
// Gravity is already removed by SH2_LINEAR_ACCELERATION.
// A standing person at rest reads ~0.05–0.15 m/s² (sensor noise).
// Walking generates peaks of 1–3 m/s²; running 5–15 m/s².
// Threshold of 0.5 m/s² gives a comfortable margin above noise.
#define MOTION_ACTIVE_THRESHOLD_MS2  0.5f

// Acceleration below which the athlete is considered idle.
// Lower than ACTIVE_THRESHOLD to add hysteresis and avoid flapping.
#define MOTION_IDLE_THRESHOLD_MS2    0.3f

// Time (ms) the signal must stay ABOVE the active threshold before
// switching from IDLE → ACTIVE. Avoids single-spike false triggers.
#define MOTION_ACTIVE_DEBOUNCE_MS    200

// Time (ms) the signal must stay BELOW the idle threshold before
// switching from ACTIVE → IDLE. Prevents switching during brief
// pauses (e.g., athlete stops for 1 second at a traffic light).
#define MOTION_IDLE_DEBOUNCE_MS      2000

// ------------------------------------------------------------------
// MotionDetector class
// ------------------------------------------------------------------
class MotionDetector {
public:
  MotionDetector();

  // Call once per loop iteration with the latest linear acceleration
  // magnitude (m/s²). Returns true if the motion state changed.
  bool update(float accelMagnitude);

  // Current motion state
  MotionState getState() const { return _state; }

  // Human-readable state label for Serial debugging
  const char* getStateLabel() const;

  // Milliseconds spent in the current state
  uint32_t timeInCurrentState() const;

private:
  MotionState _state;
  uint32_t    _stateEnteredAt;    // millis() when current state started
  uint32_t    _thresholdCrossedAt; // millis() when pending transition began
  bool        _pendingTransition;
  MotionState _pendingState;
};
