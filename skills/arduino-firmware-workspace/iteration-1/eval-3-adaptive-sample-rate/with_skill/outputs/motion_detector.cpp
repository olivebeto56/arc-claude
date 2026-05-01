// motion_detector.cpp — Adaptive sample rate controller implementation
// Wearable Sport Monitor — Running Node

#include "motion_detector.h"

// ------------------------------------------------------------------
// Constructor
// ------------------------------------------------------------------
MotionDetector::MotionDetector()
  : _state(MOTION_IDLE),
    _stateEnteredAt(0),
    _thresholdCrossedAt(0),
    _pendingTransition(false),
    _pendingState(MOTION_IDLE)
{}

// ------------------------------------------------------------------
// update()
//
// State machine with hysteresis debounce:
//
//   IDLE ──(accel > ACTIVE_THRESHOLD for ACTIVE_DEBOUNCE_MS)──► ACTIVE
//   ACTIVE ─(accel < IDLE_THRESHOLD  for IDLE_DEBOUNCE_MS)───► IDLE
//
// Returns true when the state actually changes so the caller can
// immediately call setSampleInterval() without polling getState().
// ------------------------------------------------------------------
bool MotionDetector::update(float accelMagnitude) {
  uint32_t now = millis();

  // Determine what state the current magnitude suggests
  MotionState suggested;
  float threshold;

  if (_state == MOTION_IDLE) {
    // Rising edge: need sustained activity above ACTIVE threshold
    suggested = MOTION_ACTIVE;
    threshold = MOTION_ACTIVE_THRESHOLD_MS2;
  } else {
    // Falling edge: need sustained stillness below IDLE threshold
    suggested = MOTION_IDLE;
    threshold = MOTION_IDLE_THRESHOLD_MS2;
  }

  bool conditionMet = (_state == MOTION_IDLE)
                        ? (accelMagnitude > threshold)
                        : (accelMagnitude < threshold);

  if (conditionMet) {
    if (!_pendingTransition || _pendingState != suggested) {
      // Start timing the debounce window
      _pendingTransition  = true;
      _pendingState       = suggested;
      _thresholdCrossedAt = now;
    } else {
      // Check if debounce window has elapsed
      uint32_t debounceMs = (suggested == MOTION_ACTIVE)
                              ? MOTION_ACTIVE_DEBOUNCE_MS
                              : MOTION_IDLE_DEBOUNCE_MS;

      if ((now - _thresholdCrossedAt) >= debounceMs) {
        // Commit the state transition
        _state             = suggested;
        _stateEnteredAt    = now;
        _pendingTransition = false;
        return true;  // State changed — caller should update sample rate
      }
    }
  } else {
    // Condition no longer met — cancel any pending transition
    _pendingTransition = false;
  }

  return false;  // No state change
}

// ------------------------------------------------------------------
// getStateLabel
// ------------------------------------------------------------------
const char* MotionDetector::getStateLabel() const {
  return (_state == MOTION_ACTIVE) ? "ACTIVE" : "IDLE";
}

// ------------------------------------------------------------------
// timeInCurrentState
// ------------------------------------------------------------------
uint32_t MotionDetector::timeInCurrentState() const {
  return millis() - _stateEnteredAt;
}
