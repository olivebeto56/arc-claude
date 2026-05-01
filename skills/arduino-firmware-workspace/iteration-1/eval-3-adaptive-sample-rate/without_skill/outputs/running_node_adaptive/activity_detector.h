/**
 * activity_detector.h — Hysteresis-based motion / stillness classifier
 *
 * Classifies the athlete as ACTIVE or IDLE based on a sliding window of
 * linear-acceleration magnitude samples.  Two separate thresholds and
 * a time-guard prevent rapid oscillation of the sample rate:
 *
 *   IDLE  → ACTIVE : |a| exceeds ACCEL_ACTIVE_THRESHOLD for
 *                    at least ACTIVE_CONFIRM_MS milliseconds.
 *
 *   ACTIVE → IDLE  : |a| stays below ACCEL_IDLE_THRESHOLD for
 *                    at least IDLE_CONFIRM_MS milliseconds.
 *
 * Usage:
 *   ActivityDetector detector;
 *   detector.begin();
 *
 *   // In the main loop, after reading sensor:
 *   ActivityState state = detector.update(accelMagnitude);
 *   if (state == ACTIVITY_CHANGED) { ... apply new rate ... }
 */

#ifndef ACTIVITY_DETECTOR_H
#define ACTIVITY_DETECTOR_H

#include <Arduino.h>

// ─── Thresholds ───────────────────────────────────────────────────────────────
// Tune these values with real hardware.
// Running footstrike produces peaks of 15–40 m/s²; standing still < 0.5 m/s².

/** m/s² — acceleration that confirms the athlete has started moving. */
#define ACCEL_ACTIVE_THRESHOLD  1.5f

/** m/s² — acceleration that confirms the athlete is standing still. */
#define ACCEL_IDLE_THRESHOLD    0.8f

/** ms — acceleration must exceed ACTIVE threshold for this long before
 *  switching from IDLE → ACTIVE.  Prevents a single spike from triggering. */
#define ACTIVE_CONFIRM_MS       200UL

/** ms — acceleration must stay below IDLE threshold for this long before
 *  switching from ACTIVE → IDLE.  Prevents the rate dropping mid-stride. */
#define IDLE_CONFIRM_MS        2000UL

// ─── State machine ────────────────────────────────────────────────────────────

enum ActivityMode {
  MODE_IDLE   = 0,  // athlete is still   → sensor at 25 Hz
  MODE_ACTIVE = 1   // athlete is moving  → sensor at 100 Hz
};

enum ActivityState {
  ACTIVITY_NO_CHANGE = 0,
  ACTIVITY_CHANGED   = 1   // mode flipped this call — apply new sample rate
};

// ─── Class ────────────────────────────────────────────────────────────────────

class ActivityDetector {
public:
  ActivityDetector();

  /** Call once in setup().  Starts in ACTIVE mode (safe default at boot). */
  void begin();

  /**
   * update()
   * Feed a new |acceleration| sample.  Returns ACTIVITY_CHANGED if the
   * internal mode flipped this call.  Call on every sensor reading.
   *
   * @param accelMagnitude  |a| in m/s² from getAccelMagnitude().
   * @return ACTIVITY_CHANGED or ACTIVITY_NO_CHANGE.
   */
  ActivityState update(float accelMagnitude);

  /** Returns the current activity mode. */
  ActivityMode  getMode() const;

  /** Returns the sample-rate interval in microseconds for the current mode. */
  uint32_t      getCurrentIntervalUs() const;

private:
  ActivityMode _mode;

  // Timestamps for hysteresis guards
  uint32_t _aboveThresholdSince;  // millis() when |a| first exceeded ACTIVE threshold
  uint32_t _belowThresholdSince;  // millis() when |a| first dropped below IDLE threshold

  bool _aboveActive;  // true while |a| > ACCEL_ACTIVE_THRESHOLD
  bool _belowIdle;    // true while |a| < ACCEL_IDLE_THRESHOLD
};

#endif // ACTIVITY_DETECTOR_H
