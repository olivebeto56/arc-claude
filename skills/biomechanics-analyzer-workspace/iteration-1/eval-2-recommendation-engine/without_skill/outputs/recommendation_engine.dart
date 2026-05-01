/// Motor de recomendaciones biomecánicas para running.
///
/// Evalúa las métricas de carrera y devuelve una sola recomendación accionable
/// en español. Las reglas se aplican en orden de prioridad (crítico → warning).

class RunningMetrics {
  /// Cadencia en pasos por minuto (spm).
  final double cadence;

  /// Simetría de carga entre pierna izquierda y derecha (%).
  /// Un valor de 50 % indica distribución perfectamente simétrica.
  final double symmetry;

  /// Tiempo de contacto medio con el suelo en milisegundos (ms).
  final double contactTime;

  /// Ángulo de pisada respecto a la vertical (°).
  final double strikeAngle;

  /// Variabilidad del paso (coeficiente de variación, %).
  final double variability;

  const RunningMetrics({
    required this.cadence,
    required this.symmetry,
    required this.contactTime,
    required this.strikeAngle,
    required this.variability,
  });
}

class RecommendationEngine {
  // ── Umbrales de cadencia ──────────────────────────────────────────────────
  static const double _cadenceLow = 160.0; // spm
  static const double _cadenceHigh = 200.0; // spm

  // ── Umbrales de simetría ──────────────────────────────────────────────────
  static const double _symmetryMin = 46.0; // %
  static const double _symmetryMax = 54.0; // %

  // ── Umbrales de tiempo de contacto ───────────────────────────────────────
  static const double _contactTimeMax = 280.0; // ms
  static const double _contactTimeMin = 160.0; // ms

  // ── Umbrales de ángulo de pisada ──────────────────────────────────────────
  static const double _strikeAngleWarning = 10.0; // °
  static const double _strikeAngleCritical = 20.0; // °

  // ── Umbrales de variabilidad ──────────────────────────────────────────────
  static const double _variabilityMax = 8.0; // %

  /// Evalúa [m] y devuelve una recomendación accionable en español,
  /// o `null` si todos los parámetros están dentro de los rangos óptimos.
  ///
  /// Las reglas se aplican en orden de prioridad: primero las condiciones
  /// críticas, luego las advertencias.
  String? evaluate(RunningMetrics m) {
    // 1. Ángulo de pisada crítico (> 20°) — mayor riesgo de lesión
    if (m.strikeAngle > _strikeAngleCritical) {
      return 'Ángulo de pisada crítico: ${m.strikeAngle.toStringAsFixed(1)}°. '
          'Supera el límite de ${_strikeAngleCritical.toStringAsFixed(0)}°. '
          'Aterriza con el pie más cerca de la línea de tu centro de masa y '
          'reduce la zancada para corregir la inclinación.';
    }

    // 2. Tiempo de contacto demasiado largo (> 280 ms) — baja eficiencia
    if (m.contactTime > _contactTimeMax) {
      return 'Tiempo de contacto elevado: ${m.contactTime.toStringAsFixed(0)} ms '
          '(óptimo < ${_contactTimeMax.toStringAsFixed(0)} ms). '
          'Trabaja ejercicios de stiffness y pliometría para reducir el tiempo '
          'de apoyo y mejorar la elasticidad muscular.';
    }

    // 3. Tiempo de contacto demasiado corto (< 160 ms) — posible sobrecarga
    if (m.contactTime < _contactTimeMin) {
      return 'Tiempo de contacto muy corto: ${m.contactTime.toStringAsFixed(0)} ms '
          '(mínimo recomendado ${_contactTimeMin.toStringAsFixed(0)} ms). '
          'Reduce ligeramente la velocidad y concéntrate en un apoyo más '
          'controlado para evitar sobrecarga articular.';
    }

    // 4. Cadencia baja (< 160 spm) — sobrecarga de impacto
    if (m.cadence < _cadenceLow) {
      return 'Cadencia baja: ${m.cadence.toStringAsFixed(0)} spm '
          '(mínimo recomendado ${_cadenceLow.toStringAsFixed(0)} spm). '
          'Acorta la zancada y aumenta la frecuencia de paso; usa un metrónomo '
          'a ${_cadenceLow.toStringAsFixed(0)} spm para recalibrar el ritmo.';
    }

    // 5. Cadencia alta (> 200 spm) — posible hiperactividad neuromuscular
    if (m.cadence > _cadenceHigh) {
      return 'Cadencia elevada: ${m.cadence.toStringAsFixed(0)} spm '
          '(máximo recomendado ${_cadenceHigh.toStringAsFixed(0)} spm). '
          'Intenta ampliar levemente la zancada y relaja la tensión en piernas '
          'para alcanzar una cadencia más eficiente.';
    }

    // 6. Asimetría de carga
    if (m.symmetry < _symmetryMin || m.symmetry > _symmetryMax) {
      final side = m.symmetry < _symmetryMin ? 'derecha' : 'izquierda';
      final excess = (m.symmetry - 50.0).abs().toStringAsFixed(1);
      return 'Asimetría de carga detectada: ${m.symmetry.toStringAsFixed(1)} % '
          '(rango óptimo ${_symmetryMin.toStringAsFixed(0)}–'
          '${_symmetryMax.toStringAsFixed(0)} %). '
          'La pierna $side recibe $excess % más de carga. '
          'Refuerza la cadera y el glúteo del lado dominante con ejercicios '
          'unilaterales de equilibrio.';
    }

    // 7. Ángulo de pisada en zona de advertencia (10°–20°)
    if (m.strikeAngle > _strikeAngleWarning) {
      return 'Ángulo de pisada elevado: ${m.strikeAngle.toStringAsFixed(1)}° '
          '(advertencia > ${_strikeAngleWarning.toStringAsFixed(0)}°). '
          'Procura aterrizar con el pie más bajo y cerca del cuerpo; '
          'realiza ejercicios de postura de carrera para corregir la tendencia.';
    }

    // 8. Variabilidad excesiva (> 8 %)
    if (m.variability > _variabilityMax) {
      return 'Variabilidad de paso alta: ${m.variability.toStringAsFixed(1)} % '
          '(máximo recomendado ${_variabilityMax.toStringAsFixed(0)} %). '
          'Esto puede indicar fatiga o inestabilidad. Reduce el ritmo, '
          'activa el core y mantén la mirada al frente para estabilizar '
          'la zancada.';
    }

    // Todos los parámetros dentro de rango óptimo
    return null;
  }
}
