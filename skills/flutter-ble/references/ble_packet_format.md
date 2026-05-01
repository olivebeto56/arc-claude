# Formato de paquete BLE del nodo sensor

## Estructura del paquete (14–16 bytes, little-endian)

```
Offset  Tipo      Campo            Escala           Descripción
──────  ────────  ───────────────  ───────────────  ──────────────────────────────
0–1     uint16    timestamp_ms     1 ms/LSB         Tiempo relativo al inicio de sesión
2–3     int16     qw               ÷ 10000          Parte real del cuaternión
4–5     int16     qx               ÷ 10000          Parte i del cuaternión
6–7     int16     qy               ÷ 10000          Parte j del cuaternión
8–9     int16     qz               ÷ 10000          Parte k del cuaternión
10–11   int16     accel_x          × 9.81/1000      Aceleración X sin gravedad (m/s²)
12–13   int16     accel_y          × 9.81/1000      Aceleración Y sin gravedad (m/s²)
14–15   int16     accel_z          × 9.81/1000      Aceleración Z sin gravedad (m/s²)
```

**Total: 16 bytes** (cabe en MTU BLE de 20 bytes con 4 bytes de overhead ATT)

**Nota:** El firmware v1 puede enviar 14 bytes (sin accel_z). Verificar `bytes.length` antes de parsear.

---

## Convención de ejes del BNO085 montado en el tobillo

Cuando el nodo está montado en el tobillo (cara plana hacia arriba):
- **X:** apunta hacia adelante (dirección de la marcha)
- **Y:** apunta hacia arriba (perpendicular al suelo)
- **Z:** apunta hacia la derecha del atleta

Para el análisis de running:
- **Eje Y (pitch):** ángulo de pisada (positivo = talón primero, negativo = punta)
- **Eje Z (yaw):** rotación del tobillo (pronación/supinación)
- **Aceleración Y:** componente vertical — usada para detectar impacto y tiempo de vuelo

---

## Parsing en Dart

```dart
import 'dart:typed_data';
import 'dart:math' as math;

class SensorParser {
  static const double _quatScale   = 1.0 / 10000.0;
  static const double _accelScale  = 9.81 / 1000.0;  // mili-g → m/s²

  static SensorData? parse(List<int> bytes, String nodeId) {
    if (bytes.length < 14) return null;  // paquete truncado

    try {
      final buf = ByteData.sublistView(Uint8List.fromList(bytes));

      final ts = buf.getUint16(0, Endian.little);
      final qw = buf.getInt16(2, Endian.little) * _quatScale;
      final qx = buf.getInt16(4, Endian.little) * _quatScale;
      final qy = buf.getInt16(6, Endian.little) * _quatScale;
      final qz = buf.getInt16(8, Endian.little) * _quatScale;
      final ax = buf.getInt16(10, Endian.little) * _accelScale;
      final ay = buf.getInt16(12, Endian.little) * _accelScale;
      final az = bytes.length >= 16
          ? buf.getInt16(14, Endian.little) * _accelScale
          : 0.0;

      return SensorData.fromQuaternion(
        nodeId: nodeId, timestampMs: ts,
        qw: qw, qx: qx, qy: qy, qz: qz,
        accelX: ax, accelY: ay, accelZ: az,
      );
    } catch (e) {
      // Paquete malformado — ignorar silenciosamente
      return null;
    }
  }
}
```

---

## Algoritmos de métricas de running

### Cadencia (pasos por minuto)

Detectar impactos como picos de aceleración vertical (eje Y) que superan un umbral:

