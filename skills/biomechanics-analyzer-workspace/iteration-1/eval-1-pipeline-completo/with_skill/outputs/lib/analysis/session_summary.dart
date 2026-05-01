// lib/analysis/session_summary.dart
//
// Post-session consolidation: aggregates all RunningMetrics snapshots collected
// during a session into a single SessionSummary with dimension scores and an
// overall assessment.
//
// Scoring methodology (from running_biomechanics.md):
//   Weighted average: cadence 30%, symmetry 30%, contact time 20%, strike 20%.
//   Each dimension uses stepped thresholds instead of linear interpolation to
//   match how coaches actually classify running quality.
//
// Usage pattern:
//   - Call addMetrics() every time RunningMetricsEngine emits new RunningMetrics.
//   - Call addRecommendation() every time RecommendationEngine emits a message.
//   - Call build() once when the user ends the session.

import 'dart:math' as math;
import 'running_metrics_engine.dart';

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

/// Immutable summary produced at the end of a running session.
class SessionSummary {
  /// Total elapsed session time.
  final Duration totalDuration;

  /// Total steps counted during the session (both feet).
  final int totalSteps;

  /// Session-average cadence (steps/min).
  final double avgCadence;

  /// Highest cadence sustained over a 10-stride window during the session.
  final double peakCadence;

  /// Session-average left-foot contact share (%).
  final double avgSymmetry;

  /// Session-average ground-contact time (ms).
  final double avgContactTimeMs;

  /// Session-average strike angle (degrees). Positive → heel strike.
  final double avgStrikeAngleDeg;

  /// Deduplicated list of recommendation messages shown during the session.
  final List<String> recommendations;

  /// Human-readable overall assessment sentence.
  final String overallAssessment;

  /// Score (0–100) per dimension: 'cadence', 'symmetry', 'contact_time', 'strike'.
  final Map<String, double> scores;

  /// Weighted overall score (0–100).
  final double overallScore;

  const SessionSummary({
    required this.totalDuration,
    required this.totalSteps,
    required this.avgCadence,
    required this.peakCadence,
    required this.avgSymmetry,
    required this.avgContactTimeMs,
    required this.avgStrikeAngleDeg,
    required this.recommendations,
    required this.overallAssessment,
    required this.scores,
    required this.overallScore,
  });

  /// Empty summary returned when the session produced no metrics
  /// (e.g., the user stopped before the first 3 strides were accumulated).
  factory SessionSummary.empty() => const SessionSummary(
        totalDuration: Duration.zero,
        totalSteps: 0,
        avgCadence: 0,
        peakCadence: 0,
        avgSymmetry: 50,
        avgContactTimeMs: 0,
        avgStrikeAngleDeg: 0,
        recommendations: [],
        overallAssessment: 'Sesión demasiado corta para evaluar la técnica.',
        scores: {},
        overallScore: 0,
      );

  @override
  String toString() =>
      'SessionSummary('
      'dur=${totalDuration.inMinutes}m, '
      'steps=$totalSteps, '
      'cadence=${avgCadence.toStringAsFixed(0)} spm, '
      'sym=${avgSymmetry.toStringAsFixed(1)}%, '
      'score=${overallScore.toStringAsFixed(0)})';
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

/// Accumulates data during a session and produces a [SessionSummary] on demand.
///
/// Integrate with SessionProvider:
/// ```dart
/// // In onDataReceived, after metricsEngine emits metrics:
/// _summaryBuilder.addMetrics(metrics);
/// // After recommendationEngine emits a recommendation:
/// _summaryBuilder.addRecommendation(rec.message);
/// // In endSession():
/// sessionSummary = _summaryBuilder.build();
/// ```
class SessionSummaryBuilder {
  final List<RunningMetrics> _history = [];

  // Use a Set to store unique recommendation messages — no duplicates.
  final Set<String> _recommendationMessages = {};

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Register one [RunningMetrics] snapshot from [RunningMetricsEngine].
  void addMetrics(RunningMetrics m) => _history.add(m);

  /// Register a coaching message that was shown to the athlete.
  void addRecommendation(String message) =>
      _recommendationMessages.add(message);

