import 'dart:math' as math;

/// Sensor sample consumed by the detector.
/// Both nodes feed their own [GaitEventDetector] instance.
class ImuSample {
  final int timestampMs;
  final double accelX;
  final double accelY;
  final double accelZ;

  /// Pitch angle in degrees (ankle node, BNO085 convention).
  /// Negative → forefoot/midfoot strike. Positive → heel strike.
  final double pitchDeg;

  const ImuSample({
    required this.timestampMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.pitchDeg,
  });

  /// Linear-acceleration magnitude in m/s² (gravity already removed by BNO085).
  double get accelMagnitude =>
      math.sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
}

// ── Gait phase state machine ──────────────────────────────────────────────────

/// Phases of a single gait cycle detected per foot.
enum GaitPhase {
  /// Foot is airborne; linear acceleration is near zero.
  flight,

  /// Foot is approaching the ground; acceleration rising past [GaitEventDetector.impactThreshold].
  loading,

  /// Foot is in contact with the ground; acceleration dropped below [GaitEventDetector.flightThreshold].
  stance,
}

/// A detected gait event (foot-strike or toe-off).
class GaitEvent {
  final GaitEventType type;

  /// Timestamp of the event in milliseconds.
  final int timestampMs;

  /// Pitch angle at the moment of the event (degrees). Meaningful for [GaitEventType.footStrike].
  final double pitchDeg;

  const GaitEvent({
    required this.type,
    required this.timestampMs,
    required this.pitchDeg,
  });

  @override
  String toString() =>
      'GaitEvent{type=$type, ts=${timestampMs}ms, pitch=${pitchDeg.toStringAsFixed(1)}°}';
}

enum GaitEventType { footStrike, toeOff }

// ── Detector ──────────────────────────────────────────────────────────────────

/// State-machine gait event detector for a single ankle IMU node.
///
/// Feed every sensor sample via [processSample]. The detector fires
/// [onFootStrike] and [onToeOff] callbacks when phase transitions occur.
///
/// ## State transitions
///
/// ```
/// flight ──(accel > impactThreshold)──► loading
/// loading ──(accel > impactThreshold, after debounce)──► stance  [fires footStrike]
/// stance ──(accel < flightThreshold)──► flight  [fires toeOff]
/// flight ──(accel > impactThreshold, debounce ok)──► loading
/// ```
class GaitEventDetector {
  // ── Thresholds (m/s²) ────────────────────────────────────────────────────────

  /// Acceleration magnitude above which we consider the foot to be in loading/stance.
  /// Based on running_biomechanics.md: 12 m/s² for recreational pace (4–6 min/km).
  final double impactThreshold;

  /// Acceleration magnitude below which we consider the foot to be in flight.
  final double flightThreshold;

  /// Minimum interval between two consecutive foot-strikes (debounce, ms).
  /// Physiological limit: max ~4 Hz steps → 250 ms minimum.
  final int minStepIntervalMs;

  // ── Callbacks ────────────────────────────────────────────────────────────────

  /// Called when a foot-strike is confirmed.
  final void Function(GaitEvent event)? onFootStrike;

  /// Called when a toe-off is detected.
  final void Function(GaitEvent event)? onToeOff;

  // ── Internal state ────────────────────────────────────────────────────────────

  GaitPhase _phase = GaitPhase.flight;
  GaitPhase get phase => _phase;

  int? _lastStrikeTimestampMs;
  int? _loadingStartMs;

  GaitEventDetector({
    this.impactThreshold = 12.0,
    this.flightThreshold = 2.0,
    this.minStepIntervalMs = 250,
    this.onFootStrike,
    this.onToeOff,
  });

  /// Feed a new [ImuSample] into the detector.
  ///
  /// Returns the [GaitEvent] if one was emitted this sample, or null.
  GaitEvent? processSample(ImuSample sample) {
    final mag = sample.accelMagnitude;

    switch (_phase) {
      case GaitPhase.flight:
        if (mag >= impactThreshold) {
          // Check debounce
          if (_lastStrikeTimestampMs == null ||
              sample.timestampMs - _lastStrikeTimestampMs! >= minStepIntervalMs) {
            _phase = GaitPhase.loading;
            _loadingStartMs = sample.timestampMs;
          }
        }
        return null;

      case GaitPhase.loading:
        // Wait for the peak — transition to stance once still above threshold
        // (the loading phase is very short; we confirm on the same tick if valid).
        if (mag >= impactThreshold) {
          _phase = GaitPhase.stance;
          _lastStrikeTimestampMs = sample.timestampMs;

          final event = GaitEvent(
            type: GaitEventType.footStrike,
            timestampMs: sample.timestampMs,
            pitchDeg: sample.pitchDeg,
          );
          onFootStrike?.call(event);
          return event;
        } else {
          // False alarm — acceleration dropped before we could confirm; go back.
          _phase = GaitPhase.flight;
          _loadingStartMs = null;
        }
        return null;

      case GaitPhase.stance:
        if (mag < flightThreshold) {
          _phase = GaitPhase.flight;

          final event = GaitEvent(
            type: GaitEventType.toeOff,
            timestampMs: sample.timestampMs,
            pitchDeg: sample.pitchDeg,
          );
          onToeOff?.call(event);
          return event;
        }
        return null;
    }
  }

  /// Reset the detector to its initial state (e.g., when a session is stopped).
  void reset() {
    _phase = GaitPhase.flight;
    _lastStrikeTimestampMs = null;
    _loadingStartMs = null;
  }
}
