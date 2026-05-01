---
name: biomechanics-analyzer
description: >
  Use this skill whenever the user wants to implement, improve, or debug biomechanical analysis
  for the wearable sport monitor. Trigger on ANY mention of: biomechanics, cadence, symmetry,
  strike angle, contact time, stride variability, impact detection, step detection, running metrics,
  gait analysis, recommendation engine, running feedback, or post-session report.
  Also trigger for Sprint 3 work ("motor de análisis", "reglas de recomendación"), any request
  involving SensorData processing beyond raw parsing, Python analysis scripts, offline calibration,
  fl_chart visualizations of biomechanical data, or phrases like "analizar los datos del sensor",
  "detectar impacto", "calcular cadencia", "recomendaciones de running", or "reporte de sesión".
  When in doubt about whether a task involves processing IMU data to extract meaning, use this skill.
---

# Biomechanics Analyzer Skill — Wearable Sport Monitor

## Contexto del proyecto

Este skill genera el **motor de análisis biomecánico** que transforma los datos crudos de los nodos
IMU (cuaterniones + aceleración del BNO085) en métricas accionables y recomendaciones personalizadas.

El pipeline tiene dos contextos:
- **Tiempo real (Dart/Flutter):** corre en el teléfono a medida que llegan los paquetes BLE a 100 Hz
- **Análisis offline (Python):** scripts para explorar sesiones grabadas, calibrar umbrales, validar algoritmos

Antes de generar código, **lee los archivos de referencia relevantes**:
- `references/running_biomechanics.md` — rangos normativos, umbrales clínicos, fórmulas validadas

---

## Métricas de running a calcular

| Métrica | Fuente de datos | Método | Unidad |
|---|---|---|---|
| Cadencia | Aceleración (magnitud) | Detección de picos de impacto | pasos/min |
| Simetría L/R | Tiempo de contacto L vs R | Ratio porcentual | % (50% = ideal) |
| Tiempo de contacto | Aceleración vertical | Ventana entre impacto y despegue | ms |
| Ángulo de pisada | Pitch en momento de impacto | Ángulo de Euler del tobillo | grados |
| Variabilidad de zancada | Intervalos entre pasos | Coeficiente de variación | % |
| Carga de impacto | Magnitud de aceleración en pico | Promedio móvil de picos | m/s² |

---

## Arquitectura del pipeline en Dart

### Estructura de archivos a generar

```
lib/analysis/
├── running_analyzer.dart       ← orchestrator principal
├── event_detector.dart         ← detección de impacto y despegue
├── metrics_calculator.dart     ← cadencia, simetría, contacto, etc.
├── recommendation_engine.dart  ← reglas → texto accionable
└── session_summary.dart        ← agregación post-sesión
```

### Flujo de datos

```
SensorData (100 Hz)
  → EventDetector (detecta IMPACT / TAKEOFF por tobillo)
  → MetricsCalculator (actualiza métricas con cada evento)
  → RecommendationEngine (evalúa reglas cada N pasos)
  → SessionProvider.notifyListeners() (actualiza UI)
```

---

## EventDetector — detección de eventos en la señal IMU

Usa la **magnitud del vector de aceleración lineal** (sin gravedad, ya filtrada por el BNO085).
Dos umbrales distintos (histéresis) evitan oscilación en la zona de transición:

