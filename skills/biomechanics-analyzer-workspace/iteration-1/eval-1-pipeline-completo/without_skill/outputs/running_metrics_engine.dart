import 'dart:collection';
import 'stride_pipeline.dart';

// ── Aggregated running metrics ─────────────────────────────────────────────────

/// Snapshot of aggregated running metrics computed from the last N strides.
///
/// Exposed to the UI and to the [RecommendationEngine].
class RunningMetrics {
  /// Cadence in steps per minute (spm).
  /// Based on the average step interval across the sliding window.
  final double cadenceSpm;

  /// Left-foot load percentage (0–100). 50% = perfectly symmetric.
  /// > 50% means more load on the left foot.
  final double symmetryPct;

  /// Average ground contact time across the window (ms).
  final double avgContactTimeMs;

  /// Average foot-strike angle across the window (degrees).
  /// Negative = forefoot/midfoot; positive = heel strike.
  final double avgStrikeAngleDeg;

  /// Stride duration coefficient of variation (standard deviation / mean × 100).
  /// Lower = more consistent cadence.
  final double strideVariabilityCv;

  /// Number of strides included in this snapshot (up to [RunningMetricsEngine.windowSize]).
  final int strideCount;

  /// Timestamp of the most recent stride used (ms).
  final int lastTimestampMs;

  const RunningMetrics({
    required this.cadenceSpm,
    required this.symmetryPct,
    required this.avgContactTimeMs,
    required this.avgStrikeAngleDeg,
    required this.strideVariabilityCv,
    required this.strideCount,
    required this.lastTimestampMs,
  });

  @override
  String toString() => 'RunningMetrics{'
      'cadence=${cadenceSpm.toStringAsFixed(1)}spm, '
      'symmetry=${symmetryPct.toStringAsFixed(1)}%, '
      'contact=${avgContactTimeMs.toStringAsFixed(0)}ms, '
      'strike=${avgStrikeAngleDeg.toStringAsFixed(1)}°, '
      'cv=${strideVariabilityCv.toStringAsFixed(1)}%}';
}

// ── Engine ─────────────────────────────────────────────────────────────────────

/// Computes aggregated [RunningMetrics] from a sliding window of completed strides.
///
/// The window is configurable (default: 10 strides) and shared between both
/// feet. Metrics are recomputed every time a new stride is added.
///
/// ## Integration with StridePipeline
/// ```dart
/// final engine = RunningMetricsEngine(onMetricsUpdated: sessionProvider.updateMetrics);
/// final pipeline = StridePipeline(onStride: engine.addStride);
/// ```
class RunningMetricsEngine {
  /// Number of strides kept in the sliding window (default: 10).
  final int windowSize;

  /// Called each time a new [RunningMetrics] snapshot is computed.
  final void Function(RunningMetrics metrics)? onMetricsUpdated;

  // Sliding window — separate queues for each foot so symmetry is computed correctly.
  final Queue<StrideMetrics> _leftWindow = Queue();
  final Queue<StrideMetrics> _rightWindow = Queue();

  RunningMetricsEngine({
    this.windowSize = 10,
    this.onMetricsUpdated,
  });

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Add a completed stride to the sliding window and recompute metrics.
  ///
  /// Designed to be passed directly to [StridePipeline.onStride].
  void addStride(StrideMetrics stride) {
    final queue =
        stride.foot == Foot.left ? _leftWindow : _rightWindow;

    queue.addLast(stride);

    // Keep each queue at most [windowSize] strides (half the window per foot
    // so that the combined window stays at [windowSize] total).
    final halfWindow = (windowSize / 2).ceil();
    while (queue.length > halfWindow) {
      queue.removeFirst();
    }

    final metrics = _computeMetrics();
    if (metrics != null) {
      onMetricsUpdated?.call(metrics);
    }
  }

  /// Reset the engine (call on session stop / new session start).
  void reset() {
    _leftWindow.clear();
    _rightWindow.clear();
  }

  // ── Private computation ─────────────────────────────────────────────────────

  RunningMetrics? _computeMetrics() {
    // Require at least one stride per foot before emitting metrics.
    if (_leftWindow.isEmpty || _rightWindow.isEmpty) return null;

    final allStrides = [..._leftWindow, ..._rightWindow]
      ..sort((a, b) => a.strikeTimestampMs.compareTo(b.strikeTimestampMs));

    // ── Cadence ──────────────────────────────────────────────────────────────
    // Cadence = 60,000 / avgStepInterval × 2 steps per stride interval.
    // Here we treat each per-foot stride as a "step pair" at that foot's rate
    // and average both feet.
    final double leftCadence = _cadenceFromQueue(_leftWindow);
    final double rightCadence = _cadenceFromQueue(_rightWindow);
    final double cadence = (leftCadence + rightCadence) / 2.0;

    // ── Symmetry ─────────────────────────────────────────────────────────────
    // symmetry% = totalContactLeft / (totalContactLeft + totalContactRight) × 100
    final int totalLeftContact =
        _leftWindow.fold(0, (sum, s) => sum + s.contactTimeMs);
    final int totalRightContact =
        _rightWindow.fold(0, (sum, s) => sum + s.contactTimeMs);
    final double totalContact = (totalLeftContact + totalRightContact).toDouble();
    final double symmetry =
        totalContact > 0 ? (totalLeftContact / totalContact) * 100.0 : 50.0;

    // ── Average contact time ──────────────────────────────────────────────────
    final double avgContact = allStrides.isEmpty
        ? 0.0
        : allStrides.map((s) => s.contactTimeMs.toDouble()).reduce((a, b) => a + b) /
            allStrides.length;

    // ── Average strike angle ──────────────────────────────────────────────────
    final double avgStrike = allStrides.isEmpty
        ? 0.0
        : allStrides.map((s) => s.strikeAngleDeg).reduce((a, b) => a + b) /
            allStrides.length;

    // ── Stride variability (CV of stride durations) ───────────────────────────
    final double cv = _coefficientOfVariation(
      allStrides.map((s) => s.strideDurationMs.toDouble()).toList(),
    );

    return RunningMetrics(
      cadenceSpm: cadence,
      symmetryPct: symmetry,
      avgContactTimeMs: avgContact,
      avgStrikeAngleDeg: avgStrike,
      strideVariabilityCv: cv,
      strideCount: allStrides.length,
      lastTimestampMs: allStrides.last.strikeTimestampMs,
    );
  }

  /// Compute cadence (spm) from a queue of per-foot strides.
  ///
  /// Formula: 60,000 ms/min ÷ avgStrideDuration_ms × 2
  /// (×2 because one stride = two steps, one per foot)
  double _cadenceFromQueue(Queue<StrideMetrics> queue) {
    if (queue.isEmpty) return 0.0;
    final avgStride =
        queue.map((s) => s.strideDurationMs.toDouble()).reduce((a, b) => a + b) /
            queue.length;
    return avgStride > 0 ? (60000.0 / avgStride) * 2.0 : 0.0;
  }

  /// Coefficient of variation (%) = stdDev / mean × 100.
  double _coefficientOfVariation(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 0.0;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    return (variance > 0 ? variance : 0).abs() != 0
        ? (variance > 0 ? variance : -variance) == variance
            ? (100.0 * (variance > 0 ? _sqrt(variance) : 0) / mean)
            : 0.0
        : 0.0;
  }

  double _sqrt(double v) {
    // Simple Newton-Raphson to avoid dart:math import in this file.
    if (v <= 0) return 0;
    double x = v;
    for (int i = 0; i < 40; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }
}
