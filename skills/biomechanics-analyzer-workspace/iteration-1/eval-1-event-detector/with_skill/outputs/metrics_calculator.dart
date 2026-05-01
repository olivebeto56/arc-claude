// lib/analysis/metrics_calculator.dart
//
// Computes running biomechanics metrics from gait events using a sliding
// window of the last 10 steps (configurable via _windowSteps).
//
// Metrics produced:
//   cadenceStepsPerMin  — 60000 / mean(step intervals)  [spm]
//   symmetryPercent     — leftContactTime / totalContactTime * 100  [%]
//   avgContactTimeMs    — mean GCT across both feet  [ms]
//   strikeAngleDeg      — mean foot pitch at impact across both feet  [°]
//   strideVariability   — CV of step intervals for left foot  [%]
//   stepCount           — total accumulated steps (injected by caller)
//
// Normative ranges used (running_biomechanics.md):
//   Cadence:         175–185 spm optimal; < 150 critical
//   Symmetry:        46–54% normal; < 43% or > 57% clinically significant
//   Contact time:    200–250 ms recreational typical; > 280 ms poor
//   Strike angle:    0–10° midfoot (optimal); > 20° severe heel strike
//   Stride CV:       3–6% normal; > 8% high variability
//
// References:
//   Heiderscheit et al. (2011); Zifchock et al. (2006); Morin et al. (2011)
//   Jordan et al. (2007); Lieberman et al. (2010)

import 'dart:math';

// ---------------------------------------------------------------------------
// RunningMetrics — output model
// ---------------------------------------------------------------------------

/// Snapshot of biomechanical metrics computed from the last [_windowSteps] steps.
class RunningMetrics {
  /// Current cadence in steps per minute (both feet combined).
  /// Optimal range: 175–185 spm. Critical below 150 spm.
  final double cadenceStepsPerMin;

  /// Symmetry as percentage of left-foot contact time vs total.
  /// 50 % = perfectly symmetric. Clinically significant outside 43–57 %.
  final double symmetryPercent;

  /// Mean ground contact time across both feet (ms).
  /// Recreational typical: 200–250 ms. > 280 ms = poor technique.
  final double avgContactTimeMs;

  /// Mean foot pitch angle at impact across both feet (degrees).
  /// 0–10° = midfoot (optimal). > 20° = severe heel strike.
  final double strikeAngleDeg;

  /// Coefficient of variation (%) of step intervals for the left foot.
  /// 3–6% = normal. > 8% = fatigued or inconsistent rhythm.
  final double strideVariability;

  /// Total number of steps detected since session start (injected by caller).
  final int stepCount;

  const RunningMetrics({
    required this.cadenceStepsPerMin,
    required this.symmetryPercent,
    required this.avgContactTimeMs,
    required this.strikeAngleDeg,
    required this.strideVariability,
    required this.stepCount,
  });

  /// Returns true when there is enough data for reliable metrics
  /// (at least half the sliding window filled on both feet).
  bool get isReliable => stepCount >= 6;

  @override
  String toString() => 'RunningMetrics('
      'cadence: ${cadenceStepsPerMin.toStringAsFixed(1)} spm, '
      'symmetry: ${symmetryPercent.toStringAsFixed(1)}%, '
      'contact: ${avgContactTimeMs.toStringAsFixed(0)} ms, '
      'strike: ${strikeAngleDeg.toStringAsFixed(1)}°, '
      'cv: ${strideVariability.toStringAsFixed(1)}%, '
      'steps: $stepCount)';
}

// ---------------------------------------------------------------------------
// MetricsCalculator
// ---------------------------------------------------------------------------

/// Stateful calculator that accumulates gait events and computes
/// [RunningMetrics] on demand using a sliding window of the last
/// [_windowSteps] steps per foot.
///
/// Typical integration inside RunningAnalyzer:
///
/// ```dart
/// final _calc = MetricsCalculator();
/// int _stepCount = 0;
///
/// void _onGaitEvent(GaitEvent event, String nodeId, int ts, double value) {
///   if (event == GaitEvent.impact) {
///     _stepCount++;
///     // value = pitch at impact; impactLoad must be computed separately
///     // (pass the accel magnitude at the peak from the detector if needed)
///     _calc.recordImpact(nodeId, ts, strikeAngle: value, impactLoad: 0.0);
///   } else {
///     // value = contactMs
///     _calc.recordContactTime(nodeId, contactMs: value);
///   }
///
///   final metrics = _calc.compute(_stepCount);
///   sessionProvider.updateMetrics(metrics);
/// }
/// ```
class MetricsCalculator {
  // -------------------------------------------------------------------------
  // Sliding window size
  // -------------------------------------------------------------------------

