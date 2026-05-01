// lib/analysis/recommendation_engine.dart
//
// Evaluates RunningMetrics against evidence-based thresholds and produces
// one prioritized coaching recommendation at a time.
//
// Design principles (from running_biomechanics.md):
//   1. Only ONE recommendation at a time — athletes can't fix multiple things
//      while running.
//   2. 90-second cooldown per metric key — avoids repeating the same message
//      before the athlete has had time to act on it.
//   3. Messages are actionable, positive, and ≤ 15 words for readability
//      while running.
//   4. Priority order: HIGH (injury risk) → MEDIUM (efficiency) → LOW (optimization).

import 'running_metrics_engine.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// Urgency level of a recommendation.
enum RecommendationPriority { high, medium, low }

/// A single coaching recommendation produced by [RecommendationEngine].
class Recommendation {
  /// Urgency of this recommendation (determines display style in the UI).
  final RecommendationPriority priority;

  /// Human-readable coaching message. Should be shown on screen for ≥ 5 s.
  final String message;

  /// The metric that triggered this recommendation (used for cooldown logic).
  final String metricKey;

  /// Current value of the triggering metric (useful for logging / telemetry).
  final double metricValue;

  const Recommendation({
    required this.priority,
    required this.message,
    required this.metricKey,
    required this.metricValue,
  });

  @override
  String toString() =>
      'Recommendation(${priority.name.toUpperCase()}, key=$metricKey, '
      'val=${metricValue.toStringAsFixed(1)}, msg="$message")';
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

/// Stateless evaluation logic with stateful cooldown tracking.
///
/// Usage:
/// ```dart
/// final engine = RecommendationEngine();
/// final rec = engine.evaluate(metrics);
/// if (rec != null) {
///   currentRecommendation = rec;
///   summaryBuilder.addRecommendation(rec.message);
/// }
/// ```
class RecommendationEngine {
  // -------------------------------------------------------------------------
  // Thresholds — sourced from running_biomechanics.md
  // -------------------------------------------------------------------------

  // Cadence (steps/min)
  static const double _cadenceVeryLow = 150.0; // HIGH priority below this
  static const double _cadenceLow = 160.0;     // MEDIUM priority below this
  static const double _cadenceOpt = 170.0;     // optimal target

  // Symmetry (% left-foot contact time)
  static const double _symmetryLowSevere = 40.0;  // HIGH priority
  static const double _symmetryLow = 45.0;         // MEDIUM priority
  static const double _symmetryHigh = 55.0;        // MEDIUM priority
  static const double _symmetryHighSevere = 60.0;  // HIGH priority

  // Contact time (ms)
  static const double _contactTimeMedium = 300.0;  // MEDIUM priority
  static const double _contactTimeLow = 350.0;     // HIGH priority

  // Strike angle (degrees)
  static const double _strikeAngleMedium = 12.0;   // MEDIUM priority
  static const double _strikeAngleHigh = 15.0;     // HIGH priority (excessive heel)

  // Stride variability (CV %)
  static const double _variabilityLow = 5.0;       // LOW priority
  static const double _variabilityHigh = 10.0;     // HIGH priority

  // Cooldown: do not repeat the same metric recommendation within this window
  static const int _cooldownSeconds = 90;

  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------

