import 'running_metrics_engine.dart';

// ── Domain types ───────────────────────────────────────────────────────────────

/// Urgency level of a coaching recommendation.
enum RecommendationPriority {
  /// Biomechanical risk factor requiring immediate attention.
  high,

  /// Sub-optimal pattern that should be corrected soon.
  medium,

  /// Minor optimisation opportunity.
  low,
}

/// A single coaching recommendation produced by [RecommendationEngine].
class Recommendation {
  /// Short identifier used for cooldown tracking (e.g. 'cadence_low').
  final String key;

  final RecommendationPriority priority;

  /// Human-readable coaching message (< 15 words, actionable, positive tone).
  final String message;

  const Recommendation({
    required this.key,
    required this.priority,
    required this.message,
  });

  @override
  String toString() =>
      'Recommendation{key=$key, priority=$priority, message="$message"}';
}

// ── Engine ─────────────────────────────────────────────────────────────────────

/// Evaluates [RunningMetrics] and surfaces the single most-urgent coaching
/// recommendation, respecting a 90-second per-key cooldown.
///
/// ## Integration
/// ```dart
/// final recEngine = RecommendationEngine(
///   onRecommendation: (rec) => sessionProvider.setRecommendation(rec?.message),
/// );
///
/// metricsEngine = RunningMetricsEngine(
///   onMetricsUpdated: (metrics) {
///     recEngine.evaluate(metrics);
///     sessionProvider.updateMetrics(metrics);
///   },
/// );
/// ```
class RecommendationEngine {
  /// Called when a recommendation is selected (or cleared when none applies).
  /// Passes `null` when all metrics are within healthy ranges.
  final void Function(Recommendation? recommendation)? onRecommendation;

  /// Cooldown duration between identical recommendation keys (seconds).
  final int cooldownSeconds;

  // ── Cooldown tracking ─────────────────────────────────────────────────────
  final Map<String, DateTime> _lastEmitted = {};

  RecommendationEngine({
    this.onRecommendation,
    this.cooldownSeconds = 90,
  });

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Evaluate the latest [RunningMetrics] and fire [onRecommendation] if a
  /// recommendation is available and not in cooldown.
  ///
  /// Only the highest-priority eligible recommendation is emitted. If none
  /// qualifies, `null` is passed to [onRecommendation].
  void evaluate(RunningMetrics metrics) {
    // Require at least a small window before making recommendations.
    if (metrics.strideCount < 3) return;

    final candidates = _buildCandidates(metrics);

    // Find the highest-priority candidate that is not in cooldown.
    Recommendation? chosen;
    for (final rec in candidates) {
      if (!_isCooldownActive(rec.key)) {
        chosen = rec;
        break; // Already sorted by priority; take the first eligible one.
      }
    }

    if (chosen != null) {
      _lastEmitted[chosen.key] = DateTime.now();
    }

    onRecommendation?.call(chosen);
  }

  /// Clear the cooldown map (e.g., when a new session starts).
  void reset() => _lastEmitted.clear();

  // ── Private helpers ─────────────────────────────────────────────────────────

  bool _isCooldownActive(String key) {
    final last = _lastEmitted[key];
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds < cooldownSeconds;
  }

  /// Build the full list of current recommendations sorted by priority
  /// (high → medium → low).
  List<Recommendation> _buildCandidates(RunningMetrics m) {
    final List<Recommendation> high = [];
    final List<Recommendation> medium = [];
    final List<Recommendation> low = [];

    // ── Cadence checks ──────────────────────────────────────────────────────
    final cadence = m.cadenceSpm;
    if (cadence > 0 && cadence < 150) {
      high.add(Recommendation(
        key: 'cadence_very_low',
        priority: RecommendationPriority.high,
        message:
            'Cadencia muy baja (${cadence.toStringAsFixed(0)} spm). '
            'Acorta la zancada — apunta a 160 spm.',
      ));
    } else if (cadence >= 150 && cadence < 160) {
      medium.add(Recommendation(
        key: 'cadence_low',
        priority: RecommendationPriority.medium,
        message:
            'Cadencia baja (${cadence.toStringAsFixed(0)} spm). '
            'Intenta pequeños pasos más rápidos.',
      ));
    }

    // ── Symmetry checks ─────────────────────────────────────────────────────
    final asymmetry = (m.symmetryPct - 50.0).abs();
    if (asymmetry > 10) {
      final heavier = m.symmetryPct > 50 ? 'izquierdo' : 'derecho';
      high.add(Recommendation(
        key: 'symmetry_severe',
        priority: RecommendationPriority.high,
        message:
            'Asimetría ${asymmetry.toStringAsFixed(0)}%. '
            'Relaja el pie $heavier y equilibra el esfuerzo.',
      ));
    } else if (asymmetry > 5) {
      final heavier = m.symmetryPct > 50 ? 'izquierdo' : 'derecho';
      medium.add(Recommendation(
        key: 'symmetry_moderate',
        priority: RecommendationPriority.medium,
        message:
            'Leve asimetría — más carga en pie $heavier. '
            'Intenta distribuir el esfuerzo.',
      ));
    }

    // ── Variability checks ──────────────────────────────────────────────────
    final cv = m.strideVariabilityCv;
    if (cv > 10) {
      high.add(Recommendation(
        key: 'variability_high',
        priority: RecommendationPriority.high,
        message:
            'Zancada muy irregular (CV ${cv.toStringAsFixed(1)}%). '
            'Mantén un ritmo constante.',
      ));
    } else if (cv > 7) {
      medium.add(Recommendation(
        key: 'variability_moderate',
        priority: RecommendationPriority.medium,
        message:
            'Ritmo algo irregular. Intenta pasos más uniformes.',
      ));
    }

    // ── Contact time checks ─────────────────────────────────────────────────
    final contact = m.avgContactTimeMs;
    if (contact > 400) {
      medium.add(Recommendation(
        key: 'contact_very_long',
        priority: RecommendationPriority.medium,
        message:
            'Contacto muy largo (${contact.toStringAsFixed(0)} ms). '
            'Empuja el suelo con más explosividad.',
      ));
    } else if (contact > 350) {
      low.add(Recommendation(
        key: 'contact_long',
        priority: RecommendationPriority.low,
        message:
            'Tiempo de contacto (${contact.toStringAsFixed(0)} ms) mejorable. '
            'Apunta a < 300 ms.',
      ));
    }

    // ── Strike angle checks ─────────────────────────────────────────────────
    final strike = m.avgStrikeAngleDeg;
    if (strike > 15) {
      medium.add(Recommendation(
        key: 'heel_strike_severe',
        priority: RecommendationPriority.medium,
        message:
            'Pisada de talón pronunciada (${strike.toStringAsFixed(1)}°). '
            'Aterriza con el mediopié.',
      ));
    } else if (strike > 12) {
      medium.add(Recommendation(
        key: 'heel_strike_moderate',
        priority: RecommendationPriority.medium,
        message:
            'Leve pisada de talón. Inclínate ligeramente hacia adelante.',
      ));
    } else if (strike < -5) {
      low.add(Recommendation(
        key: 'forefoot_extreme',
        priority: RecommendationPriority.low,
        message:
            'Pisada muy de punta. Cuida el tendón de Aquiles en fondo.',
      ));
    }

    return [...high, ...medium, ...low];
  }
}
