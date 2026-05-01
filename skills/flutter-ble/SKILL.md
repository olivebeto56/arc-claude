---
name: flutter-ble
description: >
  Use this skill whenever the user wants to write, generate, or modify Flutter code for the
  wearable sport monitor app. Trigger on ANY mention of: Flutter widgets, Dart code, BLE scanning,
  multi-node connection, sensor data display, running dashboard, fl_chart, flutter_blue_plus,
  Provider state management, SensorDataParser, BleManager, or real-time metrics UI.
  Also trigger for Sprint 2, Sprint 3, or Sprint 4 work in the wearable project, or any request
  to "mostrar datos del sensor", "conectar los nodos", "pantalla de running", "parsear paquetes BLE",
  "dashboard de métricas", or "app Flutter del wearable". When in doubt about whether to use this
  skill for a Flutter/Dart task in this project, use it.
---

# Flutter BLE Skill — Wearable Sport Monitor App

## Contexto del proyecto

Esta app Flutter recibe datos de **2 nodos BLE simultáneos** (tobillo izquierdo + tobillo derecho), parsea los paquetes de cuaterniones e IMU, y muestra métricas biomecánicas de running en tiempo real.

Stack fijo del proyecto:
- **BLE:** `flutter_blue_plus` (escaneo por UUID, conexión multi-dispositivo)
- **Estado:** `Provider` (ChangeNotifier)
- **Gráficas:** `fl_chart`
- **Target:** Android + iOS (prototipo demo para inversores)

Antes de generar código, **lee los archivos de referencia relevantes**:
- `references/flutter_blue_plus.md` — API de la librería, patrones de escaneo y conexión multi-nodo
- `references/ble_packet_format.md` — formato exacto del paquete del nodo (14 bytes), cómo parsear cuaterniones y aceleración

---

## Estructura de proyecto recomendada

```
lib/
├── main.dart
├── models/
│   └── sensor_data.dart          ← SensorData, RunningMetrics structs
├── services/
│   ├── ble_manager.dart          ← escaneo, conexión, subscripción multi-nodo
│   └── sensor_parser.dart        ← decodifica paquetes BLE → SensorData
├── providers/
│   └── session_provider.dart     ← ChangeNotifier con estado de sesión y métricas
└── screens/
    ├── scan_screen.dart           ← escaneo y conexión de nodos
    ├── running_screen.dart        ← dashboard en tiempo real
    └── summary_screen.dart        ← resumen post-sesión
```

Cuando generes código, **crea cada archivo por separado** guardado en la carpeta del proyecto. Siempre comenta el código en inglés.

---

## Modelos de datos — usar siempre estos structs

```dart
// models/sensor_data.dart

class SensorData {
  final String nodeId;       // "LEFT_ANKLE" o "RIGHT_ANKLE"
  final int timestampMs;     // relativo al inicio de sesión
  final double qw, qx, qy, qz;  // cuaternión (ya convertido de int16 a double)
  final double accelX, accelY, accelZ;  // aceleración en m/s² (sin gravedad)
  final double roll, pitch, yaw;        // ángulos de Euler calculados

  const SensorData({...});

  // Calcular ángulos de Euler desde cuaternión
  static SensorData fromQuaternion({
    required String nodeId,
    required int timestampMs,
    required double qw, required double qx,
    required double qy, required double qz,
    required double accelX, required double accelY, required double accelZ,
  }) {
    final roll  = math.atan2(2*(qw*qx + qy*qz), 1 - 2*(qx*qx + qy*qy)) * 180/math.pi;
    final sinp  = 2*(qw*qy - qz*qx);
    final pitch = (sinp.abs() >= 1) ? math.pi/2 * sinp.sign : math.asin(sinp) * 180/math.pi;
    final yaw   = math.atan2(2*(qw*qz + qx*qy), 1 - 2*(qy*qy + qz*qz)) * 180/math.pi;
    return SensorData(nodeId: nodeId, timestampMs: timestampMs,
        qw: qw, qx: qx, qy: qy, qz: qz,
        accelX: accelX, accelY: accelY, accelZ: accelZ,
        roll: roll, pitch: pitch, yaw: yaw);
  }
}

class RunningMetrics {
  final double cadenceStepsPerMin;      // pasos/minuto
  final double symmetryPercent;         // 0–100%, 50% = perfectamente simétrico
  final double avgContactTimeMs;        // tiempo de contacto suelo (ms)
  final double strikeAngleDeg;          // ángulo de pisada (grados)
  final double strideVariability;       // coeficiente de variación de zancada
  final int stepCount;

  // Recomendación automática (ver lógica en SessionProvider)
  final String? recommendation;
}
```

