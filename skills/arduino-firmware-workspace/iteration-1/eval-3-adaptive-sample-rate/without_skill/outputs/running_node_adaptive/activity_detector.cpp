/**
 * activity_detector.cpp — Hysteresis-based motion / stillness classifier
 *
 * State transitions:
 *
 *   MODE_ACTIVE ──── |a| < IDLE_THRESHOLD for IDLE_CONFIRM_MS ───► MODE_IDLE
 *   MODE_IDLE   ──── |a| > ACTIVE_THRESHOLD for ACTIVE_CONFIRM_MS ► MODE_ACTIVE
 *
 * The "confirm time" approach avoids bouncing:
 *  - A single footstrike spike will not prevent transition to IDLE
 *    because the spike duration is << IDLE_CONFIRM_MS (2 s).
 *  - A momentary vibration bump will not switch from IDLE to ACTIVE
 *    because it must persist for ACTIVE_CONFIRM_MS (200 ms).
 */

#include "activity_detector.h"
#include "sensor.h"   // for INTERVAL_ACTIVE_US / INTERVAL_IDLE_US

ActivityDetector::ActivityDetector()
  : _mode(MODE_ACTIVE),
    _aboveThresholdSince(0),
    _belowThresholdSince(0),
    _aboveActive(false),
    _belowIdle(false)
{}

void ActivityDetector::begin() {
  _mode                 = MODE_ACTIVE;
  _aboveThresholdSince  = millis();
  _belowThresholdSince  = 0;
  _aboveActive          = true;
  _belowIdle            = false;

  Serial.println("[activity] Detector started in MODE_ACTIVE");
}

ActivityState ActivityDetector::update(float accelMagnitude) {
  uint32_t now = millis();

  // ── Track how long |a| has been ABOVE the active threshold ───────────────
  if (accelMagnitude > ACCEL_ACTIVE_THRESHOLD) {
    if (!_aboveActive) {
      _aboveActive         = true;
      _aboveThresholdSince = now;
    }
    // Reset idle countdown — any motion resets the idle timer
    _belowIdle           = false;
    _belowThresholdSince = 0;
  } else {
    _aboveActive = false;
  }

  // ── Track how long |a| has been BELOW the idle threshold ─────────────────
  if (accelMagnitude < ACCEL_IDLE_THRESHOLD) {
    if (!_belowIdle) {
      _belowIdle           = true;
      _belowThresholdSince = now;
    }
  } else {
    _belowIdle           = false;
    _belowThresholdSince = 0;
  }

  // ── Evaluate transitions ──────────────────────────────────────────────────

  if (_mode == MODE_IDLE) {
    // Idle → Active: need sustained motion
    if (_aboveActive && (now - _aboveThresholdSince >= ACTIVE_CONFIRM_MS)) {
      _mode = MODE_ACTIVE;
      Serial.print("[activity] IDLE → ACTIVE  |a|=");
      Serial.print(accelMagnitude, 2);
      Serial.println(" m/s²  → 100 Hz");
      return ACTIVITY_CHANGED;
    }
  } else {
    // Active → Idle: need sustained stillness
    if (_belowIdle && (now - _belowThresholdSince >= IDLE_CONFIRM_MS)) {
      _mode = MODE_IDLE;
      Serial.print("[activity] ACTIVE → IDLE  |a|=");
      Serial.print(accelMagnitude, 2);
      Serial.println(" m/s²  → 25 Hz");
      return ACTIVITY_CHANGED;
    }
  }

  return ACTIVITY_NO_CHANGE;
}

ActivityMode ActivityDetector::getMode() const {
  return _mode;
}

uint32_t ActivityDetector::getCurrentIntervalUs() const {
  return (_mode == MODE_ACTIVE) ? INTERVAL_ACTIVE_US : INTERVAL_IDLE_US;
}
