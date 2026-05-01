import 'dart:math' as math;
import 'event_detector.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

/// One completed stride step: the interval between two consecutive heel
/// strikes on the **same** foot.
class StepRecord {
  /// Timestamp (ms) of the heel strike that opened this step.
  final int impactTimestampMs;

  /// Timestamp (ms) of the toe-off that closed the stance phase.
  final int toeOffTimestampMs;

  /// Contact time = toe-off minus heel-strike (ms).
  int get contactTimeMs => toeOffTimestampMs - impactTimestampMs;

  /// Acceleration magnitude at heel strike (m/s²) — proxy for strike angle.
  final double impactAccelMagnitude;

  const StepRecord({
    required this.impactTimestampMs,
    required this.toeOffTimestampMs,
    required this.impactAccelMagnitude,
  });
}

/// Identifies which foot a sensor is attached to.
enum FootSide { left, right }

/// Aggregated running biomechanics metrics computed over the sliding window.
class RunningMetrics {
  /// Steps per minute (both feet combined).
  final double cadenceSpm;

  /// Symmetry index: 0 = perfect symmetry, positive = right dominant,
  /// negative = left dominant.  Range roughly −1 to +1.
  /// Formula: (rightMean − leftMean) / ((rightMean + leftMean) / 2)
  final double symmetryIndex;

  /// Mean ground-contact time across all steps in the window (ms).
  final double meanContactTimeMs;

  /// Mean strike angle proxy (m/s²) — higher values indicate harder,
  /// more heel-dominant landing.
  final double meanStrikeAngleProxy;

  /// Coefficient of variation (%) for step interval — measure of rhythm
  /// consistency. Lower is more consistent.
  final double stepIntervalVariabilityPct;

  /// Number of steps (per foot) used to compute these metrics.
  final int leftStepCount;
  final int rightStepCount;

  /// Timestamp (ms) of the most recent event used in this computation.
  final int computedAtMs;

  const RunningMetrics({
    required this.cadenceSpm,
    required this.symmetryIndex,
    required this.meanContactTimeMs,
    required this.meanStrikeAngleProxy,
    required this.stepIntervalVariabilityPct,
    required this.leftStepCount,
    required this.rightStepCount,
    required this.computedAtMs,
  });

  /// Human-readable symmetry label.
  String get symmetryLabel {
    final abs = symmetryIndex.abs();
    if (abs < 0.05) return 'Symmetric';
    if (symmetryIndex > 0) return 'Right dominant';
    return 'Left dominant';
  }

  @override
  String toString() => 'RunningMetrics('
      'cadence=${cadenceSpm.toStringAsFixed(1)} spm, '
      'symmetry=${(symmetryIndex * 100).toStringAsFixed(1)}%, '
      'contactTime=${meanContactTimeMs.toStringAsFixed(0)} ms, '
      'strikeProxy=${meanStrikeAngleProxy.toStringAsFixed(2)} m/s², '
      'variability=${stepIntervalVariabilityPct.toStringAsFixed(1)}%, '
      'L=$leftStepCount R=$rightStepCount)';
}

// ── Calculator ────────────────────────────────────────────────────────────────

/// Computes running biomechanics metrics from gait events.
///
/// Feed events from [EventDetector] instances (one per foot) via [addEvent].
/// After each addition [currentMetrics] is recomputed over a sliding window
/// of the last [windowSize] completed steps per foot.
///
/// Metrics computed:
/// - **Cadence** (steps/min) — based on heel-strike timestamps.
/// - **L/R Symmetry** — ratio of mean contact-time left vs right.
/// - **Contact time** — heel-strike to toe-off interval.
/// - **Strike angle proxy** — impact acceleration magnitude.
/// - **Step-interval variability** — CV% of inter-step durations.
class MetricsCalculator {
  // ── Configuration ─────────────────────────────────────────────────────────

  /// Number of completed steps per foot to keep in the sliding window.
  final int windowSize;

  // ── State ─────────────────────────────────────────────────────────────────

  // Pending heel-strike events waiting for their matching toe-off.
  GaitEvent? _pendingLeftImpact;
  GaitEvent? _pendingRightImpact;

  // Completed step records per foot (capped at [windowSize]).
  final List<StepRecord> _leftSteps = [];
  final List<StepRecord> _rightSteps = [];

  // Heel-strike timestamps used for cadence / variability (capped at
  // windowSize + 1 so we can compute windowSize inter-step intervals).
  final List<int> _leftImpactTs = [];
  final List<int> _rightImpactTs = [];

  RunningMetrics? _cachedMetrics;

  // ── Constructor ───────────────────────────────────────────────────────────

  MetricsCalculator({this.windowSize = 10})
      : assert(windowSize >= 2, 'windowSize must be at least 2');

  // ── Public API ────────────────────────────────────────────────────────────

  /// The most recently computed metrics, or null if not enough data yet.
  RunningMetrics? get currentMetrics => _cachedMetrics;

  /// Feed a gait event from a specific foot's [EventDetector].
  ///
  /// Call this in the order events are received. After each toe-off that
  /// completes a step, metrics are recomputed automatically.
  void addEvent(GaitEvent event, FootSide side) {
    switch (event.type) {
      case GaitEventType.heelStrike:
        _handleImpact(event, side);

      case GaitEventType.toeOff:
        _handleToeOff(event, side);
    }
  }

  /// Feed multiple events at once (order must be chronological).
  void addEvents(List<GaitEvent> events, FootSide side) {
    for (final e in events) {
      addEvent(e, side);
    }
  }

