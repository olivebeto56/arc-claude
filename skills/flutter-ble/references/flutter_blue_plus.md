# flutter_blue_plus — Referencia técnica para el wearable

## Versión y compatibilidad
- Versión: `^1.32.0` (latest estable 2025)
- Android: mínimo SDK 21, target SDK 34+
- iOS: mínimo iOS 13
- **No compatible con Web ni Desktop** — solo mobile

## Setup inicial

### pubspec.yaml
```yaml
dependencies:
  flutter_blue_plus: ^1.32.0
  permission_handler: ^11.3.1  # requerido para solicitar permisos en runtime
```

### Android — AndroidManifest.xml
```xml
<!-- Para Android 12+ (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<!-- Para Android 11 y menores (legacy) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS — Info.plist
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Needed to connect to sport sensor wearable nodes</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Needed to connect to sport sensor wearable nodes</string>
```

### Solicitar permisos en runtime (antes de escanear)
```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestBlePermissions() async {
  if (Platform.isAndroid) {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return results.values.every((s) => s.isGranted);
  } else if (Platform.isIOS) {
    // iOS pide el permiso automáticamente al primer uso de BLE
    return true;
  }
  return false;
}
```

---

## API principal de escaneo

### Escanear por UUID de servicio (RECOMENDADO para el wearable)
```dart
// Solo descubre dispositivos que anuncian el UUID del servicio del wearable
// Mucho más eficiente que escanear todos y filtrar por nombre
FlutterBluePlus.startScan(
  withServices: [Guid('19B10000-E8F2-537E-4F6C-D104768A1214')],
  timeout: const Duration(seconds: 10),
);

// Escuchar resultados
final subscription = FlutterBluePlus.scanResults.listen((results) {
  for (final result in results) {
    print('Found: ${result.device.advName} RSSI: ${result.rssi}');
    // result.device es un BluetoothDevice
    // result.rssi es la intensidad de señal (-40 muy cerca, -90 lejos)
  }
});

// Detener escaneo
await FlutterBluePlus.stopScan();
subscription.cancel();
```

### Verificar si está escaneando
```dart
FlutterBluePlus.isScanning.listen((isScanning) {
  // true mientras escanea, false cuando terminó o fue detenido
});
```

---

## API de conexión

### Conectar un dispositivo
```dart
final device = BluetoothDevice.fromId('XX:XX:XX:XX:XX:XX');
// o usar el device del scan result directamente

try {
  await device.connect(timeout: const Duration(seconds: 10));
} on FlutterBluePlusException catch (e) {
  print('Connection error: ${e.errorCode} ${e.description}');
}
```

### Conectar 2 nodos en PARALELO (crítico para el wearable)
```dart
// CORRECTO — conectar simultáneamente
await Future.wait([
  leftAnkleDevice.connect(timeout: const Duration(seconds: 10)),
  rightAnkleDevice.connect(timeout: const Duration(seconds: 10)),
]);

// INCORRECTO — conectar secuencialmente (duplica el tiempo de setup)
// await leftAnkleDevice.connect();
// await rightAnkleDevice.connect();
```

### Escuchar estado de conexión
```dart
device.connectionState.listen((BluetoothConnectionState state) {
  switch (state) {
    case BluetoothConnectionState.connected:
      print('${device.advName} connected');
      _discoverServices(device);
      break;
    case BluetoothConnectionState.disconnected:
      print('${device.advName} disconnected');
      _scheduleReconnect(device);
      break;
    default:
      break;
  }
});
```

### Desconectar
```dart
await device.disconnect();
```

---

## Descubrimiento de servicios y características

