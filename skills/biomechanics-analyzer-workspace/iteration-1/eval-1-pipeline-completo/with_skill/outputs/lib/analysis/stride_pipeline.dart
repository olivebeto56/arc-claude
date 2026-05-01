// lib/analysis/stride_pipeline.dart
//
// Accumulates GaitEvents from both ankle nodes and computes per-stride metrics
// every time there is enough data from both feet.
//
// Key design decisions:
//   - One [StridePipeline] is shared between both detectors (unlike GaitEventDetector
//     which is per-foot). It needs both left and right events to compute symmetry.
//   - Cadence is averaged over the last 10 same-foot intervals to smooth natural
//     step-to-step variance (running_biomechanics.md recommendation).
//   - Contact-time values outside the physiological window [50 ms, 500 ms] are
//     clamped rather than rejected so the pipeline never stalls on a bad sample.

import 'gait_event_detector.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// Per-stride metrics emitted by [StridePipeline] after each complete
/// left+right step pair.
class StrideMetrics {
  /// Session-relative timestamp of the event that triggered this emission (ms).
  final int timestampMs;

  /// Cadence smoothed over the last 10 same-foot step intervals (steps/min).
  /// Computed as: 60,000 / avg_interval × 2  (×2 because interval is per foot).
  final double cadenceStepsPerMin;

  /// Ground-contact time for the left foot (ms), clamped to [50, 500].
  final double contactTimeLeftMs;

  /// Ground-contact time for the right foot (ms), clamped to [50, 500].
  final double contactTimeRightMs;

  /// Percentage of total contact time spent on the LEFT foot.
  /// 50 % = perfectly symmetric; < 50 % = more load on right foot.
  final double symmetryPercent;

  /// Ankle pitch at last left-foot impact (degrees). Positive → heel strike.
  final double strikeAngleLeftDeg;

  /// Ankle pitch at last right-foot impact (degrees). Positive → heel strike.
  final double strikeAngleRightDeg;

  /// Flight time (ms). Reserved for Sprint 4+ when both feet are tracked
  /// simultaneously with synchronized timestamps.
  final double flightTimeMs;

  const StrideMetrics({
    required this.timestampMs,
    required this.cadenceStepsPerMin,
    required this.contactTimeLeftMs,
    required this.contactTimeRightMs,
    required this.symmetryPercent,
    required this.strikeAngleLeftDeg,
    required this.strikeAngleRightDeg,
    this.flightTimeMs = 0.0,
  });

  @override
  String toString() =>
      'StrideMetrics(ts=${timestampMs}ms, '
      'cadence=${cadenceStepsPerMin.toStringAsFixed(0)} spm, '
      'sym=${symmetryPercent.toStringAsFixed(1)}%, '
      'ctL=${contactTimeLeftMs.toStringAsFixed(0)}ms, '
      'ctR=${contactTimeRightMs.toStringAsFixed(0)}ms)';
}

// ---------------------------------------------------------------------------
// Pipeline
// ---------------------------------------------------------------------------

/// Stateful accumulator that converts raw [GaitEvent]s into [StrideMetrics].
///
/// Create one shared instance; feed events from both feet:
/// ```dart
/// final stride = _stridePipeline.onEvent(event);
/// if (stride != null) _metricsEngine.addStride(stride);
/// ```
class StridePipeline {
  // Per-node last known timestamps
  final Map<String, int> _impactTimes = {};
  final Map<String, int> _takeoffTimes = {};

  // Strike angle at last impact, per node
  final Map<String, double> _strikeAngles = {};

  // Rolling buffer of the last 10 same-foot step intervals (ms).
  // Each entry records (nodeId, interval) so the average is across all steps
  // but indexed by arrival order — same-foot intervals interleave naturally.
  final List<int> _recentIntervals = [];

  // Maximum number of intervals kept for cadence smoothing.
  static const int _cadenceWindowSize = 10;

  // Physiological bounds for contact time (ms)
  static const double _contactTimeMin = 50.0;
  static const double _contactTimeMax = 500.0;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Process one [GaitEvent] and return [StrideMetrics] when there is
  /// sufficient bilateral data, or null otherwise.
  StrideMetrics? onEvent(GaitEvent event) {
    if (event.type == GaitEventType.impact) {
      _handleImpact(event);
    } else {
      _handleTakeoff(event);
    }

    // Emit metrics only when we have at least one impact AND one takeoff
    // for each foot — prevents partial computations on first few steps.
    return _canEmit() ? _computeMetrics(event.timestampMs) : null;
  }

  /// Reset all accumulated state (call when a new session starts).
  void reset() {
    _impactTimes.clear();
    _takeoffTimes.clear();
    _strikeAngles.clear();
    _recentIntervals.clear();
  }

  // ---------------------------------------------------------------------------
  // Internal handlers
  // ---------------------------------------------------------------------------

  void _handleImpact(GaitEvent event) {
    _strikeAngles[event.nodeId] = event.strikeAngleDeg;

    // Compute step interval from previous impact of the same foot
    if (_impactTimes.containsKey(event.nodeId)) {
      final interval = event.timestampMs - _impactTimes[event.nodeId]!;
      // Physiological guard: intervals outside [200 ms, 2000 ms] are artefacts
      if (interval >= 200 && interval <= 2000) {
        _recentIntervals.add(interval);
        if (_recentIntervals.length > _cadenceWindowSize) {
          _recentIntervals.removeAt(0);
        }
      }
    }
    _impactTimes[event.nodeId] = event.timestampMs;
  }

  void _handleTakeoff(GaitEvent event) {
    _takeoffTimes[event.nodeId] = event.timestampMs;
  }

  bool _canEmit() =>
      _impactTimes.length >= 2 && _takeoffTimes.length >= 2;

  StrideMetrics _computeMetrics(int timestampMs) {
    // Contact times: takeoff − impact, clamped to physiological range
    final contactLeft = _safeContact('LEFT_ANKLE');
    final contactRight = _safeContact('RIGHT_ANKLE');
    final totalContact = contactLeft + contactRight;

    // Cadence: average interval across both feet (interval is per-foot,
    // multiply by 2 to get steps/min for both feet combined)
    final avgInterval = _recentIntervals.isEmpty
        ? 500.0 // fallback: assume 120 spm until we have real data
        : _recentIntervals.reduce((a, b) => a + b) / _recentIntervals.length;
    final cadence = (60000.0 / avgInterval) * 2.0;

    // Symmetry: fraction of contact time on the left foot
    final symmetry =
        totalContact > 0 ? (contactLeft / totalContact) * 100.0 : 50.0;

    return StrideMetrics(
      timestampMs: timestampMs,
      cadenceStepsPerMin: cadence,
      contactTimeLeftMs: contactLeft,
      contactTimeRightMs: contactRight,
      symmetryPercent: symmetry,
      strikeAngleLeftDeg: _strikeAngles['LEFT_ANKLE'] ?? 0.0,
      strikeAngleRightDeg: _strikeAngles['RIGHT_ANKLE'] ?? 0.0,
    );
  }

  /// Compute contact time for [nodeId], returning 0 when data is missing
  /// and clamping to the physiological window to discard sensor artefacts.
  double _safeContact(String nodeId) {
    final impact = _impactTimes[nodeId];
    final takeoff = _takeoffTimes[nodeId];
    if (impact == null || takeoff == null) return 0.0;
    final raw = (takeoff - impact).toDouble();
    return raw.clamp(_contactTimeMin, _contactTimeMax);
  }
}
