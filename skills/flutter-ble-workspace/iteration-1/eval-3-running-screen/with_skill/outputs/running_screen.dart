// running_screen.dart
// Real-time running dashboard screen for the wearable sport monitor app.
// Displays cadence, L/R symmetry bar, average ground contact time,
// a 30-second cadence chart (fl_chart), and a recommendation banner.

import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import 'widgets/cadence_chart.dart';
import 'widgets/metric_card.dart';
import 'widgets/recommendation_banner.dart';
import 'widgets/symmetry_bar.dart';

/// Dark sport theme colors used throughout the running screen.
class SportColors {
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceVariant = Color(0xFF16213E);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color green = Color(0xFF00E676);
  static const Color orange = Color(0xFFFF9100);
  static const Color red = Color(0xFFFF1744);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color divider = Color(0xFF1E1E1E);

  SportColors._();
}

/// Main running screen — subscribes to [SessionProvider] and renders
/// the full real-time biomechanics dashboard.
class RunningScreen extends StatefulWidget {
  const RunningScreen({super.key});

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  /// Rolling window of cadence data points for the 30-second chart.
  /// Each [FlSpot] has x = elapsed seconds (relative, 0-30) and y = spm.
  final Queue<FlSpot> _cadenceHistory = Queue();

  /// Elapsed seconds counter — incremented each time a new cadence value
  /// arrives from the provider.
  double _elapsedSeconds = 0;

  /// The most recent recommendation text; cached so we can dismiss it.
  String? _lastRecommendation;

  /// Whether the current recommendation banner is visible.
  bool _bannerVisible = false;

  static const double _windowSeconds = 30.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportColors.background,
      appBar: _buildAppBar(),
      body: Consumer<SessionProvider>(
        builder: (context, session, _) {
          _handleMetricsUpdate(session);
          final metrics = session.currentMetrics;

          return Stack(
            children: [
              // ── Main scrollable dashboard ──────────────────────────────
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Recommendation banner (slides in when a new tip arrives)
                    if (_bannerVisible && _lastRecommendation != null)
                      RecommendationBanner(
                        message: _lastRecommendation!,
                        onDismiss: _dismissBanner,
                      ),

                    const SizedBox(height: 12),

                    // ── Top row: cadence + contact time ───────────────
                    Row(
                      children: [
                        // Cadence metric (primary — larger card)
                        Expanded(
                          flex: 3,
                          child: MetricCard(
                            label: 'CADENCIA',
                            value: metrics != null
                                ? metrics.cadenceStepsPerMin
                                    .toStringAsFixed(0)
                                : '--',
                            unit: 'spm',
                            highlight: true,
                            color: _cadenceColor(
                                metrics?.cadenceStepsPerMin ?? 0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Ground contact time
                        Expanded(
                          flex: 2,
                          child: MetricCard(
                            label: 'CONTACTO',
                            value: metrics != null
                                ? metrics.avgContactTimeMs.toStringAsFixed(0)
                                : '--',
                            unit: 'ms',
                            highlight: false,
                            color: SportColors.cyan,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Symmetry bar ───────────────────────────────────
                    _SymmetrySection(
                      symmetryPct: metrics?.symmetryPercent ?? 50.0,
                      hasData: metrics != null,
                    ),

                    const SizedBox(height: 16),

                    // ── 30-second cadence chart ────────────────────────
                    _ChartSection(cadenceHistory: _cadenceHistory.toList()),

                    const SizedBox(height: 16),

                    // ── Step count footer ──────────────────────────────
                    if (metrics != null)
                      _StepCountRow(stepCount: metrics.stepCount),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: SportColors.surface,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: SportColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'RUNNING  LIVE',
            style: TextStyle(
              color: SportColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.stop_circle_outlined,
              color: SportColors.red, size: 28),
          tooltip: 'Finalizar sesión',
          onPressed: () => _confirmStop(context),
        ),
      ],
    );
  }

  /// Called on every Consumer rebuild to update the cadence chart history
  /// and to detect new recommendations.
  void _handleMetricsUpdate(SessionProvider session) {
    final metrics = session.currentMetrics;
    if (metrics == null) return;

    // Append new cadence data point to the rolling 30-second window.
    final cadence = metrics.cadenceStepsPerMin;
    if (cadence > 0) {
      _elapsedSeconds += 0.5; // provider notifies every ~0.5 s (50 samples @ 100 Hz)
      _cadenceHistory.add(FlSpot(_elapsedSeconds, cadence));

      // Remove points older than 30 seconds.
      while (_cadenceHistory.isNotEmpty &&
          _elapsedSeconds - _cadenceHistory.first.x > _windowSeconds) {
        _cadenceHistory.removeFirst();
      }
    }

    // Show recommendation banner when the message changes.
    final rec = metrics.recommendation;
    if (rec != null && rec != _lastRecommendation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _lastRecommendation = rec;
            _bannerVisible = true;
          });
        }
      });
    }
  }

  void _dismissBanner() {
    setState(() => _bannerVisible = false);
  }

  /// Returns a color based on cadence quality.
  Color _cadenceColor(double spm) {
    if (spm == 0) return SportColors.textSecondary;
    if (spm >= 170 && spm <= 190) return SportColors.green;
    if (spm >= 160 && spm < 170) return SportColors.cyan;
    if (spm > 190) return SportColors.orange;
    return SportColors.red; // < 160 spm — too low
  }

  Future<void> _confirmStop(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SportColors.surface,
        title: const Text('Finalizar sesión',
            style: TextStyle(color: SportColors.textPrimary)),
        content: const Text('¿Deseas terminar la sesión de running?',
            style: TextStyle(color: SportColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: SportColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalizar',
                style: TextStyle(color: SportColors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.pop(context); // Return to previous screen
    }
  }
}

// ── Internal layout widgets ──────────────────────────────────────────────────

/// Section wrapper for the L/R symmetry bar.
class _SymmetrySection extends StatelessWidget {
  const _SymmetrySection({
    required this.symmetryPct,
    required this.hasData,
  });

  final double symmetryPct;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SportColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SIMETRÍA  L / R',
            style: TextStyle(
              color: SportColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          hasData
              ? SymmetryBar(symmetryPct: symmetryPct)
              : const Center(
                  child: Text('Esperando datos...',
                      style: TextStyle(color: SportColors.textSecondary)),
                ),
        ],
      ),
    );
  }
}

/// Section wrapper for the 30-second cadence line chart.
class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.cadenceHistory});

  final List<FlSpot> cadenceHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: SportColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CADENCIA — ÚLTIMOS 30 s',
            style: TextStyle(
              color: SportColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: cadenceHistory.isEmpty
                ? const Center(
                    child: Text('Iniciando...',
                        style: TextStyle(color: SportColors.textSecondary)))
                : CadenceChart(spots: cadenceHistory),
          ),
        ],
      ),
    );
  }
}

/// Footer row showing total step count.
class _StepCountRow extends StatelessWidget {
  const _StepCountRow({required this.stepCount});

  final int stepCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.directions_run,
            color: SportColors.textSecondary, size: 16),
        const SizedBox(width: 6),
        Text(
          '$stepCount pasos totales',
          style: const TextStyle(
            color: SportColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