```dart
Future<void> _discoverServices(BluetoothDevice device) async {
  final services = await device.discoverServices();

  for (final service in services) {
    // Buscar el servicio del wearable por UUID
    if (service.uuid.toString().toUpperCase() ==
        '19B10000-E8F2-537E-4F6C-D104768A1214') {

      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toUpperCase();

        // Characteristic de datos del sensor — subscribe a notificaciones
        if (uuid == '19B10001-E8F2-537E-4F6C-D104768A1214') {
          if (char.properties.notify) {
            await char.setNotifyValue(true);
            char.lastValueStream.listen(_handleSensorData);
          }
        }

        // Characteristic de batería — leer una vez
        if (uuid == '19B10002-E8F2-537E-4F6C-D104768A1214') {
          final batteryBytes = await char.read();
          final batteryPct = batteryBytes.isNotEmpty ? batteryBytes[0] : 0;
          print('Battery: $batteryPct%');
        }

        // Characteristic de configuración — escribir para cambiar frecuencia
        if (uuid == '19B10003-E8F2-537E-4F6C-D104768A1214') {
          if (char.properties.write) {
            // Escribir 0x01 = 100Hz, 0x02 = 25Hz
            await char.write([0x01]);
          }
        }
      }
    }
  }
}
```

---

## Recibir notificaciones (flujo de datos del sensor)

```dart
void _handleSensorData(List<int> bytes) {
  if (bytes.length < 14) return;  // paquete incompleto, ignorar
  final data = SensorParser.parse(bytes, nodeId);
  sessionProvider.onDataReceived(data);
}
```

**Nota de rendimiento:** `lastValueStream` emite en el thread de la UI. Para 100 Hz de dos nodos (200 eventos/seg), considera mover el parsing a un `Isolate` en Sprint 3+ si hay jank en la UI.

---

## Verificar estado de Bluetooth del sistema

```dart
// Verificar si el Bluetooth del teléfono está encendido
FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
  if (state == BluetoothAdapterState.on) {
    // Listo para escanear
  } else if (state == BluetoothAdapterState.off) {
    // Mostrar diálogo pidiendo al usuario que active BT
  }
});

// Snapshot actual (sin stream)
final isOn = await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
```

---

## Errores comunes y soluciones

| Error | Causa | Solución |
|---|---|---|
| `scan failed: error 1` | Permisos BLE no otorgados | Llamar `requestBlePermissions()` antes de `startScan()` |
| `connection failed: timeout` | Dispositivo fuera de rango o no está advertising | Verificar que el nodo está encendido y en modo advertising |
| `service discovery failed` | Dispositivo desconectado antes de `discoverServices()` | Verificar `connectionState == connected` antes de llamar |
| `setNotifyValue failed` | La característica no tiene propiedad `notify` | Verificar `char.properties.notify` antes de suscribir |
| Notificaciones dejan de llegar | El sistema iOS suspendió la app | Usar `device.connectionState` para detectar desconexión y reconectar |
| `MTU negotiation failed` | Android, algunos dispositivos | Llamar `device.requestMtu(23)` después de conectar |

---

## Patrón recomendado para BleManager completo

```dart
class BleManager extends ChangeNotifier {
  final Map<String, BluetoothDevice> _connectedNodes = {};
  final Map<String, StreamSubscription> _dataSubscriptions = {};
  final Map<String, StreamSubscription> _stateSubscriptions = {};

  bool get bothNodesConnected =>
      _connectedNodes.containsKey('LEFT_ANKLE') &&
      _connectedNodes.containsKey('RIGHT_ANKLE');

  String nodeIdFromDeviceName(String name) =>
      name.contains('-L') ? 'LEFT_ANKLE' : 'RIGHT_ANKLE';

  Future<void> connectNodes(List<BluetoothDevice> devices) async {
    await Future.wait(devices.map(_connectSingle));
  }

  Future<void> _connectSingle(BluetoothDevice device) async {
    final nodeId = nodeIdFromDeviceName(device.advName);
    await device.connect(timeout: const Duration(seconds: 10));
    _connectedNodes[nodeId] = device;

    _stateSubscriptions[nodeId] = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _connectedNodes.remove(nodeId);
        notifyListeners();
        Future.delayed(const Duration(seconds: 3), () => _connectSingle(device));
      }
    });

    await _discoverAndSubscribe(device, nodeId);
    notifyListeners();
  }

  void dispose() {
    for (final sub in _dataSubscriptions.values) sub.cancel();
    for (final sub in _stateSubscriptions.values) sub.cancel();
    super.dispose();
  }
}
```
