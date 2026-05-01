// lib/analysis/gait_event_detector.dart
//
// Detects foot-strike and toe-off events from raw IMU samples at 100 Hz.
// Uses linear acceleration magnitude (gravity already removed by BNO085's
// SH2_LINEAR_ACCELERATION report) so orientation of the node doesn't matter
// for threshold comparison.
//
// References:
//   - Heiderscheit et al. (2011) — impact thresholds and debounce intervals
//   - running_biomechanics.md — validated physiological thresholds

import 'dart:math' as math;
import '../../../../../../skills/flutter-ble-workspace/iteration-1/eval-2-sensor-parser/with_skill/outputs/sensor_data.dart';

// ---------------------------------------------------------------------------
// Enums and data classes
// ---------------------------------------------------------------------------

/// Phases of one foot's gait cycle.
enum GaitPhase { flight, loading, stance }

/// Type of gait event detected.
enum GaitEventType { impact, takeoff }

/// A single detected foot event (impact or takeoff) for one ankle node.
class GaitEvent {
  /// Which ankle produced this event ('LEFT_ANKLE' | 'RIGHT_ANKLE').
  final String nodeId;

  /// Whether this is a foot-strike (impact) or a toe-off (takeoff).
  final GaitEventType type;

  /// Session-relative timestamp in milliseconds.
  final int timestampMs;

  /// Peak linear acceleration magnitude at the moment of the event (m/s²).
  /// For impact events this is the value at first threshold crossing;
  /// for takeoff events this is the highest peak recorded during stance.
  final double peakAccelMs2;

  /// Pitch angle of the ankle node at the moment of the event (degrees).
  /// Positive → heel strike, negative → forefoot strike (BNO085 convention).
  final double strikeAngleDeg;

  const GaitEvent({
    required this.nodeId,
    required this.type,
    required this.timestampMs,
    required this.peakAccelMs2,
    required this.strikeAngleDeg,
  });

  @override
  String toString() =>
      'GaitEvent(node=$nodeId, type=$type, ts=${timestampMs}ms, '
      'peak=${peakAccelMs2.toStringAsFixed(1)} m/s², '
      'angle=${strikeAngleDeg.toStringAsFixed(1)}°)';
}

// ---------------------------------------------------------------------------
// Detector (one instance per foot)
// ---------------------------------------------------------------------------

/// Processes a stream of [SensorData] samples from one ankle node and emits
/// [GaitEvent]s when a foot-strike or toe-off is detected.
///
/// Typical usage:
/// ```dart
/// final detector = GaitEventDetector();
/// final event = detector.processSample(sample);
/// if (event != null) stridePipeline.onEvent(event);
/// ```
///
/// Create one detector per foot; do NOT share a single instance between
/// LEFT_ANKLE and RIGHT_ANKLE streams.
class GaitEventDetector {
  // -------------------------------------------------------------------------
  // Configurable thresholds (see running_biomechanics.md for evidence)
  // -------------------------------------------------------------------------

  /// Acceleration magnitude above which a foot-strike is declared (m/s²).
  /// Default 12 m/s² suits recreational running at 4–6 min/km pace.
  /// Adjust upward (18–25) for faster athletes after hardware calibration.
  final double impactThresholdMs2;

  /// Acceleration magnitude below which the foot is considered airborne (m/s²).
  /// BNO085 linear acceleration ≈ 0 during free flight; 2 m/s² adds margin
  /// for arm swing and vibration noise.
  final double flightThresholdMs2;

  /// Minimum time between consecutive impacts of the same foot (ms).
  /// Physiological maximum step rate ≈ 4 Hz → 250 ms minimum interval.
  /// Prevents double-detection from sensor ringing after a hard landing.
  final int minStepIntervalMs;

  // -------------------------------------------------------------------------
  // Internal state
  // -------------------------------------------------------------------------

  GaitPhase _phase = GaitPhase.flight;
  int _lastImpactMs = 0;
  double _peakDuringStance = 0.0;

  GaitEventDetector({
    this.impactThresholdMs2 = 12.0,
    this.flightThresholdMs2 = 2.0,
    this.minStepIntervalMs = 250,
  });

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Feed one IMU sample; returns a [GaitEvent] if an event was detected,
  /// or null if the sample did not trigger a state transition.
  GaitEvent? processSample(SensorData sample) {
    final accel = _linearAccelMagnitude(sample);
    GaitEvent? event;

    switch (_phase) {
      case GaitPhase.flight:
        // Rising edge: acceleration crosses impact threshold
        if (accel > impactThresholdMs2) {
          final interval = sample.timestampMs - _lastImpactMs;
          if (interval > minStepIntervalMs) {
            _phase = GaitPhase.loading;
            _peakDuringStance = accel;
            _lastImpactMs = sample.timestampMs;
            event = GaitEvent(
              nodeId: sample.nodeId,
              type: GaitEventType.impact,
              timestampMs: sample.timestampMs,
              peakAccelMs2: accel,
              strikeAngleDeg: sample.pitch,
            );
          }
        }
        break;

      case GaitPhase.loading:
        // Transition immediately to full stance; keep tracking peak
        _phase = GaitPhase.stance;
        if (accel > _peakDuringStance) _peakDuringStance = accel;
        // Also check for a very brief contact (unlikely, but guarded)
        if (accel < flightThresholdMs2) {
          event = _buildTakeoffEvent(sample);
        }
        break;

      case GaitPhase.stance:
        // Track stance-phase peak for richer data
        if (accel > _peakDuringStance) _peakDuringStance = accel;
        // Falling edge: acceleration drops below flight threshold → toe-off
        if (accel < flightThresholdMs2) {
          event = _buildTakeoffEvent(sample);
        }
        break;
    }

    return event;
  }

  /// Reset detector state (call when a new session starts).
  void reset() {
    _phase = GaitPhase.flight;
    _lastImpactMs = 0;
    _peakDuringStance = 0.0;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  GaitEvent _buildTakeoffEvent(SensorData sample) {
    _phase = GaitPhase.flight;
    final peak = _peakDuringStance;
    _peakDuringStance = 0.0;
    return GaitEvent(
      nodeId: sample.nodeId,
      type: GaitEventType.takeoff,
      timestampMs: sample.timestampMs,
      peakAccelMs2: peak,
      strikeAngleDeg: sample.pitch,
    );
  }

  /// Compute the magnitude of the linear acceleration vector (m/s²).
  /// BNO085 already strips gravity, so this is purely motion-induced
  /// acceleration — ideal for impact detection regardless of node orientation.
  double _linearAccelMagnitude(SensorData s) => math.sqrt(
        s.accelX * s.accelX + s.accelY * s.accelY + s.accelZ * s.accelZ,
      );
}
