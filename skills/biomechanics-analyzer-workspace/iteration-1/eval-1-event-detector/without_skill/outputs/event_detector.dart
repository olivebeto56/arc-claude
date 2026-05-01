import 'dart:math' as math;

/// Represents a single IMU sample from the ankle sensor.
class ImuSample {
  /// Timestamp in milliseconds since epoch (or session start).
  final int timestampMs;

  /// Linear acceleration magnitude in m/s².
  final double accelMagnitude;

  /// Raw acceleration components (optional, for richer analysis).
  final double ax;
  final double ay;
  final double az;

  const ImuSample({
    required this.timestampMs,
    required this.accelMagnitude,
    this.ax = 0.0,
    this.ay = 0.0,
    this.az = 0.0,
  });

  /// Convenience factory that computes magnitude from components.
  factory ImuSample.fromComponents({
    required int timestampMs,
    required double ax,
    required double ay,
    required double az,
  }) {
    final mag = math.sqrt(ax * ax + ay * ay + az * az);
    return ImuSample(
      timestampMs: timestampMs,
      accelMagnitude: mag,
      ax: ax,
      ay: ay,
      az: az,
    );
  }
}

/// The type of gait event detected.
enum GaitEventType {
  /// Foot strikes the ground — acceleration spike above [impactThreshold].
  heelStrike,

  /// Foot leaves the ground — acceleration drops below [takeoffThreshold].
  toeOff,
}

/// A single detected gait event.
class GaitEvent {
  final GaitEventType type;

  /// Timestamp (ms) of the sample that triggered this event.
  final int timestampMs;

  /// Acceleration magnitude (m/s²) at the moment of the event.
  final double accelMagnitude;

  const GaitEvent({
    required this.type,
    required this.timestampMs,
    required this.accelMagnitude,
  });

  @override
  String toString() =>
      'GaitEvent(${type.name}, t=${timestampMs}ms, a=${accelMagnitude.toStringAsFixed(2)} m/s²)';
}

/// Detects heel-strike and toe-off events from a stream of IMU acceleration
/// samples.
///
/// Detection logic:
/// - **Heel strike**: acceleration rises above [impactThreshold] (12 m/s²).
///   A new strike is only registered if at least [minStepIntervalMs] (200 ms)
///   have passed since the last impact, preventing double-detection on the
///   same footfall.
/// - **Toe-off**: after a heel strike, acceleration falls below
///   [takeoffThreshold] (2.5 m/s²) while the foot is in the stance phase.
///
/// State machine per instance (one instance per foot/node):
///
///   AIRBORNE  ──(accel ≥ impactThreshold && gap ≥ minStep)──►  STANCE
///   STANCE    ──(accel <  takeoffThreshold)──────────────────►  AIRBORNE
///
class EventDetector {
  // ── Thresholds ────────────────────────────────────────────────────────────

  /// Acceleration magnitude (m/s²) that triggers a heel-strike event.
  final double impactThreshold;

  /// Acceleration magnitude (m/s²) below which a toe-off event is fired.
  final double takeoffThreshold;

  /// Minimum time (ms) between two consecutive heel-strike events.
  /// Prevents multiple detections for the same footfall; 200 ms ≈ 5 Hz max
  /// cadence, well above any realistic running cadence.
  final int minStepIntervalMs;

  // ── Internal state ────────────────────────────────────────────────────────

  _FootState _state = _FootState.airborne;

  /// Timestamp (ms) of the most recently detected heel strike.
  int? _lastImpactTimestampMs;

  /// All events emitted since the detector was created / last reset.
  final List<GaitEvent> _events = [];

  // ── Constructor ───────────────────────────────────────────────────────────

  EventDetector({
    this.impactThreshold = 12.0,
    this.takeoffThreshold = 2.5,
    this.minStepIntervalMs = 200,
  }) : assert(impactThreshold > takeoffThreshold,
            'impactThreshold must be greater than takeoffThreshold');

  // ── Public API ────────────────────────────────────────────────────────────

  /// Unmodifiable view of all events emitted so far.
  List<GaitEvent> get events => List.unmodifiable(_events);

  /// Only heel-strike events.
  List<GaitEvent> get heelStrikes =>
      _events.where((e) => e.type == GaitEventType.heelStrike).toList();

  /// Only toe-off events.
  List<GaitEvent> get toeOffs =>
      _events.where((e) => e.type == GaitEventType.toeOff).toList();

  /// Current foot phase.
  bool get isInStance => _state == _FootState.stance;

  /// Process a single IMU sample. Returns any event(s) that were fired, or an
  /// empty list if no transition occurred.
  List<GaitEvent> processSample(ImuSample sample) {
    final fired = <GaitEvent>[];

    switch (_state) {
      case _FootState.airborne:
        if (_shouldFireImpact(sample)) {
          final event = GaitEvent(
            type: GaitEventType.heelStrike,
            timestampMs: sample.timestampMs,
            accelMagnitude: sample.accelMagnitude,
          );
          _events.add(event);
          fired.add(event);
          _lastImpactTimestampMs = sample.timestampMs;
          _state = _FootState.stance;
        }

      case _FootState.stance:
        if (sample.accelMagnitude < takeoffThreshold) {
          final event = GaitEvent(
            type: GaitEventType.toeOff,
            timestampMs: sample.timestampMs,
            accelMagnitude: sample.accelMagnitude,
          );
          _events.add(event);
          fired.add(event);
          _state = _FootState.airborne;
        }
    }

    return fired;
  }

  /// Process a batch of samples in order. Returns all events emitted.
  List<GaitEvent> processBatch(List<ImuSample> samples) {
    final allFired = <GaitEvent>[];
    for (final s in samples) {
      allFired.addAll(processSample(s));
    }
    return allFired;
  }

  /// Reset detector state (keeps threshold settings, clears event history).
  void reset() {
    _state = _FootState.airborne;
    _lastImpactTimestampMs = null;
    _events.clear();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  bool _shouldFireImpact(ImuSample sample) {
    if (sample.accelMagnitude < impactThreshold) return false;

    // Enforce minimum step interval to avoid double-counting.
    final last = _lastImpactTimestampMs;
    if (last != null) {
      final gap = sample.timestampMs - last;
      if (gap < minStepIntervalMs) return false;
    }

    return true;
  }
}

/// Internal state of the foot in the gait cycle.
enum _FootState {
  /// Foot is off the ground (swing / flight phase).
  airborne,

  /// Foot is in contact with the ground (stance phase).
  stance,
}
