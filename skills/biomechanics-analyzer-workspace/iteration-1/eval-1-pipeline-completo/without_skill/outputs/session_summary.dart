import 'running_metrics_engine.dart';
import 'recommendation_engine.dart';

// ── Scoring helpers ────────────────────────────────────────────────────────────

/// Dimension scores (0–100) for a completed running session.
class DimensionScores {
  /// Score based on average cadence vs. optimal range (170–180 spm).
  final int cadence;

  /// Score based on L/R symmetry deviation from 50%.
  final int symmetry;

  /// Score based on average ground contact time.
  final int contactTime;

  /// Score based on average foot-strike angle.
  final int strikeAngle;

  /// Weighted overall score:
  ///   cadence 30% + symmetry 30% + contactTime 20% + strikeAngle 20%
  final int overall;

  const DimensionScores({
    required this.cadence,
    required this.symmetry,
    required this.contactTime,
    required this.strikeAngle,
    required this.overall,
  });
}

// ── Athlete level ──────────────────────────────────────────────────────────────

/// Performance tier derived from the overall session score.
enum AthleteLevel {
  elite,
  advanced,
  intermediate,
  beginner,
  developing,
}

extension AthleteLevelLabel on AthleteLevel {
  String get label {
    switch (this) {
      case AthleteLevel.elite:
        return 'Élite';
      case AthleteLevel.advanced:
        return 'Avanzado';
      case AthleteLevel.intermediate:
        return 'Intermedio';
      case AthleteLevel.beginner:
        return 'Principiante';
      case AthleteLevel.developing:
        return 'En desarrollo';
    }
  }

  String get description {
    switch (this) {
      case AthleteLevel.elite:
        return 'Técnica sobresaliente. Mantén la consistencia.';
      case AthleteLevel.advanced:
        return 'Técnica sólida con pequeños detalles a pulir.';
      case AthleteLevel.intermediate:
        return 'Buena base. Trabajo focalizado recomendado.';
      case AthleteLevel.beginner:
        return 'Trabaja los fundamentos de técnica de carrera.';
      case AthleteLevel.developing:
        return 'Sesión de análisis con entrenador recomendada.';
    }
  }
}

// ── Session summary ────────────────────────────────────────────────────────────

/// Complete post-session biomechanical report.
class SessionSummary {
  /// Total number of strides recorded during the session.
  final int totalStrides;

  /// Session duration in milliseconds (last stride ts − first stride ts).
  final int durationMs;

  // ── Averages ──────────────────────────────────────────────────────────────

  final double avgCadenceSpm;
  final double avgSymmetryPct;
  final double avgContactTimeMs;
  final double avgStrikeAngleDeg;
  final double avgStrideVariabilityCv;

  // ── Scoring ───────────────────────────────────────────────────────────────

  final DimensionScores scores;
  final AthleteLevel level;

  /// All unique coaching recommendations that were raised during the session.
  final List<Recommendation> sessionRecommendations;

  const SessionSummary({
    required this.totalStrides,
    required this.durationMs,
    required this.avgCadenceSpm,
    required this.avgSymmetryPct,
    required this.avgContactTimeMs,
    required this.avgStrikeAngleDeg,
    required this.avgStrideVariabilityCv,
    required this.scores,
    required this.level,
    required this.sessionRecommendations,
  });