---

## BleManager — patrones críticos

### Escaneo por UUID de servicio (no por nombre)

```dart
// Buscar solo dispositivos del wearable por UUID del servicio GATT
FlutterBluePlus.startScan(
  withServices: [Guid('19B10000-E8F2-537E-4F6C-D104768A1214')],
  timeout: const Duration(seconds: 10),
);
```

### Conexión simultánea a 2 nodos

```dart
// Conectar los dos nodos en paralelo — NO secuencialmente
await Future.wait([
  _connectNode(leftAnkleDevice),
  _connectNode(rightAnkleDevice),
]);
```

### Subscripción a notificaciones BLE

```dart
Future<void> _subscribeToNotifications(BluetoothDevice device, String nodeId) async {
  final services = await device.discoverServices();
  for (final service in services) {
    if (service.uuid == Guid('19B10000-...')) {
      for (final char in service.characteristics) {
        if (char.uuid == Guid('19B10001-...') && char.properties.notify) {
          await char.setNotifyValue(true);
          char.lastValueStream.listen((bytes) {
            if (bytes.length >= 14) {
              final data = SensorParser.parse(bytes, nodeId);
              _onDataReceived(data);
            }
          });
        }
      }
    }
  }
}
```

### Reconexión automática

```dart
device.connectionState.listen((state) {
  if (state == BluetoothConnectionState.disconnected) {
    // Reintentar conexión con backoff exponencial
    Future.delayed(const Duration(seconds: 2), () => _connectNode(device));
  }
});
```

---

## SensorParser — decodificación del paquete BLE

El nodo envía paquetes de **14 bytes** en little-endian:

```
Bytes 0-1:   uint16  timestamp_ms   (relativo al inicio de sesión)
Bytes 2-3:   int16   qw × 10000
Bytes 4-5:   int16   qx × 10000
Bytes 6-7:   int16   qy × 10000
Bytes 8-9:   int16   qz × 10000
Bytes 10-11: int16   accel_x (mili-g)
Bytes 12-13: int16   accel_y (mili-g)
Bytes 14-15: int16   accel_z (mili-g)
```

```dart
// services/sensor_parser.dart
import 'dart:typed_data';

class SensorParser {
  static const double _quatScale = 1.0 / 10000.0;
  static const double _accelScale = 9.81 / 1000.0;  // mili-g → m/s²

  static SensorData parse(List<int> bytes, String nodeId) {
    final buf = ByteData.sublistView(Uint8List.fromList(bytes));

    final ts   = buf.getUint16(0, Endian.little);
    final qw   = buf.getInt16(2, Endian.little) * _quatScale;
    final qx   = buf.getInt16(4, Endian.little) * _quatScale;
    final qy   = buf.getInt16(6, Endian.little) * _quatScale;
    final qz   = buf.getInt16(8, Endian.little) * _quatScale;
    final ax   = buf.getInt16(10, Endian.little) * _accelScale;
    final ay   = buf.getInt16(12, Endian.little) * _accelScale;
    // Nota: si el paquete es de 14 bytes, az usa bytes 12-13
    // Si es de 16 bytes, az usa bytes 14-15
    final az   = bytes.length >= 16
        ? buf.getInt16(14, Endian.little) * _accelScale
        : 0.0;

    return SensorData.fromQuaternion(
      nodeId: nodeId, timestampMs: ts,
      qw: qw, qx: qx, qy: qy, qz: qz,
      accelX: ax, accelY: ay, accelZ: az,
    );
  }
}
```

