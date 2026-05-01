import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import 'ble_provider.dart';

/// Full BLE scan screen.
///
/// - Starts a scan filtered by [kWearableServiceUuid].
/// - Displays every discovered node with its name and live RSSI.
/// - Allows the user to select up to two nodes.
/// - Connects both selected nodes in parallel via [BleProvider.connectSelected].
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off the scan as soon as the screen is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleProvider>().startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar nodos BLE'),
        actions: [_ScanToggleButton()],
      ),
      body: Column(
        children: [
          _StatusBanner(),
          Expanded(child: _NodeList()),
          _ConnectBar(),
        ],
      ),
    );
  }
}

// ─── Scan toggle (AppBar action) ─────────────────────────────────────────────

class _ScanToggleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BleProvider>();

    if (provider.isScanning) {
      return IconButton(
        tooltip: 'Detener escaneo',
        icon: const Icon(Icons.stop_circle_outlined),
        onPressed: () => provider.stopScan(),
      );
    }

    return IconButton(
      tooltip: 'Iniciar escaneo',
      icon: const Icon(Icons.search),
      onPressed: () => provider.startScan(),
    );
  }
}

// ─── Status banner ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BleProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // Scanning indicator
    if (provider.isScanning) {
      return _Banner(
        color: colorScheme.primaryContainer,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Escaneando… (UUID: ${kWearableServiceUuid.substring(0, 8)}…)',
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
          ],
        ),
      );
    }

    // Connection error
    if (provider.connectionStatus == ConnectionStatus.error) {
      return _Banner(
        color: colorScheme.errorContainer,
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Error al conectar: ${provider.connectionError}',
                style: TextStyle(color: colorScheme.onErrorContainer),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Connected
    if (provider.connectionStatus == ConnectionStatus.connected) {
      return _Banner(
        color: Colors.green.shade100,
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              '${provider.connectedDevices.length} nodo(s) conectados',
              style: const TextStyle(color: Colors.green),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.read<BleProvider>().disconnectAll(),
              child: const Text('Desconectar'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: child,
    );
  }
}

// ─── Node list ────────────────────────────────────────────────────────────────

class _NodeList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BleProvider>();
    final nodes = provider.nodes;

    if (nodes.isEmpty) {
      return Center(
        child: Text(
          provider.isScanning
              ? 'Buscando nodos…'
              : 'No se encontraron nodos.\nPulsa  para escanear.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: nodes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final node = nodes[index];
        return _NodeTile(node: node);
      },
    );
  }
}

// ─── Single node tile ─────────────────────────────────────────────────────────

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node});

  final DiscoveredNode node;

  /// Maps RSSI to a signal strength icon (4 levels).
  IconData _rssiIcon(int rssi) {
    if (rssi >= -55) return Icons.signal_wifi_4_bar;
    if (rssi >= -70) return Icons.network_wifi_3_bar;
    if (rssi >= -80) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -55) return Colors.green;
    if (rssi >= -70) return Colors.lightGreen;
    if (rssi >= -80) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BleProvider>();
    final selected = provider.isSelected(node.id);
    final selectionFull =
        provider.selectedIds.length >= 2 && !selected;

    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      tileColor: selected ? colorScheme.secondaryContainer : null,
      leading: CircleAvatar(
        backgroundColor:
            selected ? colorScheme.secondary : colorScheme.surfaceVariant,
        child: Icon(
          Icons.bluetooth,
          color: selected
              ? colorScheme.onSecondary
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        node.name,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        node.id,
        style: Theme.of(context).textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // RSSI badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _rssiColor(node.rssi).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _rssiIcon(node.rssi),
                  size: 16,
                  color: _rssiColor(node.rssi),
                ),
                const SizedBox(width: 4),
                Text(
                  '${node.rssi} dBm',
                  style: TextStyle(
                    fontSize: 12,
                    color: _rssiColor(node.rssi),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Selection checkbox
          Checkbox(
            value: selected,
            onChanged: selectionFull
                ? null // disable when two others are already selected
                : (_) => provider.toggleSelection(node.id),
          ),
        ],
      ),
      onTap: selectionFull
          ? null
          : () => provider.toggleSelection(node.id),
    );
  }
}

// ─── Connect bar (bottom) ────────────────────────────────────────────────────

class _ConnectBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BleProvider>();
    final selectedCount = provider.selectedIds.length;
    final isConnecting =
        provider.connectionStatus == ConnectionStatus.connecting;
    final isConnected =
        provider.connectionStatus == ConnectionStatus.connected;

    final canConnect = selectedCount == 2 && !isConnecting && !isConnected;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selection hint
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _selectionHint(selectedCount, isConnected),
                key: ValueKey('$selectedCount-$isConnected'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            // Connect button
            FilledButton.icon(
              onPressed: canConnect
                  ? () => provider.connectSelected()
                  : null,
              icon: isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isConnected
                          ? Icons.check_circle
                          : Icons.bluetooth_connected,
                    ),
              label: Text(
                isConnecting
                    ? 'Conectando…'
                    : isConnected
                        ? 'Conectados'
                        : 'Conectar $selectedCount/2 nodos',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _selectionHint(int count, bool connected) {
    if (connected) return 'Ambos nodos conectados y listos.';
    if (count == 0) return 'Selecciona 2 nodos para conectar.';
    if (count == 1) return 'Selecciona 1 nodo más.';
    return 'Listo para conectar ambos nodos en paralelo.';
  }
}