  String get durationFormatted {
    final totalSec = durationMs ~/ 1000;
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

// ── Builder ────────────────────────────────────────────────────────────────────

/// Accumulates [RunningMetrics] snapshots throughout a session and builds a
/// final [SessionSummary] on demand.
///
/// ## Integration with SessionProvider
/// ```dart
/// // In SessionProvider:
/// final _summaryBuilder = SessionSummaryBuilder();
///
/// // Call from RunningMetricsEngine callback:
/// void updateMetrics(RunningMetrics metrics) {
///   _summaryBuilder.recordSnapshot(metrics);
///   _currentMetrics = metrics;
///   notifyListeners();
/// }
///
/// // When recommendation is emitted:
/// void setRecommendation(Recommendation? rec) {
///   if (rec != null) _summaryBuilder.recordRecommendation(rec);
///   _recommendation = rec?.message;
///   notifyListeners();
/// }
///
/// // On session end:
/// SessionSummary? get summary => _summaryBuilder.build();
/// ```
class SessionSummaryBuilder {
  final List<RunningMetrics> _snapshots = [];

  // De-duplicated recommendations ordered by first appearance.
  final Map<String, Recommendation> _recommendationsSeen = {};

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Record a new metrics snapshot (called every time [RunningMetricsEngine] emits).
  void recordSnapshot(RunningMetrics metrics) {
    _snapshots.add(metrics);
  }

  /// Record a recommendation that was surfaced during the session.
  /// Duplicates (same key) are silently ignored.
  void recordRecommendation(Recommendation rec) {
    _recommendationsSeen.putIfAbsent(rec.key, () => rec);
  }

  /// Build the final [SessionSummary] from all accumulated data.
  ///
  /// Returns `null` if fewer than 5 snapshots were recorded (session too short
  /// to be meaningful).
  SessionSummary? build() {
    if (_snapshots.length < 5) return null;

    // ── Compute averages ────────────────────────────────────────────────────
    final n = _snapshots.length.toDouble();

    final avgCadence =
        _snapshots.map((s) => s.cadenceSpm).reduce((a, b) => a + b) / n;
    final avgSymmetry =
        _snapshots.map((s) => s.symmetryPct).reduce((a, b) => a + b) / n;
    final avgContact =
        _snapshots.map((s) => s.avgContactTimeMs).reduce((a, b) => a + b) / n;
    final avgStrike =
        _snapshots.map((s) => s.avgStrikeAngleDeg).reduce((a, b) => a + b) / n;
    final avgCv =
        _snapshots.map((s) => s.strideVariabilityCv).reduce((a, b) => a + b) / n;
    final totalStrides = _snapshots.last.strideCount; // cumulative

    final firstTs = _snapshots.first.lastTimestampMs;
    final lastTs = _snapshots.last.lastTimestampMs;
    final durationMs = lastTs - firstTs;

    // ── Compute dimension scores ────────────────────────────────────────────
    final cadenceScore = _scoreCadence(avgCadence);
    final symmetryScore = _scoreSymmetry(avgSymmetry);
    final contactScore = _scoreContact(avgContact);
    final strikeScore = _scoreStrike(avgStrike);

    final overall = (cadenceScore * 0.30 +
            symmetryScore * 0.30 +
            contactScore * 0.20 +
            strikeScore * 0.20)
        .round();

    final scores = DimensionScores(
      cadence: cadenceScore,
      symmetry: symmetryScore,
      contactTime: contactScore,
      strikeAngle: strikeScore,
      overall: overall,
    );

    final level = _levelFromScore(overall);

    return SessionSummary(
      totalStrides: totalStrides,
      durationMs: durationMs,
      avgCadenceSpm: avgCadence,
      avgSymmetryPct: avgSymmetry,
      avgContactTimeMs: avgContact,
      avgStrikeAngleDeg: avgStrike,
      avgStrideVariabilityCv: avgCv,
      scores: scores,
      level: level,
      sessionRecommendations: _recommendationsSeen.values.toList(),
    );
  }

  /// Reset the builder for a new session.
  void reset() {
    _snapshots.clear();
    _recommendationsSeen.clear();
  }

  // ── Scoring functions ───────────────────────────────────────────────────────

  /// Cadence score (0–100).
  /// Optimal: 170–180 spm → 100. < 155 spm → 30.
  int _scoreCadence(double spm) {
    if (spm >= 170 && spm <= 180) return 100;
    if (spm >= 180) return 90; // fast but valid for elite runners
    if (spm >= 160) return 70;
    if (spm >= 155) return 50;
    if (spm >= 150) return 40;
    return 30;
  }

  /// Symmetry score (0–100).
  /// Perfect 50% → 100. > 10 points off → 30.
  int _scoreSymmetry(double pct) {
    final deviation = (pct - 50.0).abs();
    if (deviation <= 2) return 100;
    if (deviation <= 5) return 80;
    if (deviation <= 10) return 60;
    return 30;
  }

  /// Contact time score (0–100).
  /// ≤ 220 ms → 100. > 300 ms → 25.
  int _scoreContact(double ms) {
    if (ms <= 220) return 100;
    if (ms <= 260) return 75;
    if (ms <= 300) return 50;
    return 25;
  }

  /// Foot-strike angle score (0–100).
  /// ≤ 5° → 100. > 15° → 25.
  int _scoreStrike(double deg) {
    final absDeg = deg.abs();
    // Both heel and extreme forefoot reduce score; midfoot (≤ 5°) is ideal.
    if (absDeg <= 5) return 100;
    if (absDeg <= 10) return 75;
    if (absDeg <= 15) return 50;
    return 25;
  }

  // ── Level mapping ───────────────────────────────────────────────────────────

  AthleteLevel _levelFromScore(int score) {
    if (score >= 85) return AthleteLevel.elite;
    if (score >= 70) return AthleteLevel.advanced;
    if (score >= 55) return AthleteLevel.intermediate;
    if (score >= 40) return AthleteLevel.beginner;
    return AthleteLevel.developing;
  }
}