```dart
enum GaitEvent { impact, takeoff }

class GaitEventDetector {
  static const double _impactThreshold  = 12.0;  // m/s²
  static const double _takeoffThreshold =  2.5;  // m/s²
  static const int    _minStepMs        =  200;  // 300 spm máximo fisiológico
  static const int    _maxContactMs     =  500;  // contacto > 500ms no es running

  bool _inStance = false;
  int  _lastImpactMs = 0;
  int  _stanceStartMs = 0;

  final void Function(GaitEvent, String nodeId, int timestampMs, double value) onEvent;
  GaitEventDetector({required this.onEvent});

  void process(SensorData s) {
    final mag = sqrt(s.accelX*s.accelX + s.accelY*s.accelY + s.accelZ*s.accelZ);
    if (!_inStance && mag >= _impactThreshold) {
      final interval = s.timestampMs - _lastImpactMs;
      if (interval >= _minStepMs || _lastImpactMs == 0) {
        _inStance = true;
        _stanceStartMs = s.timestampMs;
        _lastImpactMs  = s.timestampMs;
        onEvent(GaitEvent.impact, s.nodeId, s.timestampMs, s.pitch);
      }
    } else if (_inStance && mag < _takeoffThreshold) {
      final contactMs = s.timestampMs - _stanceStartMs;
      if (contactMs > 50 && contactMs < _maxContactMs) {
        _inStance = false;
        onEvent(GaitEvent.takeoff, s.nodeId, s.timestampMs, contactMs.toDouble());
      }
    }
  }
}
```

---

## MetricsCalculator — ventana deslizante de N pasos

Todas las métricas usan los **últimos 10 pasos** para reflejar el estado actual, no el promedio histórico:

```dart
class MetricsCalculator {
  static const int _windowSteps = 10;

  final _stepIntervals = {'LEFT_ANKLE': <int>[], 'RIGHT_ANKLE': <int>[]};
  final _contactTimes  = {'LEFT_ANKLE': <double>[], 'RIGHT_ANKLE': <double>[]};
  final _strikeAngles  = {'LEFT_ANKLE': <double>[], 'RIGHT_ANKLE': <double>[]};
  final _impactLoads   = {'LEFT_ANKLE': <double>[], 'RIGHT_ANKLE': <double>[]};
  final _lastImpact    = {'LEFT_ANKLE': 0, 'RIGHT_ANKLE': 0};

  void recordImpact(String nodeId, int timestampMs, double strikeAngle, double impactLoad) {
    final prev = _lastImpact[nodeId]!;
    if (prev > 0) {
      _stepIntervals[nodeId]!.add(timestampMs - prev);
      _trim(_stepIntervals[nodeId]!);
    }
    _lastImpact[nodeId] = timestampMs;
    _strikeAngles[nodeId]!.add(strikeAngle);
    _impactLoads[nodeId]!.add(impactLoad);
    _trim(_strikeAngles[nodeId]!);
    _trim(_impactLoads[nodeId]!);
  }

  void recordContactTime(String nodeId, double contactMs) {
    _contactTimes[nodeId]!.add(contactMs);
    _trim(_contactTimes[nodeId]!);
  }

  RunningMetrics compute(int stepCount) {
    return RunningMetrics(
      cadenceStepsPerMin: _computeCadence(),
      symmetryPercent:    _computeSymmetry(),
      avgContactTimeMs:   _mean([..._contactTimes['LEFT_ANKLE']!, ..._contactTimes['RIGHT_ANKLE']!]),
      strikeAngleDeg:     _mean([..._strikeAngles['LEFT_ANKLE']!, ..._strikeAngles['RIGHT_ANKLE']!]),
      strideVariability:  _computeVariability('LEFT_ANKLE'),
      stepCount:          stepCount,
    );
  }

  double _computeCadence() {
    final all = [..._stepIntervals['LEFT_ANKLE']!, ..._stepIntervals['RIGHT_ANKLE']!];
    if (all.isEmpty) return 0;
    return 60000.0 / _mean(all.map((i) => i.toDouble()).toList());
  }

  double _computeSymmetry() {
    final cL = _mean(_contactTimes['LEFT_ANKLE']!);
    final cR = _mean(_contactTimes['RIGHT_ANKLE']!);
    return (cL + cR) > 0 ? (cL / (cL + cR)) * 100.0 : 50.0;
  }

  double _computeVariability(String nodeId) {
    final vals = _stepIntervals[nodeId]!.map((i) => i.toDouble()).toList();
    if (vals.length < 3) return 0;
    final mean = _mean(vals);
    if (mean == 0) return 0;
    final variance = vals.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / vals.length;
    return (sqrt(variance) / mean) * 100.0;
  }

  double _mean(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  void _trim(List list) { while (list.length > _windowSteps) list.removeAt(0); }
}
```