  /// Number of recent steps to keep in each rolling buffer.
  /// 10 steps ≈ 3–4 seconds at 175 spm — responsive but not noisy.
  static const int _windowSteps = 10;

  // -------------------------------------------------------------------------
  // Supported node IDs
  // -------------------------------------------------------------------------

  static const String _leftAnkle = 'LEFT_ANKLE';
  static const String _rightAnkle = 'RIGHT_ANKLE';
  static const List<String> _nodeIds = [_leftAnkle, _rightAnkle];

  // -------------------------------------------------------------------------
  // Sliding-window buffers
  // -------------------------------------------------------------------------

  /// Interval (ms) between consecutive impacts on the same foot.
  /// Used for cadence and stride variability.
  final Map<String, List<int>> _stepIntervals = {
    _leftAnkle: [],
    _rightAnkle: [],
  };

  /// Ground contact time (ms) per stance phase.
  final Map<String, List<double>> _contactTimes = {
    _leftAnkle: [],
    _rightAnkle: [],
  };

  /// Foot pitch (degrees) at the moment of impact — strike angle.
  final Map<String, List<double>> _strikeAngles = {
    _leftAnkle: [],
    _rightAnkle: [],
  };

  /// Peak acceleration magnitude (m/s²) at impact — impact load.
  final Map<String, List<double>> _impactLoads = {
    _leftAnkle: [],
    _rightAnkle: [],
  };

  /// Timestamp of the most recent accepted impact per foot.
  final Map<String, int> _lastImpactMs = {
    _leftAnkle: 0,
    _rightAnkle: 0,
  };

  // -------------------------------------------------------------------------
  // Public API — recording events
  // -------------------------------------------------------------------------

  /// Record an impact event for [nodeId].
  ///
  /// [timestampMs]  — monotonic timestamp from [SensorData]
  /// [strikeAngle]  — foot pitch at impact (degrees); positive = heel strike
  /// [impactLoad]   — accel magnitude at the impact peak (m/s²);
  ///                  pass 0.0 if not available from the detector
  void recordImpact(
    String nodeId,
    int timestampMs, {
    required double strikeAngle,
    required double impactLoad,
  }) {
    if (!_nodeIds.contains(nodeId)) return;

    // Compute and store the step interval if we already have a previous impact.
    final int prev = _lastImpactMs[nodeId]!;
    if (prev > 0) {
      final int interval = timestampMs - prev;
      // Sanity-check: discard absurd intervals (< 150 ms or > 2 s).
      if (interval >= 150 && interval <= 2000) {
        _stepIntervals[nodeId]!.add(interval);
        _trim(_stepIntervals[nodeId]!);
      }
    }

    _lastImpactMs[nodeId] = timestampMs;

    _strikeAngles[nodeId]!.add(strikeAngle);
    _trim(_strikeAngles[nodeId]!);

    _impactLoads[nodeId]!.add(impactLoad);
    _trim(_impactLoads[nodeId]!);
  }

  /// Record a ground contact time for [nodeId].
  ///
  /// [contactMs] — duration in milliseconds between impact and takeoff.
  /// Values outside 50–500 ms are silently discarded (sensor noise filter
  /// matches [GaitEventDetector] thresholds).
  void recordContactTime(String nodeId, {required double contactMs}) {
    if (!_nodeIds.contains(nodeId)) return;
    if (contactMs < 50 || contactMs > 500) return;

    _contactTimes[nodeId]!.add(contactMs);
    _trim(_contactTimes[nodeId]!);
  }

  // -------------------------------------------------------------------------
  // Public API — computing metrics
  // -------------------------------------------------------------------------

