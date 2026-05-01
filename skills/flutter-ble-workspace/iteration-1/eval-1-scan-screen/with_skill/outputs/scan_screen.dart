// screens/scan_screen.dart
// BLE scan screen for the wearable sport monitor app.
//
// Displays a filtered list of wearable nodes (by service UUID), shows RSSI
// signal strength per node, and allows the user to select exactly 2 nodes
// and connect them in parallel.
//
// State is managed via BleManager (ChangeNotifier) accessed through Provider.

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../services/ble_manager.dart';

/// ScanScreen — entry point for discovering and connecting wearable nodes.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    // Start scanning automatically when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleManager>().startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          'Buscar nodos',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          // Bluetooth adapter state indicator
          _BluetoothStateIndicator(),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<BleManager>(
        builder: (context, ble, _) {
          return Column(
            children: [
              // ── Scan status bar ──────────────────────────────────────────
              _ScanStatusBar(ble: ble),

              // ── Node list ────────────────────────────────────────────────
              Expanded(
                child: ble.discoveredNodes.isEmpty
                    ? _EmptyState(isScanning: ble.isScanning)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: ble.discoveredNodes.length,
                        itemBuilder: (context, index) {
                          final node = ble.discoveredNodes[index];
                          final isSelected = ble.selectedDeviceIds
                              .contains(node.device.remoteId.str);
                          return _NodeCard(
                            node: node,
                            isSelected: isSelected,
                            onTap: () => ble
                                .toggleSelection(node.device.remoteId.str),
                          );
                        },
                      ),
              ),

              // ── Selection hint ───────────────────────────────────────────
              _SelectionHint(selectedCount: ble.selectedDeviceIds.length),

              // ── Connect button ───────────────────────────────────────────
              _ConnectButton(ble: ble),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────────────────────

/// Animated scanning status bar with scan/stop toggle.
class _ScanStatusBar extends StatelessWidget {
  final BleManager ble;

  const _ScanStatusBar({required this.ble});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Animated pulsing dot while scanning
          if (ble.isScanning)
            _PulsingDot()
          else
            const Icon(Icons.circle, size: 10, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ble.isScanning
                  ? 'Escaneando nodos wearable…'
                  : 'Escaneo completado — ${ble.discoveredNodes.length} nodo(s) encontrado(s)',
              style: TextStyle(
                color: ble.isScanning
                    ? const Color(0xFF00E5FF)
                    : Colors.grey[400],
                fontSize: 13,
              ),
            ),
          ),
          // Scan / Stop toggle button
          TextButton.icon(
            onPressed: ble.isConnecting
                ? null
                : (ble.isScanning ? ble.stopScan : ble.startScan),
            icon: Icon(
              ble.isScanning ? Icons.stop_circle_outlined : Icons.search,
              size: 18,
              color: const Color(0xFF00E5FF),
            ),
            label: Text(
              ble.isScanning ? 'Detener' : 'Escanear',
              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated pulsing circle indicating active scan.
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: const Icon(Icons.circle, size: 10, color: Color(0xFF00E5FF)),
    );
  }
}

/// Card showing one discovered node with RSSI, name, and connection state.
class _NodeCard extends StatelessWidget {
  final NodeState node;
  final bool isSelected;
  final VoidCallback onTap;

  const _NodeCard({
    required this.node,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected =
        node.connectionState == NodeConnectionState.connected;
    final isConnecting =
        node.connectionState == NodeConnectionState.connecting;
    final hasError = node.connectionState == NodeConnectionState.error;

    return GestureDetector(
      onTap: (isConnected || isConnecting) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isConnected
                ? Colors.greenAccent
                : isSelected
                    ? const Color(0xFF00E5FF)
                    : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection checkbox / status icon
              _NodeStatusIcon(
                isSelected: isSelected,
                isConnected: isConnected,
                isConnecting: isConnecting,
                hasError: hasError,
              ),
              const SizedBox(width: 14),

              // Node name and device ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      node.device.remoteId.str,
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    if (hasError && node.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Error: ${node.errorMessage}',
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 11),
                        ),
                      ),
                    if (isConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Conectado — ${node.nodeId.replaceAll('_', ' ')}',
                          style: const TextStyle(
                              color: Colors.greenAccent, fontSize: 12),
                        ),
                      ),
                    if (isConnecting)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Conectando…',
                          style: TextStyle(
                              color: Color(0xFF00E5FF), fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),

              // RSSI signal strength indicator
              _RssiIndicator(rssi: node.rssi),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon that reflects the selection and connection state of a node.
class _NodeStatusIcon extends StatelessWidget {
  final bool isSelected;
  final bool isConnected;
  final bool isConnecting;
  final bool hasError;

  const _NodeStatusIcon({
    required this.isSelected,
    required this.isConnected,
    required this.isConnecting,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    if (isConnected) {
      return const Icon(Icons.check_circle, color: Colors.greenAccent, size: 26);
    }
    if (isConnecting) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor:
              AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
        ),
      );
    }
    if (hasError) {
      return const Icon(Icons.error_outline, color: Colors.redAccent, size: 26);
    }
    return Icon(
      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
      color: isSelected ? const Color(0xFF00E5FF) : Colors.grey,
      size: 26,
    );
  }
}

/// Visual RSSI signal-strength bars (similar to WiFi icon bars).
class _RssiIndicator extends StatelessWidget {
  final int rssi;

  const _RssiIndicator({required this.rssi});

  /// Maps RSSI (dBm) to 1–4 bars.
  /// -40 dBm or better → 4 bars; worse than -80 dBm → 1 bar.
  int get _bars {
    if (rssi >= -50) return 4;
    if (rssi >= -65) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  Color get _color {
    if (rssi >= -65) return const Color(0xFF00E5FF);
    if (rssi >= -80) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Bar chart graphic
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final active = (i + 1) <= _bars;
            return Container(
              width: 5,
              height: 6.0 + i * 4.0,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: active ? _color : Colors.grey[800],
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          '$rssi dBm',
          style: TextStyle(color: Colors.grey[500], fontSize: 10),
        ),
      ],
    );
  }
}

