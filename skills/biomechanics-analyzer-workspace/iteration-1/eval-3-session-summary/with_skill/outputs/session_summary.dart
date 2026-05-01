// lib/analysis/session_summary.dart
//
// SessionSummaryBuilder — computes post-session statistics and scores.
// Scores follow the physiological thresholds from references/running_biomechanics.md.
// Weighted overall score: cadence 30%, symmetry 30%, contact time 20%, strike angle 20%.

import 'dart:math' as math;

// ---------------------------------------------------------------------------
// Data models expected from the upstream pipeline
// ---------------------------------------------------------------------------

/// Snapshot of running metrics for one sliding-window interval.
/// Produced by RunningMetricsEngine; fed here via [SessionSummaryBuilder.addMetrics].
class RunningMetrics {
  final double cadenceStepsPerMin;
  final double symmetryPercent;     // % load on left foot; 50 = perfectly symmetric
  final double avgContactTimeMs;
  final double strikeAngleDeg;      // positive = heel strike, negative = forefoot
  final double strideVariability;   // CV of cadence (%)
  final int stepCount;
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
}

// ---------------------------------------------------------------------------
// Athlete level — controls assessment text tone and score thresholds
// ---------------------------------------------------------------------------

enum AthleteLevel {
  developing,     // score < 40
  beginner,       // 40–54
  intermediate,   // 55–69
  advanced,       // 70–84
  elite,          // 85–100
}

// ---------------------------------------------------------------------------
// SessionSummary — immutable result object
// ---------------------------------------------------------------------------

class SessionSummary {
  /// Total active session time.
  final Duration totalDuration;

  /// Total step count for the session.
  final int totalSteps;

  // --- Average metrics ---
  final double avgCadence;         // steps per minute
  final double peakCadence;        // highest cadence window seen
  final double avgSymmetry;        // % load left foot
  final double avgContactTimeMs;   // ms
  final double avgStrikeAngleDeg;  // degrees (positive = heel strike)
  final double avgVariability;     // stride variability CV %

  // --- Dimension scores (0–100, higher is better) ---
  /// Individual scores keyed by dimension name.
  final Map<String, double> dimensionScores;

  /// Weighted overall score (0–100).
  final double overallScore;

  /// Athlete level derived from [overallScore].
  final AthleteLevel athleteLevel;

  /// Unique recommendation messages collected during the session.
  final List<String> recommendations;

  /// Human-readable assessment paragraph tailored to [athleteLevel].
  final String overallAssessment;

  const SessionSummary({
    required this.totalDuration,
    required this.totalSteps,
    required this.avgCadence,
    required this.peakCadence,
    required this.avgSymmetry,
    required this.avgContactTimeMs,
    required this.avgStrikeAngleDeg,
    required this.avgVariability,
    required this.dimensionScores,
    required this.overallScore,
    required this.athleteLevel,
    required this.recommendations,
    required this.overallAssessment,
  });

  /// Returns a [SessionSummary] with zeroed-out values (session too short to evaluate).
  factory SessionSummary.empty() {
    return const SessionSummary(
      totalDuration: Duration.zero,
      totalSteps: 0,
      avgCadence: 0,
      peakCadence: 0,
      avgSymmetry: 50,
      avgContactTimeMs: 0,
      avgStrikeAngleDeg: 0,
      avgVariability: 0,
      dimensionScores: {
        'cadence': 0,
        'symmetry': 0,
        'contact_time': 0,
        'strike': 0,
      },
      overallScore: 0,
      athleteLevel: AthleteLevel.developing,
      recommendations: [],
      overallAssessment: 'La sesión fue demasiado corta para generar un análisis completo.',
    );
  }
}

// ---------------------------------------------------------------------------
// SessionSummaryBuilder — accumulates metrics, builds the final summary
// ---------------------------------------------------------------------------

class SessionSummaryBuilder {
  final List<RunningMetrics> _history = [];
  final Set<String> _recommendationMessages = {};

  // Dimension score weights — must sum to 1.0
  static const _weightCadence    = 0.30;
  static const _weightSymmetry   = 0.30;
  static const _weightContact    = 0.20;
  static const _weightStrike     = 0.20;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Call once per sliding-window update from [RunningMetricsEngine].
  void addMetrics(RunningMetrics m) => _history.add(m);

  /// Call whenever [RecommendationEngine] emits a recommendation.
  /// Duplicates are suppressed automatically.
  void addRecommendation(String message) => _recommendationMessages.add(message);

  /// Build the immutable [SessionSummary]. Safe to call multiple times.
  SessionSummary build() {
    if (_history.isEmpty) return SessionSummary.empty();

    // --- Aggregate raw metrics ---
    final avgCadence   = _avg(_history.map((m) => m.cadenceStepsPerMin));
    final avgSymmetry  = _avg(_history.map((m) => m.symmetryPercent));
    final avgContact   = _avg(_history.map((m) => m.avgContactTimeMs));
    final avgStrike    = _avg(_history.map((m) => m.strikeAngleDeg));
    final avgVariability = _avg(_history.map((m) => m.strideVariability));
    final peakCadence  = _history
        .map((m) => m.cadenceStepsPerMin)
        .reduce(math.max);
    final totalSteps   = _history.last.stepCount;
    final duration     = _history.last.sessionDuration;

    // --- Score per dimension (0–100) ---
    final scores = <String, double>{
      'cadence':      _scoreCadence(avgCadence),
      'symmetry':     _scoreSymmetry(avgSymmetry),
      'contact_time': _scoreContactTime(avgContact),
      'strike':       _scoreStrikeAngle(avgStrike),
    };

    // --- Weighted overall score ---
    final overall =
        scores['cadence']!      * _weightCadence  +
        scores['symmetry']!     * _weightSymmetry +
        scores['contact_time']! * _weightContact  +
        scores['strike']!       * _weightStrike;

    final level = _levelFromScore(overall);

    return SessionSummary(
      totalDuration:     duration,
      totalSteps:        totalSteps,
      avgCadence:        avgCadence,
      peakCadence:       peakCadence,
      avgSymmetry:       avgSymmetry,
      avgContactTimeMs:  avgContact,
      avgStrikeAngleDeg: avgStrike,
      avgVariability:    avgVariability,
      dimensionScores:   scores,
      overallScore:      overall,
      athleteLevel:      level,
      recommendations:   _recommendationMessages.toList(),
      overallAssessment: _generateAssessment(overall, scores, level),
    );
  }

