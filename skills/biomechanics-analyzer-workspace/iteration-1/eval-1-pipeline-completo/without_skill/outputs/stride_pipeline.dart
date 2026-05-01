import 'gait_event_detector.dart';

// ── Data types ─────────────────────────────────────────────────────────────────

/// Identifies which foot owns a measurement.
enum Foot { left, right }

/// Metrics computed from a single completed stride (one foot-strike to the
/// next foot-strike of the SAME foot).
///
/// All time values are in milliseconds; angles in degrees.
class StrideMetrics {
  /// Which foot this stride belongs to.
  final Foot foot;

  /// Stride duration (foot-strike N to foot-strike N+1 of same foot), ms.
  final int strideDurationMs;

  /// Ground contact time (foot-strike to toe-off), ms.
  final int contactTimeMs;

  /// Flight time (toe-off to next foot-strike), ms.
  final int flightTimeMs;

  /// Pitch angle at foot-strike (degrees). Negative = forefoot, positive = heel.
  final double strikeAngleDeg;

  /// Timestamp of the foot-strike that started this stride, ms.
  final int strikeTimestampMs;

  const StrideMetrics({
    required this.foot,
    required this.strideDurationMs,
    required this.contactTimeMs,
    required this.flightTimeMs,
    required this.strikeAngleDeg,
    required this.strikeTimestampMs,
  });

  @override
  String toString() => 'StrideMetrics{'
      'foot=$foot, '
      'stride=${strideDurationMs}ms, '
      'contact=${contactTimeMs}ms, '
      'flight=${flightTimeMs}ms, '
      'strike=${strikeAngleDeg.toStringAsFixed(1)}°}';
}

// ── Per-foot stride accumulator ────────────────────────────────────────────────

/// Accumulates raw gait events for one foot and emits [StrideMetrics] when a
/// full stride is complete.
///
/// A stride is defined as:
///   foot-strike[n] → toe-off[n] → foot-strike[n+1]
///
/// Usage:
/// ```dart
/// final leftStride = _StrideAccumulator(Foot.left);
/// leftDetector.onFootStrike = (e) => leftStride.onStrike(e);
/// leftDetector.onToeOff     = (e) => leftStride.onToeOff(e);
/// leftStride.onStrideComplete = (metrics) { /* use metrics */ };
/// ```
class _StrideAccumulator {
  final Foot foot;

  void Function(StrideMetrics metrics)? onStrideComplete;

  // Pending events for the current stride.
  GaitEvent? _pendingStrike;
  GaitEvent? _pendingToeOff;

  // Contact-time validity range (ms) — reject physiologically impossible values.
  static const int _minContactMs = 50;
  static const int _maxContactMs = 500;

  _StrideAccumulator(this.foot);

  void onStrike(GaitEvent event) {
    if (_pendingStrike == null) {
      // First strike ever — start accumulating.
      _pendingStrike = event;
      _pendingToeOff = null;
      return;
    }

    if (_pendingToeOff == null) {
      // Got a second strike without a toe-off in between — detector glitch;
      // replace the old strike and keep going.
      _pendingStrike = event;
      return;
    }

    // Complete stride: pendingStrike → pendingToeOff → event (next strike)
    final strideDuration = event.timestampMs - _pendingStrike!.timestampMs;
    final contactTime = _pendingToeOff!.timestampMs - _pendingStrike!.timestampMs;
    final flightTime = event.timestampMs - _pendingToeOff!.timestampMs;

    // Validate contact time to guard against sensor artifacts.
    if (contactTime >= _minContactMs && contactTime <= _maxContactMs) {
      final metrics = StrideMetrics(
        foot: foot,
        strideDurationMs: strideDuration,
        contactTimeMs: contactTime,
        flightTimeMs: flightTime,
        strikeAngleDeg: _pendingStrike!.pitchDeg,
        strikeTimestampMs: _pendingStrike!.timestampMs,
      );
      onStrideComplete?.call(metrics);
    }

    // Start next stride from the current strike.
    _pendingStrike = event;
    _pendingToeOff = null;
  }

  void onToeOff(GaitEvent event) {
    if (_pendingStrike != null) {
      _pendingToeOff = event;
    }
  }

  void reset() {
    _pendingStrike = null;
    _pendingToeOff = null;
  }
}

// ── Public pipeline facade ─────────────────────────────────────────────────────

/// Wires two [GaitEventDetector] instances (left + right foot) to two
/// [_StrideAccumulator] instances and surfaces completed [StrideMetrics].
///
/// ## Integration
/// ```dart
/// final pipeline = StridePipeline(
///   onStride: (metrics) => metricsEngine.addStride(metrics),
/// );
///
/// // In your BLE callback for left ankle:
/// pipeline.processLeftSample(imuSample);
///
/// // In your BLE callback for right ankle:
/// pipeline.processRightSample(imuSample);
/// ```
class StridePipeline {
  /// Called every time a complete stride is detected on either foot.
  final void Function(StrideMetrics metrics) onStride;

  late final GaitEventDetector _leftDetector;
  late final GaitEventDetector _rightDetector;
  late final _StrideAccumulator _leftAccum;
  late final _StrideAccumulator _rightAccum;

  StridePipeline({
    required this.onStride,
    double impactThreshold = 12.0,
    double flightThreshold = 2.0,
    int minStepIntervalMs = 250,
  }) {
    _leftAccum = _StrideAccumulator(Foot.left)
      ..onStrideComplete = onStride;

    _rightAccum = _StrideAccumulator(Foot.right)
      ..onStrideComplete = onStride;

    _leftDetector = GaitEventDetector(
      impactThreshold: impactThreshold,
      flightThreshold: flightThreshold,
      minStepIntervalMs: minStepIntervalMs,
      onFootStrike: _leftAccum.onStrike,
      onToeOff: _leftAccum.onToeOff,
    );

    _rightDetector = GaitEventDetector(
      impactThreshold: impactThreshold,
      flightThreshold: flightThreshold,
      minStepIntervalMs: minStepIntervalMs,
      onFootStrike: _rightAccum.onStrike,
      onToeOff: _rightAccum.onToeOff,
    );
  }

  /// Feed a new IMU sample from the left ankle node.
  void processLeftSample(ImuSample sample) => _leftDetector.processSample(sample);

  /// Feed a new IMU sample from the right ankle node.
  void processRightSample(ImuSample sample) => _rightDetector.processSample(sample);

  /// Reset both detectors and accumulators (e.g., on session stop).
  void reset() {
    _leftDetector.reset();
    _rightDetector.reset();
    _leftAccum.reset();
    _rightAccum.reset();
  }
}
