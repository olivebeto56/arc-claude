// lib/analysis/running_metrics_engine.dart
//
// Sliding-window aggregator that turns per-stride metrics into smooth,
// session-level running metrics ready for display and recommendation logic.
//
// Why a sliding window?
//   Individual strides have natural variance (terrain, fatigue, step-to-step
//   noise). Averaging over the last N strides produces stable numbers without
//   the latency of a full-session average. 10 strides ≈ 5–6 seconds of data
//   at recreational pace — responsive enough for real-time feedback.

import 'dart:math' as math;
import 'stride_pipeline.dart';

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

/// Aggregated running metrics computed over a sliding window of strides.
/// This is the output handed to [RecommendationEngine] and displayed in the UI.
class RunningMetrics {
  /// Average cadence over the current window (steps/min, both feet).
  final double cadenceStepsPerMin;

  /// Average left-foot share of contact time over the window (%).
  /// 50 % = symmetric; < 45 % or > 55 % triggers a recommendation.
  final double symmetryPercent;

  /// Mean ground-contact time averaged across left and right feet and
  /// across all strides in the window (ms).
  final double avgContactTimeMs;

  /// Average foot-strike angle at impact, mean of both feet over the window
  /// (degrees). Positive → heel strike, negative → forefoot strike.
  final double strikeAngleDeg;

  /// Coefficient of variation of cadence within the window (%).
  /// CV = (std_dev / mean) × 100. Values > 5 % indicate fatigue or terrain.
  final double strideVariability;

  /// Cumulative step count since session start.
  final int stepCount;

  /// Elapsed time since the session started.
  final Duration sessionDuration;

  const RunningMetrics({
    required this.cadenceStepsPerMin,
    required this.symmetryPercent,
    required this.avgContactTimeMs,
    required this.strikeAngleDeg,
    required this.strideVariability,
    required this.stepCount,
    required this.sessionDuration,
  });

  @override
  String toString() =>
      'RunningMetrics('
      'cadence=${cadenceStepsPerMin.toStringAsFixed(0)} spm, '
      'sym=${symmetryPercent.toStringAsFixed(1)}%, '
      'ct=${avgContactTimeMs.toStringAsFixed(0)}ms, '
      'strike=${strikeAngleDeg.toStringAsFixed(1)}°, '
      'var=${strideVariability.toStringAsFixed(1)}%, '
      'steps=$stepCount, '
      'dur=${sessionDuration.inSeconds}s)';
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

/// Accumulates [StrideMetrics] into a sliding window and computes
/// [RunningMetrics] after a minimum of 3 strides have been collected.
///
/// Usage:
/// ```dart
/// final engine = RunningMetricsEngine(windowSize: 10);
/// final metrics = engine.addStride(stride);
/// if (metrics != null) { /* update UI / feed recommendation engine */ }
/// ```
class RunningMetricsEngine {
  /// Number of most recent strides to include in the sliding average.
  /// 10 strides ≈ 5–6 s at 170 spm — balances smoothness and responsiveness.
  final int windowSize;

  /// Minimum strides before emitting metrics (avoids garbage values on startup).
  static const int _minStrides = 3;

  final List<StrideMetrics> _window = [];
  int _stepCount = 0;
  DateTime? _sessionStart;

  RunningMetricsEngine({this.windowSize = 10});

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Add one stride and return aggregated [RunningMetrics], or null if the
  /// window is still too small to produce reliable numbers.
  RunningMetrics? addStride(StrideMetrics stride) {
    _sessionStart ??= DateTime.now();

    // Each StrideMetrics represents one complete left+right step pair = 2 steps
    _stepCount += 2;

    _window.add(stride);
    if (_window.length > windowSize) _window.removeAt(0);

    if (_window.length < _minStrides) return null;

    return _aggregate();
  }

  /// Reset engine state (call when a new session starts).
  void reset() {
    _window.clear();
    _stepCount = 0;
    _sessionStart = null;
  }

  // ---------------------------------------------------------------------------
  // Aggregation
  // ---------------------------------------------------------------------------

  RunningMetrics _aggregate() {
    final cadences = _window.map((s) => s.cadenceStepsPerMin).toList();
    final avgCadence = _mean(cadences);
    final cadenceStd = _stdDev(cadences, avgCadence);

    final avgSymmetry = _mean(_window.map((s) => s.symmetryPercent));

    // Average contact time = mean of per-foot averages across window
    final avgContact = _mean(
      _window.map((s) => (s.contactTimeLeftMs + s.contactTimeRightMs) / 2.0),
    );

    // Strike angle = mean of per-foot averages across window
    final avgStrike = _mean(
      _window
          .map((s) => (s.strikeAngleLeftDeg + s.strikeAngleRightDeg) / 2.0),
    );

    // Coefficient of variation (%) — robustness guard: avoid division by zero
    final variability =
        avgCadence > 0 ? (cadenceStd / avgCadence) * 100.0 : 0.0;

    return RunningMetrics(
      cadenceStepsPerMin: avgCadence,
      symmetryPercent: avgSymmetry,
      avgContactTimeMs: avgContact,
      strikeAngleDeg: avgStrike,
      strideVariability: variability,
      stepCount: _stepCount,
      sessionDuration: DateTime.now().difference(_sessionStart!),
    );
  }

  // ---------------------------------------------------------------------------
  // Math helpers
  // ---------------------------------------------------------------------------

  double _mean(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0.0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  /// Population standard deviation.
  double _stdDev(List<double> values, double mean) {
    if (values.length < 2) return 0.0;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    return math.sqrt(variance);
  }
}
