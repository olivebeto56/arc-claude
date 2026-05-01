// lib/analysis/event_detector.dart
//
// Detects gait events (IMPACT and TAKEOFF) from BNO085 linear acceleration data.
// Uses hysteresis with two thresholds to avoid oscillation in the transition zone.
//
// Thresholds are based on running_biomechanics.md reference constants:
//   _impactThreshold  = 12.0 m/s²  — normal running impact range 8–15 m/s²
//   _takeoffThreshold =  2.5 m/s²  — below resting signal noise floor
//   _minStepMs        =  200 ms    — physiological max of ~300 spm
//   _maxContactMs     =  500 ms    — values > 500 ms are sensor noise, not running
//
// References:
//   Morin et al. (2011) — GCT at 12 km/h ≈ 250 ms; elite ≈ 185 ms
//   running_biomechanics.md §Carga de impacto §Tiempo de contacto

import 'dart:math';

// ---------------------------------------------------------------------------
// Data model — SensorData
// Assumed to be provided by the flutter-ble layer. Declared here so this file
// compiles standalone; replace with the real import in production.
// ---------------------------------------------------------------------------

/// Raw packet from one BNO085 node arriving at ~100 Hz over BLE.
class SensorData {
  /// Node identifier, e.g. "LEFT_ANKLE" or "RIGHT_ANKLE"
  final String nodeId;

  /// Milliseconds since session start (monotonic)
  final int timestampMs;

  /// Linear acceleration WITHOUT gravity, already filtered by BNO085 (m/s²)
  final double accelX;
  final double accelY;
  final double accelZ;

  /// Pitch angle of the foot at this sample (degrees).
  /// Positive = heel-strike orientation; negative = forefoot.
  final double pitch;

  const SensorData({
    required this.nodeId,
    required this.timestampMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.pitch,
  });
}

// ---------------------------------------------------------------------------
// Gait event types
// ---------------------------------------------------------------------------

/// Events fired by [GaitEventDetector] as the runner's foot contacts / leaves
/// the ground.
enum GaitEvent {
  /// Foot has just struck the ground. [value] = foot pitch angle (degrees).
  impact,

  /// Foot has just left the ground. [value] = ground contact time (ms).
  takeoff,
}

// ---------------------------------------------------------------------------
// GaitEventDetector
// ---------------------------------------------------------------------------

/// Stateful per-node detector that converts a stream of [SensorData] samples
/// into discrete [GaitEvent] callbacks.
///
/// Instantiate one [GaitEventDetector] per physical node (ankle):
///
/// ```dart
/// final leftDetector = GaitEventDetector(
///   onEvent: (event, nodeId, ts, value) {
///     if (event == GaitEvent.impact) metricsCalculator.recordImpact(nodeId, ts, value, ???);
///   },
/// );
/// ```
///
/// Then call [process] for every incoming [SensorData] packet:
///
/// ```dart
/// bleStream.listen((data) {
///   if (data.nodeId == 'LEFT_ANKLE') leftDetector.process(data);
/// });
/// ```
class GaitEventDetector {
  // -------------------------------------------------------------------------
  // Hysteresis thresholds (calibrated from running_biomechanics.md)
  // -------------------------------------------------------------------------

  /// Impact threshold (m/s²). A spike above this marks initial ground contact.
  /// Typical BNO085 ankle values at 10–12 km/h: 10–20 m/s².
  static const double _impactThreshold = 12.0;

  /// Takeoff threshold (m/s²). Acceleration drops below this when the foot
  /// is airborne. The gap between 12.0 and 2.5 provides hysteresis so small
  /// vibrations during stance do not spuriously trigger takeoff.
  static const double _takeoffThreshold = 2.5;

  /// Minimum interval between consecutive impacts (ms).
  /// Derived from physiological maximum of ~300 spm → 200 ms/step.
  static const int _minStepMs = 200;

  /// Maximum plausible ground contact time (ms).
  /// Values > 500 ms indicate sensor noise or standing still — discarded.
  static const int _maxContactMs = 500;

  /// Minimum plausible contact time (ms).
  /// Values < 50 ms are sensor noise — discarded (see running_biomechanics.md).
  static const int _minContactMs = 50;

  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------

  /// Whether the foot is currently in the stance (ground contact) phase.
  bool _inStance = false;

  /// Timestamp of the last accepted impact event (ms). 0 = no impact yet.
  int _lastImpactMs = 0;

  /// Timestamp at which the current stance phase started (ms).
  int _stanceStartMs = 0;

  // -------------------------------------------------------------------------
  // Callback
  // -------------------------------------------------------------------------

  /// Called when a [GaitEvent] is detected.
  ///
  /// Parameters:
  ///   - [event]       — [GaitEvent.impact] or [GaitEvent.takeoff]
  ///   - [nodeId]      — e.g. "LEFT_ANKLE"
  ///   - [timestampMs] — monotonic ms counter from [SensorData]
  ///   - [value]       — for impact: foot pitch in degrees;
  ///                     for takeoff: ground contact time in ms
  final void Function(
    GaitEvent event,
    String nodeId,
    int timestampMs,
    double value,
  ) onEvent;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------

  GaitEventDetector({required this.onEvent});

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Feed a single [SensorData] sample into the detector.
  ///
  /// Must be called for every packet from this node, in chronological order.
  void process(SensorData s) {
    final double mag = _accelMagnitude(s);

    if (!_inStance) {
      _handleSwingPhase(s, mag);
    } else {
      _handleStancePhase(s, mag);
    }
  }

  /// Reset detector state (e.g. when the session is paused or restarted).
  void reset() {
    _inStance = false;
    _lastImpactMs = 0;
    _stanceStartMs = 0;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Euclidean magnitude of the linear acceleration vector.
  double _accelMagnitude(SensorData s) =>
      sqrt(s.accelX * s.accelX + s.accelY * s.accelY + s.accelZ * s.accelZ);

  /// Logic executed while the foot is in the swing (airborne) phase.
  /// Transitions to stance when a valid impact spike is detected.
  void _handleSwingPhase(SensorData s, double mag) {
    if (mag < _impactThreshold) return;

    // Reject impacts that arrive too soon after the previous one (anti-bounce).
    final int interval = s.timestampMs - _lastImpactMs;
    final bool firstImpact = _lastImpactMs == 0;
    if (!firstImpact && interval < _minStepMs) return;

    // Valid impact — transition to stance phase.
    _inStance = true;
    _stanceStartMs = s.timestampMs;
    _lastImpactMs = s.timestampMs;

    // Report foot pitch angle as the biomechanically relevant value.
    onEvent(GaitEvent.impact, s.nodeId, s.timestampMs, s.pitch);
  }

  /// Logic executed while the foot is in the stance (ground contact) phase.
  /// Transitions to swing when acceleration drops below the takeoff threshold.
  void _handleStancePhase(SensorData s, double mag) {
    if (mag >= _takeoffThreshold) return;

    final int contactMs = s.timestampMs - _stanceStartMs;

    // Discard physiologically impossible contact durations.
    if (contactMs < _minContactMs || contactMs > _maxContactMs) {
      // Still end the stance to avoid getting stuck.
      _inStance = false;
      return;
    }

    // Valid takeoff — transition back to swing phase.
    _inStance = false;
    onEvent(GaitEvent.takeoff, s.nodeId, s.timestampMs, contactMs.toDouble());
  }
}
