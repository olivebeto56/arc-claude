// recommendation_engine.dart
//
// Motor de recomendaciones biomecánicas para running.
// Evalúa las métricas calculadas por MetricsCalculator y devuelve
// UNA sola recomendación a la vez (la más urgente), en español,
// específica y accionable.
//
// Umbrales normativos basados en:
//   - Heiderscheit et al. (2011) — cadencia
//   - Zifchock et al. (2006)     — simetría L/R
//   - Morin et al. (2011)        — tiempo de contacto
//   - Lieberman et al. (2010)    — ángulo de pisada
//   - Jordan et al. (2007)       — variabilidad de zancada
//
// Integración: llamar evaluate(metrics) cada vez que MetricsCalculator
// emite nuevas métricas (p.ej. cada 10 pasos). Si devuelve null, la
// técnica está dentro de los rangos normales.

import 'running_metrics.dart'; // modelo RunningMetrics generado por metrics_calculator

/// Motor de recomendaciones para running.
///
/// Prioridad de evaluación (de mayor a menor urgencia):
///   1. Cadencia
///   2. Simetría L/R
///   3. Tiempo de contacto
///   4. Ángulo de pisada
///   5. Variabilidad de zancada
class RecommendationEngine {
  // ─── Mínimo de pasos antes de emitir recomendaciones ───────────────────────
  /// No se emiten recomendaciones hasta acumular este número de pasos.
  /// Evita falsos positivos en los primeros segundos de la sesión.
  static const int _minSteps = 20;

  // ─── Umbrales de cadencia (spm) ────────────────────────────────────────────
  /// < 150 spm: muy baja — riesgo de sobrecarga articular (Heiderscheit 2011).
  static const double _cadenceLowCritical = 150.0;

  /// 150–159 spm: baja — común en recreativos principiantes.
  static const double _cadenceLow = 160.0;

  /// > 200 spm: muy alta — rara en distancias largas, posible zancada corta.
  static const double _cadenceHigh = 200.0;

  // ─── Umbrales de simetría L/R (%) ──────────────────────────────────────────
  /// < 43 %: asimetría significativa con carga predominante en pie derecho
  /// (Zifchock 2006 — >10 % clínicamente relevante).
  static const double _symmetryCriticalLow = 43.0;

  /// 43–46 %: asimetría leve hacia pie derecho — aviso preventivo.
  static const double _symmetryWarningLow = 46.0;

  /// 54–57 %: asimetría leve hacia pie izquierdo — aviso preventivo.
  static const double _symmetryWarningHigh = 54.0;

  /// > 57 %: asimetría significativa con carga predominante en pie izquierdo.
  static const double _symmetryCriticalHigh = 57.0;

  // ─── Umbrales de tiempo de contacto (ms) ───────────────────────────────────
  /// > 280 ms: técnica lenta — runners recreativos a 12 km/h ~250 ms
  /// (Morin 2011); élite ~185 ms.
  static const double _contactTimeHigh = 280.0;

  /// < 160 ms: contacto muy corto — posible tensión o pisada reactiva excesiva.
  static const double _contactTimeLow = 160.0;

  // ─── Umbrales de ángulo de pisada (grados, pitch del tobillo en impacto) ───
  /// > 20°: heel strike severo — alto impacto articular (Lieberman 2010).
  static const double _strikeAngleCritical = 20.0;

  /// 10–20°: heel strike moderado — común en corredores recreativos.
  static const double _strikeAngleWarning = 10.0;

  // ─── Umbral de variabilidad de zancada (CV %) ──────────────────────────────
  /// > 8 % CV: alta variabilidad — puede indicar fatiga o técnica irregular
  /// (Jordan 2007 — corredores sanos: 3–5 % CV).
  static const double _variabilityHigh = 8.0;

  // ───────────────────────────────────────────────────────────────────────────

  /// Evalúa las métricas actuales y devuelve la recomendación más urgente,
  /// o [null] si todo está dentro de los rangos normales.
  ///
  /// Se deben haber acumulado al menos [_minSteps] pasos para que el motor
  /// empiece a emitir recomendaciones.
  String? evaluate(RunningMetrics m) {
    if (m.stepCount < _minSteps) return null;

    return _checkCadence(m)
        ?? _checkSymmetry(m)
        ?? _checkContactTime(m)
        ?? _checkStrikeAngle(m)
        ?? _checkVariability(m);
  }