```dart
class CadenceDetector {
  static const double _impactThreshold = 15.0;  // m/s² — ajustar con datos reales
  static const int _minStepIntervalMs  = 200;    // 300 spm máximo fisiológico

  int _lastImpactMs = 0;
  final List<int> _stepIntervals = [];  // últimos 10 intervalos

  /// Devuelve cadencia actualizada si detectó un nuevo paso, null si no
  double? processSample(SensorData sample) {
    final accelMag = math.sqrt(
      sample.accelX * sample.accelX +
      sample.accelY * sample.accelY +
      sample.accelZ * sample.accelZ,
    );

    if (accelMag > _impactThreshold) {
      final interval = sample.timestampMs - _lastImpactMs;
      if (interval > _minStepIntervalMs && _lastImpactMs > 0) {
        _stepIntervals.add(interval);
        if (_stepIntervals.length > 10) _stepIntervals.removeAt(0);
        _lastImpactMs = sample.timestampMs;

        // Cadencia = 60000 ms/min ÷ intervalo_promedio_ms × 2 (ambos pies)
        final avgInterval = _stepIntervals.reduce((a, b) => a + b) / _stepIntervals.length;
        return (60000 / avgInterval) * 2;
      }
      if (_lastImpactMs == 0) _lastImpactMs = sample.timestampMs;
    }
    return null;
  }
}
```

### Simetría L/R

```dart
/// Comparar el tiempo de contacto promedio entre pie izquierdo y derecho
/// symmetry = 50% es perfectamente simétrico
/// < 45% o > 55% = asimetría significativa
double computeSymmetry(double avgContactLeft, double avgContactRight) {
  final total = avgContactLeft + avgContactRight;
  if (total == 0) return 50.0;
  return (avgContactLeft / total) * 100.0;
}
```

### Tiempo de contacto con el suelo

Se detecta como el tiempo entre el impacto (pico de aceleración) y el despegue (aceleración vuelve a umbral bajo):

```dart
class ContactTimeDetector {
  static const double _impactThreshold  = 15.0;
  static const double _flightThreshold  = 2.0;   // m/s² — en vuelo la aceleración es baja

  bool _inContact = false;
  int  _contactStartMs = 0;
  final List<double> _contactTimes = [];

  double? processSample(SensorData s) {
    final mag = math.sqrt(s.accelX*s.accelX + s.accelY*s.accelY + s.accelZ*s.accelZ);

    if (!_inContact && mag > _impactThreshold) {
      _inContact = true;
      _contactStartMs = s.timestampMs;
    } else if (_inContact && mag < _flightThreshold) {
      _inContact = false;
      final contactMs = (s.timestampMs - _contactStartMs).toDouble();
      if (contactMs > 50 && contactMs < 500) {  // rango fisiológico válido
        _contactTimes.add(contactMs);
        if (_contactTimes.length > 20) _contactTimes.removeAt(0);
        return _contactTimes.reduce((a, b) => a + b) / _contactTimes.length;
      }
    }
    return null;
  }
}
```

### Ángulo de pisada (strike angle)

```dart
/// pitch positivo = talón (heel strike)
/// pitch negativo = punta (forefoot strike)
/// Capturar el pitch en el momento del impacto
double getStrikeAngle(SensorData atImpact) => atImpact.pitch;
```

---

## Visualización con fl_chart

### Gráfica de cadencia en tiempo real (LineChart)

```dart
LineChartData cadenceChartData(List<FlSpot> cadenceHistory) {
  return LineChartData(
    minY: 120, maxY: 220,
    lineBarsData: [
      LineChartBarData(
        spots: cadenceHistory,
        isCurved: true,
        color: const Color(0xFF00E5FF),
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ),
    ],
    titlesData: FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ),
      ),
      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    gridData: FlGridData(
      show: true,
      getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
      drawVerticalLine: false,
    ),
    borderData: FlBorderData(show: false),
  );
}
```

### Indicador de simetría L/R (barra bicolor)

```dart
Widget symmetryBar(double symmetryPct) {
  final isBalanced = symmetryPct >= 45 && symmetryPct <= 55;
  return Column(
    children: [
      Text('Simetría ${symmetryPct.toStringAsFixed(1)}%',
          style: TextStyle(color: isBalanced ? Colors.greenAccent : Colors.orangeAccent)),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: symmetryPct / 100,
          backgroundColor: const Color(0xFF00E5FF).withOpacity(0.3),
          valueColor: AlwaysStoppedAnimation(
              isBalanced ? Colors.greenAccent : Colors.orangeAccent),
          minHeight: 16,
        ),
      ),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text('Izq', style: TextStyle(color: Colors.white54, fontSize: 10)),
                   Text('Der', style: TextStyle(color: Colors.white54, fontSize: 10))],
      ),
    ],
  );
}
```