---

## RecommendationEngine — reglas por métrica

Una recomendación a la vez (la más urgente). Específica, accionable, no alarmista.

```dart
class RecommendationEngine {
  static const int _minSteps = 20;

  String? evaluate(RunningMetrics m) {
    if (m.stepCount < _minSteps) return null;
    return _checkCadence(m)
        ?? _checkSymmetry(m)
        ?? _checkContactTime(m)
        ?? _checkStrikeAngle(m)
        ?? _checkVariability(m);
  }

  String? _checkCadence(RunningMetrics m) {
    final c = m.cadenceStepsPerMin;
    if (c < 150) return 'Cadencia muy baja (${c.round()} spm). Acorta el paso y aumenta la frecuencia — apunta a 165–180 spm.';
    if (c < 160) return 'Cadencia de ${c.round()} spm — un poco baja. Intenta dar pasos un poco más rápidos.';
    if (c > 200) return 'Cadencia muy alta (${c.round()} spm). Asegúrate de que tus pasos tengan longitud suficiente.';
    return null;
  }

  String? _checkSymmetry(RunningMetrics m) {
    final s = m.symmetryPercent;
    if (s < 43) return 'Asimetría: el pie derecho carga más (${(100-s).toStringAsFixed(1)}%). Empuja igual con ambos pies.';
    if (s > 57) return 'Asimetría: el pie izquierdo carga más (${s.toStringAsFixed(1)}%). Empuja igual con ambos pies.';
    if (s < 46 || s > 54) return 'Leve asimetría detectada — mantén un ritmo uniforme entre ambas piernas.';
    return null;
  }

  String? _checkContactTime(RunningMetrics m) {
    final ct = m.avgContactTimeMs;
    if (ct > 280) return 'Tiempo de contacto alto (${ct.round()} ms). "Rebota" más rápido del suelo.';
    if (ct < 160) return 'Contacto muy corto (${ct.round()} ms) — puede indicar pisada tensa. Relaja los pies.';
    return null;
  }

  String? _checkStrikeAngle(RunningMetrics m) {
    final a = m.strikeAngleDeg;
    if (a > 20) return 'Talón muy adelantado (${a.round()}°). Aterriza más debajo de tu centro de masa.';
    if (a > 10) return 'Ángulo de pisada ${a.round()}° — ligeramente hacia el talón. Ciclo de zancada más compacto.';
    return null;
  }

  String? _checkVariability(RunningMetrics m) {
    if (m.strideVariability > 8)
      return 'Zancada irregular (${m.strideVariability.toStringAsFixed(1)}% variabilidad). Mantén un ritmo constante.';
    return null;
  }
}
```

**Rangos normativos de los umbrales:** ver `references/running_biomechanics.md`.

---

## SessionSummary — agregación post-sesión

```dart
class SessionSummary {
  final Duration totalDuration;
  final int totalSteps;
  final double avgCadence;
  final double avgSymmetry;
  final double avgContactTime;
  final double avgStrikeAngle;
  final double avgVariability;
  final List<String> topRecommendations;  // máximo 3

  int get overallScore {
    double score = 100;
    if (avgCadence < 160 || avgCadence > 190) score -= 15;
    if (avgSymmetry < 45 || avgSymmetry > 55) score -= 20;
    if (avgContactTime > 280)                 score -= 10;
    if (avgStrikeAngle > 15)                  score -= 10;
    if (avgVariability > 6)                   score -= 10;
    return score.clamp(0, 100).round();
  }

  String get scoreLabel {
    final s = overallScore;
    if (s >= 85) return 'Excelente';
    if (s >= 70) return 'Buena';
    if (s >= 55) return 'Regular';
    return 'Mejorable';
  }
}
```