  /// Reset all buffers and cached metrics.
  void reset() {
    _pendingLeftImpact = null;
    _pendingRightImpact = null;
    _leftSteps.clear();
    _rightSteps.clear();
    _leftImpactTs.clear();
    _rightImpactTs.clear();
    _cachedMetrics = null;
  }

  // ── Event handling ────────────────────────────────────────────────────────

  void _handleImpact(GaitEvent event, FootSide side) {
    if (side == FootSide.left) {
      _pendingLeftImpact = event;
      _addImpactTs(_leftImpactTs, event.timestampMs);
    } else {
      _pendingRightImpact = event;
      _addImpactTs(_rightImpactTs, event.timestampMs);
    }
  }

  void _handleToeOff(GaitEvent event, FootSide side) {
    final pending =
        side == FootSide.left ? _pendingLeftImpact : _pendingRightImpact;

    if (pending == null) return; // No matching heel strike recorded yet.

    final record = StepRecord(
      impactTimestampMs: pending.timestampMs,
      toeOffTimestampMs: event.timestampMs,
      impactAccelMagnitude: pending.accelMagnitude,
    );

    if (side == FootSide.left) {
      _pendingLeftImpact = null;
      _addStep(_leftSteps, record);
    } else {
      _pendingRightImpact = null;
      _addStep(_rightSteps, record);
    }

    // Recompute metrics whenever a step is completed on either foot.
    _recompute(event.timestampMs);
  }

  // ── Buffer management ─────────────────────────────────────────────────────

  void _addStep(List<StepRecord> buffer, StepRecord record) {
    buffer.add(record);
    if (buffer.length > windowSize) buffer.removeAt(0);
  }

  void _addImpactTs(List<int> buffer, int ts) {
    buffer.add(ts);
    // Keep one extra entry so we can compute [windowSize] intervals.
    if (buffer.length > windowSize + 1) buffer.removeAt(0);
  }

  // ── Metrics computation ───────────────────────────────────────────────────

  void _recompute(int nowMs) {
    // Need at least 2 impacts per foot to derive cadence / variability.
    final hasLeft = _leftImpactTs.length >= 2 && _leftSteps.isNotEmpty;
    final hasRight = _rightImpactTs.length >= 2 && _rightSteps.isNotEmpty;

    if (!hasLeft && !hasRight) return;

    // Cadence — combine both feet's impact timestamps.
    final cadenceSpm = _computeCadence(nowMs);

    // Symmetry — compare mean contact times L vs R.
    final symmetryIndex = _computeSymmetry();

    // Mean contact time across both feet.
    final allSteps = [..._leftSteps, ..._rightSteps];
    final meanContact = _mean(allSteps.map((s) => s.contactTimeMs.toDouble()));

    // Strike angle proxy — mean impact acceleration across both feet.
    final meanStrikeProxy =
        _mean(allSteps.map((s) => s.impactAccelMagnitude));

    // Step-interval variability — combine inter-step intervals from both feet.
    final variability = _computeVariability();

    _cachedMetrics = RunningMetrics(
      cadenceSpm: cadenceSpm,
      symmetryIndex: symmetryIndex,
      meanContactTimeMs: meanContact,
      meanStrikeAngleProxy: meanStrikeProxy,
      stepIntervalVariabilityPct: variability,
      leftStepCount: _leftSteps.length,
      rightStepCount: _rightSteps.length,
      computedAtMs: nowMs,
    );
  }

  /// Cadence in steps/min using the elapsed time spanned by all impacts in
  /// both foot buffers.
  double _computeCadence(int nowMs) {
    final allTs = <int>[..._leftImpactTs, ..._rightImpactTs]..sort();
    if (allTs.length < 2) return 0.0;

    final spanMs = allTs.last - allTs.first;
    if (spanMs <= 0) return 0.0;

    // Number of inter-step intervals = allTs.length - 1
    final intervals = allTs.length - 1;
    final meanIntervalMs = spanMs / intervals;
    return 60000.0 / meanIntervalMs;
  }

  /// Symmetry index based on mean contact time.
  /// Returns 0 when data for only one foot is available.
  double _computeSymmetry() {
    if (_leftSteps.isEmpty || _rightSteps.isEmpty) return 0.0;

    final leftMean =
        _mean(_leftSteps.map((s) => s.contactTimeMs.toDouble()));
    final rightMean =
        _mean(_rightSteps.map((s) => s.contactTimeMs.toDouble()));

    final avg = (leftMean + rightMean) / 2.0;
    if (avg == 0) return 0.0;

    // Positive → right is longer (more dominant), negative → left.
    return (rightMean - leftMean) / avg;
  }

  /// Step-interval variability as coefficient of variation (%).
  double _computeVariability() {
    final intervals = <double>[];

    void extractIntervals(List<int> timestamps) {
      for (int i = 1; i < timestamps.length; i++) {
        intervals.add((timestamps[i] - timestamps[i - 1]).toDouble());
      }
    }

    extractIntervals(_leftImpactTs);
    extractIntervals(_rightImpactTs);

    if (intervals.length < 2) return 0.0;

    final mu = _mean(intervals);
    if (mu == 0) return 0.0;

    final sd = _stdDev(intervals, mu);
    return (sd / mu) * 100.0;
  }

  // ── Statistical helpers ───────────────────────────────────────────────────

  static double _mean(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0.0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  static double _stdDev(List<double> values, double mean) {
    if (values.length < 2) return 0.0;
    final variance =
        values.map((v) => math.pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) /
            (values.length - 1); // sample std dev
    return math.sqrt(variance);
  }
}