  /// Build and return the final [SessionSummary]. Safe to call at any time;
  /// returns [SessionSummary.empty()] if no metrics were recorded.
  SessionSummary build() {
    if (_history.isEmpty) return SessionSummary.empty();

    final avgCadence = _avg(_history.map((m) => m.cadenceStepsPerMin));
    final avgSymmetry = _avg(_history.map((m) => m.symmetryPercent));
    final avgContact = _avg(_history.map((m) => m.avgContactTimeMs));
    final avgStrike = _avg(_history.map((m) => m.strikeAngleDeg));

    final peakCadence = _history
        .map((m) => m.cadenceStepsPerMin)
        .reduce(math.max);

    final totalSteps = _history.last.stepCount;
    final duration = _history.last.sessionDuration;

    // Dimension scores (0–100, stepped thresholds from running_biomechanics.md)
    final scores = {
      'cadence': _scoreCadence(avgCadence),
      'symmetry': _scoreSymmetry(avgSymmetry),
      'contact_time': _scoreContactTime(avgContact),
      'strike': _scoreStrike(avgStrike),
    };

    // Weighted overall score: cadence 30%, symmetry 30%, contact 20%, strike 20%
    final overallScore = scores['cadence']! * 0.30 +
        scores['symmetry']! * 0.30 +
        scores['contact_time']! * 0.20 +
        scores['strike']! * 0.20;

    return SessionSummary(
      totalDuration: duration,
      totalSteps: totalSteps,
      avgCadence: avgCadence,
      peakCadence: peakCadence,
      avgSymmetry: avgSymmetry,
      avgContactTimeMs: avgContact,
      avgStrikeAngleDeg: avgStrike,
      recommendations: _recommendationMessages.toList(),
      overallAssessment: _generateAssessment(overallScore, scores),
      scores: scores,
      overallScore: overallScore,
    );
  }

  /// Reset builder state (call before starting a new session).
  void reset() {
    _history.clear();
    _recommendationMessages.clear();
  }

  // -------------------------------------------------------------------------
  // Scoring functions (stepped thresholds, running_biomechanics.md §Scoring)
  // -------------------------------------------------------------------------

  /// Cadence score: 100 if 170–180 spm (optimal), penalized below.
  double _scoreCadence(double c) {
    if (c >= 170 && c <= 180) return 100.0;
    if (c >= 160) return 70.0;
    if (c >= 155) return 50.0;
    return 30.0;
  }

  /// Symmetry score: penalized exponentially for deviation from 50%.
  double _scoreSymmetry(double s) {
    final dev = (s - 50.0).abs();
    if (dev <= 2.0) return 100.0;
    if (dev <= 5.0) return 80.0;
    if (dev <= 10.0) return 60.0;
    return 30.0;
  }

  /// Contact-time score: lower is better (shorter contact = more efficient).
  double _scoreContactTime(double t) {
    if (t <= 220) return 100.0;
    if (t <= 260) return 75.0;
    if (t <= 300) return 50.0;
    return 25.0;
  }

  /// Strike-angle score: midfoot optimal, heel-strike penalized.
  double _scoreStrike(double a) {
    if (a.abs() <= 5.0) return 100.0;
    if (a <= 10.0) return 75.0;
    if (a <= 15.0) return 50.0;
    return 25.0;
  }

  // -------------------------------------------------------------------------
  // Assessment text generation
  // -------------------------------------------------------------------------

  String _generateAssessment(
      double score, Map<String, double> scores) {
    // Identify the weakest dimension for targeted advice
    final weakest =
        scores.entries.reduce((a, b) => a.value < b.value ? a : b);

    if (score >= 85) {
      return 'Técnica sobresaliente. Sigue así — estás en nivel élite.';
    } else if (score >= 70) {
      return 'Técnica sólida. Trabaja tu ${_metricLabel(weakest.key)} '
          'para pasar al siguiente nivel.';
    } else if (score >= 55) {
      return 'Buena base. Enfócate en ${_metricLabel(weakest.key)} '
          'como prioridad esta semana.';
    } else if (score >= 40) {
      return 'Fundamentos a reforzar. Empieza por mejorar '
          'tu ${_metricLabel(weakest.key)}.';
    } else {
      return 'Margen de mejora amplio. Considera una sesión con entrenador '
          'para revisar tu técnica.';
    }
  }

  String _metricLabel(String key) => const {
        'cadence': 'cadencia',
        'symmetry': 'simetría',
        'contact_time': 'tiempo de contacto',
        'strike': 'técnica de pisada',
      }[key] ??
      key;

  // -------------------------------------------------------------------------
  // Math helpers
  // -------------------------------------------------------------------------

  double _avg(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0.0;
    return list.reduce((a, b) => a + b) / list.length;
  }
}