---

## Scripts Python — análisis offline y calibración

Generar scripts con esta estructura base:

```python
# analyze_session.py
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import find_peaks

def load_session(csv_path):
    """CSV columns: timestamp_ms, node_id, qw,qx,qy,qz, accel_x,accel_y,accel_z, roll,pitch,yaw"""
    return pd.read_csv(csv_path)

def accel_magnitude(df):
    return np.sqrt(df.accel_x**2 + df.accel_y**2 + df.accel_z**2)

def detect_impacts(mag, threshold=12.0, min_distance=20):
    """min_distance=20 samples @ 100Hz = 200ms (300 spm max)"""
    peaks, _ = find_peaks(mag, height=threshold, distance=min_distance)
    return peaks

def cadence_timeseries(impact_timestamps_ms, window=10):
    intervals = np.diff(impact_timestamps_ms)
    cadence_per_step = 60000.0 / intervals
    return pd.Series(cadence_per_step).rolling(window, min_periods=1).mean()

def plot_session(df, node_id, threshold=12.0):
    node = df[df.node_id == node_id].copy()
    mag = accel_magnitude(node)
    peaks = detect_impacts(mag, threshold)

    fig, axes = plt.subplots(3, 1, figsize=(14, 9), sharex=True)

    axes[0].plot(node.timestamp_ms, mag, lw=0.8, label='|accel|')
    axes[0].axhline(threshold, color='r', ls='--', label=f'threshold={threshold}')
    axes[0].scatter(node.timestamp_ms.iloc[peaks], mag.iloc[peaks], c='red', s=20, zorder=5)
    axes[0].set_ylabel('Accel (m/s²)'); axes[0].legend(fontsize=8)

    axes[1].plot(node.timestamp_ms, node.pitch, lw=0.8, color='green', label='pitch (strike angle)')
    axes[1].scatter(node.timestamp_ms.iloc[peaks], node.pitch.iloc[peaks], c='darkgreen', s=20, zorder=5)
    axes[1].axhline(10, color='orange', ls=':', label='10° threshold')
    axes[1].axhline(20, color='red',    ls=':', label='20° threshold')
    axes[1].set_ylabel('Pitch (°)'); axes[1].legend(fontsize=8)

    if len(peaks) > 1:
        cad = cadence_timeseries(node.timestamp_ms.iloc[peaks].values)
        axes[2].plot(node.timestamp_ms.iloc[peaks[1:]], cad.values, lw=1.5, color='purple')
        axes[2].axhline(160, color='orange', ls=':', label='160 spm')
        axes[2].axhline(180, color='green',  ls=':', label='180 spm')
        axes[2].set_ylabel('Cadence (spm)'); axes[2].legend(fontsize=8)

    axes[2].set_xlabel('Time (ms)')
    plt.suptitle(f'Session Analysis — {node_id} ({len(peaks)} impacts detected)')
    plt.tight_layout(); plt.show()

if __name__ == '__main__':
    import sys
    df = load_session(sys.argv[1] if len(sys.argv) > 1 else 'session.csv')
    for nid in df.node_id.unique():
        plot_session(df, nid)
```

**Dependencias:** `pip install pandas numpy matplotlib scipy`

---

## Formato del output

Cuando generes código de análisis biomecánico:

1. **Dart:** crea cada archivo en `lib/analysis/`. Los modelos `SensorData` y `RunningMetrics` vienen de `flutter-ble`.
2. **Python:** crea scripts en `analysis/` con parámetros como constantes configurables en la parte superior del archivo.
3. **Al terminar**, muestra:
   - Lista de archivos creados
   - Umbrales clave y su justificación (referenciando `running_biomechanics.md`)
   - Cómo integrar con `SessionProvider` (Dart) o cómo usar el script (Python)
   - Pasos concretos de calibración con datos reales del prototipo