  // ---------------------------------------------------------------------------
  // Scoring functions — thresholds from references/running_biomechanics.md
  // ---------------------------------------------------------------------------

  /// Cadence score.
  /// 170–180 spm → 100 | 160–169 → 70 | 155–159 → 50 | < 155 → 30
  double _scoreCadence(double c) {
    if (c >= 170 && c <= 180) return 100;
    if (c > 180)              return 85;   // above optimal — elite pace, still excellent
    if (c >= 160)             return 70;
    if (c >= 155)             return 50;
    return 30;
  }

  /// Symmetry score based on deviation from perfect 50 %.
  /// |dev| ≤ 2 → 100 | ≤ 5 → 80 | ≤ 10 → 60 | > 10 → 30
  double _scoreSymmetry(double s) {
    final dev = (s - 50).abs();
    if (dev <= 2)  return 100;
    if (dev <= 5)  return 80;
    if (dev <= 10) return 60;
    return 30;
  }

  /// Contact-time score.
  /// ≤ 220 ms → 100 | 220–260 → 75 | 260–300 → 50 | > 300 → 25
  double _scoreContactTime(double t) {
    if (t <= 220) return 100;
    if (t <= 260) return 75;
    if (t <= 300) return 50;
    return 25;
  }

  /// Strike-angle score (positive = heel strike).
  /// ≤ 5° → 100 | 5–10° → 75 | 10–15° → 50 | > 15° → 25
  double _scoreStrikeAngle(double a) {
    final abs = a.abs();
    if (abs <= 5)  return 100;
    if (abs <= 10) return 75;
    if (abs <= 15) return 50;
    return 25;
  }

  // ---------------------------------------------------------------------------
  // Level and assessment text
  // ---------------------------------------------------------------------------

  AthleteLevel _levelFromScore(double score) {
    if (score >= 85) return AthleteLevel.elite;
    if (score >= 70) return AthleteLevel.advanced;
    if (score >= 55) return AthleteLevel.intermediate;
    if (score >= 40) return AthleteLevel.beginner;
    return AthleteLevel.developing;
  }

  /// Generates a tailored assessment paragraph.
  /// Tone scales with athlete level so feedback feels appropriate.
  String _generateAssessment(
    double score,
    Map<String, double> scores,
    AthleteLevel level,
  ) {
    // Find weakest and strongest dimensions for targeted feedback
    final sorted = scores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final weakest   = sorted.first;
    final strongest = sorted.last;

    final weakName   = _metricDisplayName(weakest.key);
    final strongName = _metricDisplayName(strongest.key);

    switch (level) {
      case AthleteLevel.elite:
        return 'Sesión sobresaliente (${score.toStringAsFixed(0)}/100). '
            'Tu técnica de carrera está muy bien calibrada. '
            'El punto más fuerte fue tu $strongName. '
            'Para seguir progresando, sigue refinando $weakName en sesiones de calidad.';

      case AthleteLevel.advanced:
        return 'Técnica sólida (${score.toStringAsFixed(0)}/100). '
            'Tu $strongName destaca positivamente. '
            'El trabajo más rentable ahora mismo es mejorar tu $weakName, '
            'que es el único factor que separa tu nivel del élite.';

      case AthleteLevel.intermediate:
        return 'Buena base técnica (${score.toStringAsFixed(0)}/100). '
            'Has demostrado consistencia en $strongName. '
            'Enfoca los próximos entrenamientos en $weakName — '
            'una mejora aquí tendrá el mayor impacto en tu rendimiento y en la prevención de lesiones.';

      case AthleteLevel.beginner:
        return 'Sesión con recorrido de mejora (${score.toStringAsFixed(0)}/100). '
            'Es normal en esta etapa. '
            'La prioridad número uno es trabajar tu $weakName mediante drills específicos. '
            'No intentes corregir todo a la vez — un cambio por sesión es suficiente.';

      case AthleteLevel.developing:
        return 'Sesión de análisis completada (${score.toStringAsFixed(0)}/100). '
            'Los datos muestran que aún hay fundamentos técnicos importantes a desarrollar. '
            'Se recomienda trabajar con un entrenador para establecer una base correcta de $weakName '
            'antes de aumentar la carga de entrenamiento.';
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _metricDisplayName(String key) {
    const names = {
      'cadence':      'cadencia',
      'symmetry':     'simetría',
      'contact_time': 'tiempo de contacto',
      'strike':       'técnica de pisada',
    };
    return names[key] ?? key;
  }

  double _avg(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }
}