  // ─── Verificaciones individuales ───────────────────────────────────────────

  /// Cadencia: rango óptimo 175–185 spm; aceptable 160–200 spm.
  String? _checkCadence(RunningMetrics m) {
    final c = m.cadenceStepsPerMin;
    if (c <= 0) return null; // sin datos suficientes

    if (c < _cadenceLowCritical) {
      return 'Cadencia muy baja (${c.round()} spm). '
          'Acorta el paso y aumenta la frecuencia: apunta a 170–180 spm.';
    }
    if (c < _cadenceLow) {
      return 'Cadencia de ${c.round()} spm, un poco baja. '
          'Intenta dar pasos ligeramente más rápidos sin alargar el salto.';
    }
    if (c > _cadenceHigh) {
      return 'Cadencia muy alta (${c.round()} spm). '
          'Asegúrate de que cada paso tenga longitud suficiente para avanzar con eficiencia.';
    }
    return null;
  }

  /// Simetría L/R: rango normal 46–54 %; fuera de ese rango se avisa.
  String? _checkSymmetry(RunningMetrics m) {
    final s = m.symmetryPercent;

    if (s < _symmetryCriticalLow) {
      final rightLoad = (100 - s).toStringAsFixed(1);
      return 'Asimetría importante: el pie derecho carga el $rightLoad % del tiempo. '
          'Empuja con igual fuerza con ambos pies en cada zancada.';
    }
    if (s > _symmetryCriticalHigh) {
      final leftLoad = s.toStringAsFixed(1);
      return 'Asimetría importante: el pie izquierdo carga el $leftLoad % del tiempo. '
          'Empuja con igual fuerza con ambos pies en cada zancada.';
    }
    if (s < _symmetryWarningLow) {
      return 'Leve asimetría hacia el pie derecho (${s.toStringAsFixed(1)} % izquierda). '
          'Mantén un ritmo uniforme entre ambas piernas.';
    }
    if (s > _symmetryWarningHigh) {
      return 'Leve asimetría hacia el pie izquierdo (${s.toStringAsFixed(1)} %). '
          'Mantén un ritmo uniforme entre ambas piernas.';
    }
    return null;
  }

  /// Tiempo de contacto: rango normal 160–280 ms.
  String? _checkContactTime(RunningMetrics m) {
    final ct = m.avgContactTimeMs;
    if (ct <= 0) return null;

    if (ct > _contactTimeHigh) {
      return 'Tiempo de contacto alto (${ct.round()} ms). '
          'Rebota más rápido del suelo: imagina que el suelo quema y retira el pie de inmediato.';
    }
    if (ct < _contactTimeLow) {
      return 'Contacto muy corto (${ct.round()} ms), puede indicar pisada tensa. '
          'Relaja los pies y deja que el pie aterrice con suavidad antes de despegar.';
    }
    return null;
  }

  /// Ángulo de pisada: rango eficiente 0–10°; > 10° indica heel strike.
  String? _checkStrikeAngle(RunningMetrics m) {
    final a = m.strikeAngleDeg;

    if (a > _strikeAngleCritical) {
      return 'Pisada muy de talón (${a.round()}°). '
          'Aterriza más debajo de tu centro de masa: lleva el pie más hacia atrás antes del impacto.';
    }
    if (a > _strikeAngleWarning) {
      return 'Ángulo de pisada de ${a.round()}°, ligeramente hacia el talón. '
          'Prueba un ciclo de zancada más compacto: rodilla ligeramente más flexionada al aterrizar.';
    }
    return null;
  }

  /// Variabilidad de zancada: normal < 8 % CV.
  String? _checkVariability(RunningMetrics m) {
    final v = m.strideVariability;
    if (v <= 0) return null;

    if (v > _variabilityHigh) {
      return 'Zancada irregular (${v.toStringAsFixed(1)} % de variabilidad). '
          'Mantén un ritmo constante: busca un punto fijo al frente y ajusta la frecuencia de pasos.';
    }
    return null;
  }
}