  /// Compute and return a [RunningMetrics] snapshot from the current buffers.
  ///
  /// [stepCount] is the total accumulated step count maintained by the caller.
  RunningMetrics compute(int stepCount) {
    return RunningMetrics(
      cadenceStepsPerMin: _computeCadence(),
      symmetryPercent: _computeSymmetry(),
      avgContactTimeMs: _computeAvgContactTime(),
      strikeAngleDeg: _computeAvgStrikeAngle(),
      strideVariability: _computeVariability(_leftAnkle),
      stepCount: stepCount,
    );
  }

  /// Reset all buffers (e.g. when a new session starts).
  void reset() {
    for (final id in _nodeIds) {
      _stepIntervals[id]!.clear();
      _contactTimes[id]!.clear();
      _strikeAngles[id]!.clear();
      _impactLoads[id]!.clear();
      _lastImpactMs[id] = 0;
    }
  }

  // -------------------------------------------------------------------------
  // Cadence
  // -------------------------------------------------------------------------

  /// Cadence in steps per minute, computed from the mean of all recent step
  /// intervals across both feet.
  ///
  /// Formula: 60 000 ms/min ÷ mean_interval_ms
  ///
  /// Note (running_biomechanics.md): Each foot contributes one step per
  /// stride. Two steps = one complete stride cycle.
  double _computeCadence() {
    final List<double> allIntervals = [
      ..._stepIntervals[_leftAnkle]!.map((i) => i.toDouble()),
      ..._stepIntervals[_rightAnkle]!.map((i) => i.toDouble()),
    ];
    if (allIntervals.isEmpty) return 0.0;
    final double meanInterval = _mean(allIntervals);
    return meanInterval > 0 ? 60000.0 / meanInterval : 0.0;
  }

  // -------------------------------------------------------------------------
  // Symmetry
  // -------------------------------------------------------------------------

  /// Left/right symmetry as percentage of left contact time vs total.
  ///
  /// 50 % = perfectly symmetric.
  /// < 43 % = clinically significant right-side dominance.
  /// > 57 % = clinically significant left-side dominance.
  ///
  /// Reference: Zifchock et al. (2006) — >10% asymmetry clinically significant.
  double _computeSymmetry() {
    final double cL = _mean(_contactTimes[_leftAnkle]!);
    final double cR = _mean(_contactTimes[_rightAnkle]!);
    final double total = cL + cR;
    if (total <= 0) return 50.0; // neutral default when no data
    return (cL / total) * 100.0;
  }

  // -------------------------------------------------------------------------
  // Average contact time
  // -------------------------------------------------------------------------

  double _computeAvgContactTime() {
    final List<double> all = [
      ..._contactTimes[_leftAnkle]!,
      ..._contactTimes[_rightAnkle]!,
    ];
    return _mean(all);
  }

  // -------------------------------------------------------------------------
  // Average strike angle
  // -------------------------------------------------------------------------

  double _computeAvgStrikeAngle() {
    final List<double> all = [
      ..._strikeAngles[_leftAnkle]!,
      ..._strikeAngles[_rightAnkle]!,
    ];
    return _mean(all);
  }

  // -------------------------------------------------------------------------
  // Stride variability — coefficient of variation
  // -------------------------------------------------------------------------

  /// Coefficient of variation (CV) of step intervals for [nodeId].
  ///
  /// CV = (std_dev / mean) * 100
  ///
  /// Requires at least 3 intervals for a meaningful result.
  /// Reference: Jordan et al. (2007) — healthy runners show 3–5% CV.
  double _computeVariability(String nodeId) {
    final List<double> vals =
        _stepIntervals[nodeId]!.map((i) => i.toDouble()).toList();
    if (vals.length < 3) return 0.0;

    final double mean = _mean(vals);
    if (mean == 0) return 0.0;

    final double variance =
        vals.map((v) => pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) /
            vals.length;

    return (sqrt(variance) / mean) * 100.0;
  }

  // -------------------------------------------------------------------------
  // Utility
  // -------------------------------------------------------------------------

  /// Arithmetic mean of a list. Returns 0 for empty lists.
  double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Keep only the last [_windowSteps] entries in [buffer].
  void _trim(List<dynamic> buffer) {
    while (buffer.length > _windowSteps) {
      buffer.removeAt(0);
    }
  }
}