---

## SessionProvider — lógica de métricas de running

```dart
// providers/session_provider.dart
class SessionProvider extends ChangeNotifier {
  final Map<String, List<SensorData>> _buffer = {
    'LEFT_ANKLE': [], 'RIGHT_ANKLE': [],
  };

  RunningMetrics? currentMetrics;
  List<SensorData> recentLeft  = [];
  List<SensorData> recentRight = [];

  void onDataReceived(SensorData data) {
    _buffer[data.nodeId]!.add(data);
    if (data.nodeId == 'LEFT_ANKLE')  recentLeft  = _buffer['LEFT_ANKLE']!.take(200).toList();
    if (data.nodeId == 'RIGHT_ANKLE') recentRight = _buffer['RIGHT_ANKLE']!.take(200).toList();

    // Recalcular métricas cada 50 muestras (≈0.5s a 100Hz)
    if (_buffer[data.nodeId]!.length % 50 == 0) {
      currentMetrics = _computeMetrics();
      notifyListeners();
    }
  }

  RunningMetrics _computeMetrics() {
    // Cadencia: contar impactos por segundo usando picos de aceleración vertical
    // Simetría: comparar tiempo de contacto L vs R
    // Ver references/ble_packet_format.md para algoritmos detallados
    ...
  }

  // Generador de recomendaciones
  String? _generateRecommendation(RunningMetrics m) {
    if (m.symmetryPercent < 45 || m.symmetryPercent > 55)
      return 'Asimetría detectada: el pie ${m.symmetryPercent < 50 ? "derecho" : "izquierdo"} carga más. Intenta equilibrar tu zancada.';
    if (m.cadenceStepsPerMin < 160)
      return 'Cadencia baja (${m.cadenceStepsPerMin.toStringAsFixed(0)} spm). Aumenta la frecuencia de pasos para reducir impacto.';
    if (m.strikeAngleDeg > 15)
      return 'Aterrizaje con talón pronunciado. Intenta aterrizar con el pie más debajo de la cadera.';
    return null;
  }
}
```

---

## Widgets de UI — patrones a seguir

### Dashboard en tiempo real (RunningScreen)
- Usar `Consumer<SessionProvider>` para escuchar cambios
- Métricas principales en `Card` widgets grandes y legibles
- Gráfica de cadencia con `fl_chart` (LineChart, últimos 30 segundos)
- Indicador de simetría L/R con barra de progreso bicolor
- Recomendación en `SnackBar` o banner destacado cuando aparece

### Pantalla de escaneo (ScanScreen)
- `StreamBuilder` sobre `FlutterBluePlus.scanResults`
- Lista de dispositivos filtrada por UUID de servicio
- Indicador de señal (RSSI) por dispositivo
- Botón de conexión simultánea cuando se seleccionan 2 nodos
- Estado de conexión por nodo (Conectando… / Conectado ✓ / Error)

### Colores y estilo (para la demo de inversores)
```dart
// Usar tema oscuro deportivo
ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF00E5FF),   // cyan neón
  scaffoldBackgroundColor: const Color(0xFF0A0A0A),
  cardColor: const Color(0xFF1A1A2E),
)
```

---

## Formato del output

Cuando generes código Flutter:

1. **Crea cada archivo Dart por separado** en la carpeta del proyecto
2. **Comenta en inglés** las clases, métodos y bloques lógicos complejos
3. **Al terminar**, muestra:
   - Lista de archivos creados con sus rutas
   - Dependencias a agregar en `pubspec.yaml`
   - Permisos Android/iOS necesarios (Bluetooth, Location)
   - Próximos pasos sugeridos

### Dependencias requeridas (siempre menciónalas)
```yaml
dependencies:
  flutter_blue_plus: ^1.32.0
  provider: ^6.1.2
  fl_chart: ^0.68.0
  permission_handler: ^11.3.1
```

### Permisos Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### Permisos iOS (Info.plist)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Needed to connect to sport sensor nodes</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Needed to connect to sport sensor nodes</string>
```
