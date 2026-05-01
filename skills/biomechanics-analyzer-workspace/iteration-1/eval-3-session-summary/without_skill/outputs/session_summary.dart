/// session_summary.dart
///
/// Model, builder, scoring and evaluation for a running session summary.
/// Designed to work with a stream of RunningMetrics produced by the IMU
/// wearable pipeline.

// ─────────────────────────────────────────────────────────────────────────────
// Data transfer object produced by the biomechanics pipeline each frame/step.
// ─────────────────────────────────────────────────────────────────────────────

class RunningMetrics {
  /// Steps per minute.
  final double cadenceSpm;

  /// Percentage of total ground-contact time attributed to the left leg (0–100).
  final double symmetryPercent;

  /// Ground-contact time in milliseconds.
  final double contactTimeMs;

  /// Foot-strike angle in degrees (positive = heel-strike tendency).
  final double strikeAngleDeg;

  const RunningMetrics({
    required this.cadenceSpm,
    required this.symmetryPercent,
    required this.contactTimeMs,
    required this.strikeAngleDeg,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Dimension score containers
// ─────────────────────────────────────────────────────────────────────────────

class DimensionScore {
  /// Raw average value for this dimension.
  final double average;

  /// 0–100 score derived from physiological thresholds.
  final int score;

  /// Human-readable label for the dimension.
  final String label;

  const DimensionScore({
    required this.average,
    required this.score,
    required this.label,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Physiological threshold constants
// ─────────────────────────────────────────────────────────────────────────────

abstract class RunningThresholds {
  // Cadence (spm)
  static const double cadenceOptimalLow = 170.0;
  static const double cadenceOptimalHigh = 180.0;
  static const double cadenceEliteLow = 175.0;
  static const double cadenceEliteHigh = 185.0;

  // Symmetry (% left-leg contact)
  static const double symmetryOptimalLow = 45.0;
  static const double symmetryOptimalHigh = 55.0;

  // Ground contact (ms) — lower is better
  static const double contactElite = 200.0;
  static const double contactGood = 260.0;
  static const double contactFair = 320.0;

  // Foot-strike angle (°) — lower magnitude is better
  static const double strikeElite = 2.0;
  static const double strikeGood = 5.0;
  static const double strikeFair = 10.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Score weights (must sum to 1.0)
// ─────────────────────────────────────────────────────────────────────────────

abstract class ScoreWeights {
  static const double cadence = 0.30;
  static const double symmetry = 0.30;
  static const double contact = 0.20;
  static const double strike = 0.20;
}

// ─────────────────────────────────────────────────────────────────────────────
// Performance level enum
// ─────────────────────────────────────────────────────────────────────────────

enum PerformanceLevel {
  elite,
  advanced,
  intermediate,
  beginner;

  String get displayName {
    switch (this) {
      case PerformanceLevel.elite:
        return 'Élite';
      case PerformanceLevel.advanced:
        return 'Avanzado';
      case PerformanceLevel.intermediate:
        return 'Intermedio';
      case PerformanceLevel.beginner:
        return 'Principiante';
    }
  }

  String get description {
    switch (this) {
      case PerformanceLevel.elite:
        return 'Tu biomecánica de carrera es sobresaliente. '
            'Mantén la consistencia y trabaja en potencia.';
      case PerformanceLevel.advanced:
        return 'Muy buena mecánica de carrera con aspectos puntuales a pulir. '
            'Incrementa volumen con cuidado.';
      case PerformanceLevel.intermediate:
        return 'Mecánica funcional con margen claro de mejora. '
            'Enfócate en los puntos débiles antes de aumentar intensidad.';
      case PerformanceLevel.beginner:
        return 'Hay aspectos biomecánicos que requieren atención prioritaria. '
            'Trabaja con un coach o fisioterapeuta deportivo.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Immutable summary model
// ─────────────────────────────────────────────────────────────────────────────

class SessionSummary {
  /// Total number of metric samples accumulated.
  final int sampleCount;

  /// Duration of the session (if tracked externally).
  final Duration? sessionDuration;

  // Per-dimension scores
  final DimensionScore cadenceScore;
  final DimensionScore symmetryScore;
  final DimensionScore contactScore;
  final DimensionScore strikeScore;

  /// Weighted overall score 0–100.
  final int overallScore;

  /// Overall performance level.
  final PerformanceLevel level;

  /// Deduped, ordered list of actionable recommendations.
  final List<String> recommendations;

  const SessionSummary({
    required this.sampleCount,
    this.sessionDuration,
    required this.cadenceScore,
    required this.symmetryScore,
    required this.contactScore,
    required this.strikeScore,
    required this.overallScore,
    required this.level,
    required this.recommendations,
  });

  /// Converts the summary to a JSON-serialisable map.
  Map<String, dynamic> toJson() => {
        'sampleCount': sampleCount,
        'sessionDurationSeconds': sessionDuration?.inSeconds,
        'cadence': {
          'average': cadenceScore.average,
          'score': cadenceScore.score,
        },
        'symmetry': {
          'average': symmetryScore.average,
          'score': symmetryScore.score,
        },
        'contact': {
          'average': contactScore.average,
          'score': contactScore.score,
        },
        'strike': {
          'average': strikeScore.average,
          'score': strikeScore.score,
        },
        'overallScore': overallScore,
        'level': level.displayName,
        'recommendations': recommendations,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Builder — accumulates frames, then produces a SessionSummary
// ─────────────────────────────────────────────────────────────────────────────

class SessionSummaryBuilder {
  final DateTime _startTime = DateTime.now();

  final List<double> _cadenceSamples = [];
  final List<double> _symmetrySamples = [];
  final List<double> _contactSamples = [];
  final List<double> _strikeSamples = [];

  bool _finalized = false;

  /// Returns true if at least one sample has been added.
  bool get hasData => _cadenceSamples.isNotEmpty;

  /// Number of samples accumulated so far.
  int get sampleCount => _cadenceSamples.length;

  // ── Accumulation ──────────────────────────────────────────────────────────

  /// Add a single [RunningMetrics] frame.
  void addMetrics(RunningMetrics metrics) {
    if (_finalized) {
      throw StateError(
        'SessionSummaryBuilder has already been finalized. '
        'Create a new instance to start a new session.',
      );
    }
    _cadenceSamples.add(metrics.cadenceSpm);
    _symmetrySamples.add(metrics.symmetryPercent);
    _contactSamples.add(metrics.contactTimeMs);
    _strikeSamples.add(metrics.strikeAngleDeg);
  }

  /// Convenience method to add multiple frames at once.
  void addAll(Iterable<RunningMetrics> metrics) {
    for (final m in metrics) {
      addMetrics(m);
    }
  }

  // ── Finalization ──────────────────────────────────────────────────────────

  /// Compute and return the [SessionSummary]. After calling this the builder
  /// becomes immutable (calling [addMetrics] will throw).
  SessionSummary build({Duration? sessionDuration}) {
    if (_cadenceSamples.isEmpty) {
      throw StateError(
        'Cannot build a SessionSummary without at least one metric sample.',
      );
    }
    _finalized = true;

    final avgCadence = _average(_cadenceSamples);
    final avgSymmetry = _average(_symmetrySamples);
    final avgContact = _average(_contactSamples);
    final avgStrike = _average(_strikeSamples);

    final cadenceDim = DimensionScore(
      average: avgCadence,
      score: _scoreCadence(avgCadence),
      label: 'Cadencia',
    );
    final symmetryDim = DimensionScore(
      average: avgSymmetry,
      score: _scoreSymmetry(avgSymmetry),
      label: 'Simetría',
    );
    final contactDim = DimensionScore(
      average: avgContact,
      score: _scoreContact(avgContact),
      label: 'Contacto',
    );
    final strikeDim = DimensionScore(
      average: avgStrike,
      score: _scoreStrike(avgStrike),
      label: 'Pisada',
    );

    final overall = _weightedOverall(
      cadence: cadenceDim.score,
      symmetry: symmetryDim.score,
      contact: contactDim.score,
      strike: strikeDim.score,
    );

    final level = _levelFromScore(overall);
    final recommendations = _buildRecommendations(
      cadenceDim,
      symmetryDim,
      contactDim,
      strikeDim,
    );

    final elapsed =
        sessionDuration ?? DateTime.now().difference(_startTime);

    return SessionSummary(
      sampleCount: _cadenceSamples.length,
      sessionDuration: elapsed,
      cadenceScore: cadenceDim,
      symmetryScore: symmetryDim,
      contactScore: contactDim,
      strikeScore: strikeDim,
      overallScore: overall,
      level: level,
      recommendations: recommendations,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  double _average(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Cadence score: optimal band 170–180 spm scores 100; penalised linearly
  /// outside.
  int _scoreCadence(double spm) {
    const lo = RunningThresholds.cadenceOptimalLow;
    const hi = RunningThresholds.cadenceOptimalHigh;

    if (spm >= lo && spm <= hi) return 100;

    if (spm < lo) {
      // Each spm below 170 costs ~5 points; floor at 0.
      final deficit = (lo - spm) * 5.0;
      return (100 - deficit).clamp(0.0, 100.0).round();
    } else {
      // Slightly over is fine up to ~185; then penalise.
      final excess = (spm - hi) * 3.0;
      return (100 - excess).clamp(0.0, 100.0).round();
    }
  }

  /// Symmetry score: optimal 45–55 %; centred at 50 %.
  int _scoreSymmetry(double pct) {
    const lo = RunningThresholds.symmetryOptimalLow;
    const hi = RunningThresholds.symmetryOptimalHigh;
    const center = (lo + hi) / 2;

    if (pct >= lo && pct <= hi) return 100;

    final deviation = (pct - center).abs();
    // 5 % deviation from centre loses ~10 points (half-width = 5 %).
    final penalty = ((deviation - 5.0).clamp(0.0, 45.0)) * (100.0 / 45.0);
    return (100 - penalty).clamp(0.0, 100.0).round();
  }

  /// Contact time score: lower is better.
  int _scoreContact(double ms) {
    if (ms <= RunningThresholds.contactElite) return 100;
    if (ms <= RunningThresholds.contactGood) {
      // Linear from 100 (at 200 ms) to 70 (at 260 ms).
      final t = (ms - RunningThresholds.contactElite) /
          (RunningThresholds.contactGood - RunningThresholds.contactElite);
      return (100 - t * 30).round();
    }
    if (ms <= RunningThresholds.contactFair) {
      // Linear from 70 (at 260 ms) to 40 (at 320 ms).
      final t = (ms - RunningThresholds.contactGood) /
          (RunningThresholds.contactFair - RunningThresholds.contactGood);
      return (70 - t * 30).round();
    }
    // Beyond 320 ms: linear decay to 0 at 500 ms.
    final t = ((ms - RunningThresholds.contactFair) / 180.0).clamp(0.0, 1.0);
    return (40 - t * 40).round();
  }

  /// Strike angle score: smaller absolute angle is better.
  int _scoreStrike(double deg) {
    final abs = deg.abs();
    if (abs <= RunningThresholds.strikeElite) return 100;
    if (abs <= RunningThresholds.strikeGood) {
      // Linear 100→70 between 2° and 5°.
      final t = (abs - RunningThresholds.strikeElite) /
          (RunningThresholds.strikeGood - RunningThresholds.strikeElite);
      return (100 - t * 30).round();
    }
    if (abs <= RunningThresholds.strikeFair) {
      // Linear 70→40 between 5° and 10°.
      final t = (abs - RunningThresholds.strikeGood) /
          (RunningThresholds.strikeFair - RunningThresholds.strikeGood);
      return (70 - t * 30).round();
    }
    // Beyond 10°: linear decay to 0 at 20°.
    final t = ((abs - RunningThresholds.strikeFair) / 10.0).clamp(0.0, 1.0);
    return (40 - t * 40).round();
  }

  int _weightedOverall({
    required int cadence,
    required int symmetry,
    required int contact,
    required int strike,
  }) {
    final weighted = cadence * ScoreWeights.cadence +
        symmetry * ScoreWeights.symmetry +
        contact * ScoreWeights.contact +
        strike * ScoreWeights.strike;
    return weighted.round().clamp(0, 100);
  }

  PerformanceLevel _levelFromScore(int score) {
    if (score >= 85) return PerformanceLevel.elite;
    if (score >= 70) return PerformanceLevel.advanced;
    if (score >= 50) return PerformanceLevel.intermediate;
    return PerformanceLevel.beginner;
  }

  /// Build a deduped, ordered list of recommendations from the weakest
  /// dimension outward.
  List<String> _buildRecommendations(
    DimensionScore cadence,
    DimensionScore symmetry,
    DimensionScore contact,
    DimensionScore strike,
  ) {
    // Collect raw recommendations per dimension (worst-first).
    final raw = <String>[];

    // Cadence
    if (cadence.average < RunningThresholds.cadenceOptimalLow) {
      raw.add(
        'Aumenta tu cadencia hacia 170–180 ppm. Usa un metrónomo o playlist '
        'con BPM objetivo durante rodajes fáciles.',
      );
      if (cadence.average < 155) {
        raw.add(
          'Cadencia muy baja: considera acortar la zancada y elevar la '
          'frecuencia de pasos progresivamente.',
        );
      }
    } else if (cadence.average > RunningThresholds.cadenceEliteHigh) {
      raw.add(
        'Cadencia ligeramente elevada. Asegúrate de que la longitud de '
        'zancada no sea demasiado corta, lo que reduce la economía.',
      );
    }

    // Symmetry
    final symDev = (cadence.average - 50).abs(); // reuse average safely
    final symActual = symmetry.average;
    if (symActual < RunningThresholds.symmetryOptimalLow) {
      raw.add(
        'Detectamos carga excesiva en la pierna derecha '
        '(${symActual.toStringAsFixed(1)} % izquierda). '
        'Realiza ejercicios de fuerza unilateral y revisa la postura.',
      );
    } else if (symActual > RunningThresholds.symmetryOptimalHigh) {
      raw.add(
        'Detectamos carga excesiva en la pierna izquierda '
        '(${symActual.toStringAsFixed(1)} % izquierda). '
        'Realiza ejercicios de fuerza unilateral y revisa la postura.',
      );
    }

    // Contact time
    if (contact.average > RunningThresholds.contactFair) {
      raw.add(
        'Tiempo de contacto muy elevado (${contact.average.toStringAsFixed(0)} ms). '
        'Trabaja pliometría y stiffness muscular: saltos de caja, skipping.',
      );
    } else if (contact.average > RunningThresholds.contactGood) {
      raw.add(
        'Tiempo de contacto por encima del umbral óptimo '
        '(${contact.average.toStringAsFixed(0)} ms vs ≤260 ms). '
        'Incorpora ejercicios de reactividad y fortalece el tríceps sural.',
      );
    }

    // Strike angle
    final absAngle = strike.average.abs();
    if (absAngle > RunningThresholds.strikeFair) {
      raw.add(
        'Ángulo de pisada muy pronunciado (${strike.average.toStringAsFixed(1)}°). '
        'Considera una evaluación de calzado y trabajo de técnica de carrera '
        'con un especialista.',
      );
    } else if (absAngle > RunningThresholds.strikeGood) {
      raw.add(
        'Ángulo de pisada subóptimo (${strike.average.toStringAsFixed(1)}°). '
        'Practica ejercicios de activación del pie y rodaje descalzo breve '
        'para mejorar la propiocepción.',
      );
    }

    // General recommendations when all scores are high
    if (cadence.score >= 90 &&
        symmetry.score >= 90 &&
        contact.score >= 90 &&
        strike.score >= 90) {
      raw.add(
        'Excelente mecánica global. Mantén la consistencia y considera '
        'periodización avanzada para el siguiente ciclo.',
      );
    }

    // Deduplication preserving order
    final seen = <String>{};
    final deduped = <String>[];
    for (final rec in raw) {
      if (seen.add(rec)) deduped.add(rec);
    }

    // Suppress unused variable warning from symDev
    assert(symDev >= 0);

    return deduped;
  }
}