  final Map<String, DateTime> _lastRecommendationTime = {};

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Evaluate current [metrics] and return the highest-priority actionable
  /// recommendation, or null if everything is within acceptable ranges or
  /// all triggered recommendations are still in cooldown.
  Recommendation? evaluate(RunningMetrics metrics) {
    final candidates = <Recommendation>[];

    // --- Symmetry (injury risk — highest priority when severe) ---
    final asymmetry = (metrics.symmetryPercent - 50.0).abs();
    if (metrics.symmetryPercent < _symmetryLowSevere ||
        metrics.symmetryPercent > _symmetryHighSevere) {
      final heavySide =
          metrics.symmetryPercent < 50.0 ? 'derecho' : 'izquierdo';
      candidates.add(Recommendation(
        priority: RecommendationPriority.high,
        metricKey: 'symmetry',
        metricValue: metrics.symmetryPercent,
        message:
            'Asimetría severa: pie $heavySide carga ${asymmetry.toStringAsFixed(0)}% más. '
            'Equilibra el esfuerzo.',
      ));
    } else if (metrics.symmetryPercent < _symmetryLow ||
        metrics.symmetryPercent > _symmetryHigh) {
      final heavySide =
          metrics.symmetryPercent < 50.0 ? 'derecho' : 'izquierdo';
      candidates.add(Recommendation(
        priority: RecommendationPriority.medium,
        metricKey: 'symmetry',
        metricValue: metrics.symmetryPercent,
        message:
            'Asimetría ${asymmetry.toStringAsFixed(0)}%. Relaja el pie $heavySide '
            'y equilibra el ritmo.',
      ));
    }

    // --- Cadence (very low → HIGH; low → MEDIUM) ---
    if (metrics.cadenceStepsPerMin < _cadenceVeryLow) {
      candidates.add(Recommendation(
        priority: RecommendationPriority.high,
        metricKey: 'cadence',
        metricValue: metrics.cadenceStepsPerMin,
        message:
            'Cadencia muy baja (${metrics.cadenceStepsPerMin.toStringAsFixed(0)} spm). '
            'Acorta la zancada urgentemente.',
      ));
    } else if (metrics.cadenceStepsPerMin < _cadenceLow) {
      candidates.add(Recommendation(
        priority: RecommendationPriority.medium,
        metricKey: 'cadence',
        metricValue: metrics.cadenceStepsPerMin,
        message:
            'Cadencia baja (${metrics.cadenceStepsPerMin.toStringAsFixed(0)} spm). '
            'Apunta a ${_cadenceOpt.toInt()} spm.',
      ));
    }

    // --- Strike angle (excessive heel strike) ---
    if (metrics.strikeAngleDeg > _strikeAngleHigh) {
      candidates.add(Recommendation(
        priority: RecommendationPriority.high,
        metricKey: 'strike_angle',
        metricValue: metrics.strikeAngleDeg,
        message:
            'Talón pronunciado (${metrics.strikeAngleDeg.toStringAsFixed(1)}°). '
            'Aterriza bajo tu cadera.',
      ));
    } else if (metrics.strikeAngleDeg > _strikeAngleMedium) {
      candidates.add(Recommendation(
        priority: RecommendationPriority.medium,
        metricKey: 'strike_angle',
        metricValue: metrics.strikeAngleDeg,
        message:
            'Aterrizas con el talón (${metrics.strikeAngleDeg.toStringAsFixed(1)}°). '
            'Intenta una pisada más plana.',
      ));
    }

    // --- Contact time ---
    if (metrics.avgContactTimeMs > _contactTimeLow) {
      candidates.add(Recommendation(
        priority: RecommendationPriority.medium,
        metricKey: 'contact_time',
        metricValue: metrics.avgContactTimeMs,
        message:
            'Contacto largo (${metrics.avgContactTimeMs.toStringAsFixed(0)} ms). '
            'Despegue más activo del pie.',
      ));
    } else if (metrics.avgContactTimeMs > _contactTimeMedium) {
      candidates.add(Recommendation(
        priority: RecommendationPriority.low,
        metricKey: 'contact_time',
        metricValue: metrics.avgContactTimeMs,
        message:
            'Contacto algo largo (${metrics.avgContactTimeMs.toStringAsFixed(0)} ms). '
            'Imagina el suelo caliente.',
      ));
    }

    // --- Stride variability (possible fatigue) ---
    if (metrics.strideVariability > _variabilityHigh) {
      candidates.add(Recommendation(
        priority: RecommendationPriority.high,
        metricKey: 'variability',
        metricValue: metrics.strideVariability,
        message:
            'Zancada muy irregular (${metrics.strideVariability.toStringAsFixed(1)}%). '
            'Considera bajar el ritmo.',
      ));
    } else if (metrics.strideVariability > _variabilityLow) {
      candidates.add(Recommendation(
        priority: RecommendationPriority.low,
        metricKey: 'variability',
        metricValue: metrics.strideVariability,
        message:
            'Zancada irregular (${metrics.strideVariability.toStringAsFixed(1)}%). '
            'Busca un ritmo más constante.',
      ));
    }

    if (candidates.isEmpty) return null;

    // Sort by priority (HIGH = 0 < MEDIUM = 1 < LOW = 2)
    candidates.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    // Return first candidate not in cooldown
    for (final candidate in candidates) {
      if (!_isCooldownActive(candidate.metricKey)) {
        _lastRecommendationTime[candidate.metricKey] = DateTime.now();
        return candidate;
      }
    }

    // All triggered recommendations are still in cooldown
    return null;
  }

  /// Reset cooldown timers (call when a new session starts).
  void reset() => _lastRecommendationTime.clear();

  // -------------------------------------------------------------------------
  // Cooldown helper
  // -------------------------------------------------------------------------

  bool _isCooldownActive(String metricKey) {
    final last = _lastRecommendationTime[metricKey];
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds < _cooldownSeconds;
  }
}
