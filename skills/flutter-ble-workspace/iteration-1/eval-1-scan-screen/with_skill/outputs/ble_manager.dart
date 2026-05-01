// services/ble_manager.dart
// Manages BLE scanning, multi-node connection, and data subscriptions
// for the wearable sport monitor app.

import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

/// Unique UUID for the wearable sensor service (GATT service advertisement)
const String kWearableServiceUuid = '19B10000-E8F2-537E-4F6C-D104768A1214';

/// Node ID assignment — device name must contain '-L' for left ankle,
/// otherwise treated as right ankle.
String nodeIdFromDeviceName(String name) =>
    name.toUpperCase().contains('-L') ? 'LEFT_ANKLE' : 'RIGHT_ANKLE';

/// Connection state for a single BLE node.
enum NodeConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Holds live state for a discovered or connected node.
class NodeState {
  final BluetoothDevice device;
  final int rssi;
  final NodeConnectionState connectionState;
  final String? errorMessage;

  const NodeState({
    required this.device,
    required this.rssi,
    this.connectionState = NodeConnectionState.disconnected,
    this.errorMessage,
  });

  NodeState copyWith({
    BluetoothDevice? device,
    int? rssi,
    NodeConnectionState? connectionState,
    String? errorMessage,
  }) {
    return NodeState(
      device: device ?? this.device,
      rssi: rssi ?? this.rssi,
      connectionState: connectionState ?? this.connectionState,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get nodeId => nodeIdFromDeviceName(device.advName);

  String get displayName =>
      device.advName.isNotEmpty ? device.advName : device.remoteId.str;
}

/// BleManager — ChangeNotifier that owns all BLE logic:
///   - Permission requests
///   - Scanning filtered by service UUID
///   - Parallel dual-node connection
///   - Auto-reconnect on disconnection
class BleManager extends ChangeNotifier {
  // ── Scan state ────────────────────────────────────────────────────────────
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  /// All nodes discovered in the current or last scan, keyed by device ID.
  final Map<String, NodeState> _discoveredNodes = {};
  List<NodeState> get discoveredNodes => _discoveredNodes.values.toList();

  // ── Selection state ───────────────────────────────────────────────────────
  /// Up to 2 devices selected by the user for connection.
  final Set<String> _selectedDeviceIds = {};
  Set<String> get selectedDeviceIds => Set.unmodifiable(_selectedDeviceIds);

  bool get canConnect => _selectedDeviceIds.length == 2;

  // ── Connection state ──────────────────────────────────────────────────────
  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool get bothNodesConnected {
    return _discoveredNodes.values
        .where((n) => n.connectionState == NodeConnectionState.connected)
        .length >= 2;
  }

  // ── Internal subscriptions ────────────────────────────────────────────────
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  final Map<String, StreamSubscription<BluetoothConnectionState>>
      _connectionSubscriptions = {};

  // ── Permissions ───────────────────────────────────────────────────────────

  /// Request runtime BLE permissions required on Android 12+ / iOS.
  /// Returns true if all needed permissions are granted.
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final results = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      return results.values.every((s) => s.isGranted);
    }
    // iOS requests BLE permission automatically on first use.
    return true;
  }

  // ── Scanning ──────────────────────────────────────────────────────────────

  /// Start scanning for wearable nodes filtered by the service UUID.
  /// Results are merged into [discoveredNodes] as they arrive.
  Future<void> startScan() async {
    final granted = await requestPermissions();
    if (!granted) return;

    // Listen to isScanning stream to keep local flag in sync
    _isScanningSubscription?.cancel();
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      _isScanning = scanning;
      notifyListeners();
    });

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final id = result.device.remoteId.str;
        final existing = _discoveredNodes[id];
        if (existing != null) {
          // Update RSSI only; keep connection state
          _discoveredNodes[id] = existing.copyWith(rssi: result.rssi);
        } else {
          _discoveredNodes[id] = NodeState(
            device: result.device,
            rssi: result.rssi,
          );
        }
      }
      notifyListeners();
    });

    // Scan only for devices advertising the wearable service UUID
    await FlutterBluePlus.startScan(
      withServices: [Guid(kWearableServiceUuid)],
      timeout: const Duration(seconds: 10),
    );
  }

  /// Stop an ongoing scan.
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  /// Toggle selection of a node. At most 2 nodes may be selected at once.
  void toggleSelection(String deviceId) {
    if (_selectedDeviceIds.contains(deviceId)) {
      _selectedDeviceIds.remove(deviceId);
    } else {
      if (_selectedDeviceIds.length < 2) {
        _selectedDeviceIds.add(deviceId);
      }
    }
    notifyListeners();
  }

  // ── Connection ────────────────────────────────────────────────────────────

  /// Connect to the two selected nodes in parallel.
  Future<void> connectSelectedNodes() async {
    if (!canConnect) return;

    await stopScan();
    _isConnecting = true;
    notifyListeners();

    final devices = _selectedDeviceIds
        .map((id) => _discoveredNodes[id]?.device)
        .whereType<BluetoothDevice>()
        .toList();

    // Mark both as "connecting" before awaiting
    for (final device in devices) {
      final id = device.remoteId.str;
      _discoveredNodes[id] = _discoveredNodes[id]!
          .copyWith(connectionState: NodeConnectionState.connecting);
    }
    notifyListeners();

    // Connect both nodes in parallel — critical for low latency setup
    await Future.wait(devices.map(_connectSingle));

    _isConnecting = false;
    notifyListeners();
  }

  /// Connect a single node, subscribe to its connection state, and set up
  /// auto-reconnect on unexpected disconnection.
  Future<void> _connectSingle(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      _discoveredNodes[deviceId] = _discoveredNodes[deviceId]!
          .copyWith(connectionState: NodeConnectionState.connected);
      notifyListeners();

      // Subscribe to connection state for auto-reconnect
      _connectionSubscriptions[deviceId]?.cancel();
      _connectionSubscriptions[deviceId] =
          device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _discoveredNodes[deviceId] = _discoveredNodes[deviceId]!
              .copyWith(connectionState: NodeConnectionState.disconnected);
          notifyListeners();

          // Exponential backoff reconnect (simple 3-second delay for Sprint 1)
          Future.delayed(const Duration(seconds: 3), () {
            if (_discoveredNodes.containsKey(deviceId)) {
              _connectSingle(device);
            }
          });
        }
      });
    } on FlutterBluePlusException catch (e) {
      _discoveredNodes[deviceId] = _discoveredNodes[deviceId]!.copyWith(
        connectionState: NodeConnectionState.error,
        errorMessage: e.description,
      );
      notifyListeners();
    } catch (e) {
      _discoveredNodes[deviceId] = _discoveredNodes[deviceId]!.copyWith(
        connectionState: NodeConnectionState.error,
        errorMessage: e.toString(),
      );
      notifyListeners();
    }
  }

  // ── Disposal ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    stopScan();
    for (final sub in _connectionSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