/// Hint text displayed below the list to guide the user.
class _SelectionHint extends StatelessWidget {
  final int selectedCount;

  const _SelectionHint({required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;

    if (selectedCount == 0) {
      text = 'Selecciona 2 nodos para conectar';
      color = Colors.grey;
    } else if (selectedCount == 1) {
      text = 'Selecciona 1 nodo más';
      color = const Color(0xFF00E5FF);
    } else {
      text = '2 nodos seleccionados — listo para conectar';
      color = Colors.greenAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 13),
      ),
    );
  }
}

/// Primary connect button — enabled only when 2 nodes are selected and
/// not already connecting.
class _ConnectButton extends StatelessWidget {
  final BleManager ble;

  const _ConnectButton({required this.ble});

  @override
  Widget build(BuildContext context) {
    final bool enabled = ble.canConnect && !ble.isConnecting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: enabled
              ? () async {
                  await ble.connectSelectedNodes();
                  // Navigate to running screen once both nodes are connected
                  if (ble.bothNodesConnected && context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/running');
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled
                ? const Color(0xFF00E5FF)
                : const Color(0xFF1A1A2E),
            foregroundColor:
                enabled ? const Color(0xFF0A0A0A) : Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: enabled ? 8 : 0,
            shadowColor:
                const Color(0xFF00E5FF).withOpacity(0.4),
          ),
          child: ble.isConnecting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF0A0A0A)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Conectando nodos…',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                )
              : const Text(
                  'Conectar 2 nodos',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5),
                ),
        ),
      ),
    );
  }
}

/// Empty-state widget shown while no nodes have been discovered.
class _EmptyState extends StatelessWidget {
  final bool isScanning;

  const _EmptyState({required this.isScanning});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
            size: 72,
            color: const Color(0xFF00E5FF).withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            isScanning
                ? 'Buscando nodos wearable…'
                : 'No se encontraron nodos.\nAsegúrate de que los nodos están encendidos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Bluetooth adapter state icon shown in the AppBar.
class _BluetoothStateIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BluetoothAdapterState>(
      stream: FlutterBluePlus.adapterState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? BluetoothAdapterState.unknown;
        final isOn = state == BluetoothAdapterState.on;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(
            isOn ? Icons.bluetooth : Icons.bluetooth_disabled,
            color: isOn ? const Color(0xFF00E5FF) : Colors.redAccent,
            size: 22,
          ),
        );
      },
    );
  }
}
