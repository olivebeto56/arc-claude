import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// UUID of the wearable IMU service to filter during BLE scan.
const String kWearableServiceUuid = '19b10000-e8f2-537e-4f6c-d104768a1214';

/// Represents a discovered BLE device along with its latest RSSI value.
class DiscoveredNode {
  final BluetoothDevice device;
  int rssi;

  DiscoveredNode({required this.device, required this.rssi});

  String get id => device.remoteId.str;
  String get name =>
      device.platformName.isNotEmpty ? device.platformName : '(sin nombre)';
}

/// Possible states for a multi-node connection attempt.
enum ConnectionStatus { idle, connecting, connected, error }

class BleProvider extends ChangeNotifier {
  // ── Scan state ────────────────────────────────────────────────────────────
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final Map<String, DiscoveredNode> _nodes = {};
  List<DiscoveredNode> get nodes => _nodes.values.toList();

  final Set<String> _selectedIds = {};
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  // ── Connection state ──────────────────────────────────────────────────────
  ConnectionStatus _connectionStatus = ConnectionStatus.idle;
  ConnectionStatus get connectionStatus => _connectionStatus;

  String? _connectionError;
  String? get connectionError => _connectionError;

  /// Devices that were successfully connected in the last [connectSelected] call.
  final List<BluetoothDevice> _connectedDevices = [];
  List<BluetoothDevice> get connectedDevices =>
      List.unmodifiable(_connectedDevices);

  // ── Scan ──────────────────────────────────────────────────────────────────

  /// Start a BLE scan filtered to [kWearableServiceUuid].
  Future<void> startScan() async {
    if (_isScanning) return;

    _nodes.clear();
    _selectedIds.clear();
    _connectionStatus = ConnectionStatus.idle;
    _connectionError = null;
    _connectedDevices.clear();
    notifyListeners();

    // Listen to the global scanning flag so the UI reflects FlutterBluePlus's
    // internal state (e.g. Android auto-stops after a timeout).
    _isScanningSubscription?.cancel();
    _isScanningSubscription =
        FlutterBluePlus.isScanning.listen((scanning) {
      _isScanning = scanning;
      notifyListeners();
    });

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final id = result.device.remoteId.str;
        _nodes[id] = DiscoveredNode(
          device: result.device,
          rssi: result.rssi,
        );
      }
      notifyListeners();
    });

    await FlutterBluePlus.startScan(
      withServices: [Guid(kWearableServiceUuid)],
      timeout: const Duration(seconds: 15),
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanningSubscription?.cancel();
    _isScanningSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  /// Toggle selection of a node. At most two nodes may be selected at a time.
  void toggleSelection(String deviceId) {
    if (_selectedIds.contains(deviceId)) {
      _selectedIds.remove(deviceId);
    } else {
      if (_selectedIds.length < 2) {
        _selectedIds.add(deviceId);
      }
    }
    notifyListeners();
  }

  bool isSelected(String deviceId) => _selectedIds.contains(deviceId);

  // ── Connection ────────────────────────────────────────────────────────────

  /// Connect to the two selected nodes in parallel using [Future.wait].
  Future<void> connectSelected() async {
    if (_selectedIds.length != 2) return;
    if (_connectionStatus == ConnectionStatus.connecting) return;

    _connectionStatus = ConnectionStatus.connecting;
    _connectionError = null;
    _connectedDevices.clear();
    notifyListeners();

    final devicesToConnect = _selectedIds
        .map((id) => _nodes[id]!.device)
        .toList();

    try {
      // Connect both nodes simultaneously.
      await Future.wait(
        devicesToConnect.map(
          (device) => device.connect(
            autoConnect: false,
            timeout: const Duration(seconds: 10),
          ),
        ),
      );

      _connectedDevices.addAll(devicesToConnect);
      _connectionStatus = ConnectionStatus.connected;
    } catch (e) {
      _connectionStatus = ConnectionStatus.error;
      _connectionError = e.toString();
    }

    notifyListeners();
  }

  /// Disconnect all currently connected devices.
  Future<void> disconnectAll() async {
    await Future.wait(
      _connectedDevices.map((d) => d.disconnect()),
    );
    _connectedDevices.clear();
    _connectionStatus = ConnectionStatus.idle;
    notifyListeners();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }
}
