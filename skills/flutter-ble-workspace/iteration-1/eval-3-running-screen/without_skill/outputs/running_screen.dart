import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Data model – replace with your real SessionProvider import
// ---------------------------------------------------------------------------

/// Holds the running session state. Wire this up to your BLE pipeline.
class SessionProvider extends ChangeNotifier {
  // Live metrics
  double _cadence = 0; // steps per minute
  double _leftContact = 50; // % of ground contact time on left foot
  double _avgContactTime = 0; // ms

  // Rolling cadence history (last 30 s sampled once per second)
  final List<double> _cadenceHistory = [];
  static const int _historyLength = 30;

  // Optional coaching recommendation
  String? _recommendation;

  // ── Getters ──────────────────────────────────────────────────────────────
  double get cadence => _cadence;
  double get leftContact => _leftContact; // right = 100 - leftContact
  double get rightContact => 100 - _leftContact;
  double get avgContactTime => _avgContactTime;
  List<double> get cadenceHistory => List.unmodifiable(_cadenceHistory);
  String? get recommendation => _recommendation;

  bool get symmetryInRange => _leftContact >= 45 && _leftContact <= 55;

  // ── Setters (call from your BLE data handler) ─────────────────────────────
  void updateMetrics({
    required double cadence,
    required double leftContactPct,
    required double avgContactMs,
    String? recommendation,
  }) {
    _cadence = cadence;
    _leftContact = leftContactPct;
    _avgContactTime = avgContactMs;
    _recommendation = recommendation;

    _cadenceHistory.add(cadence);
    if (_cadenceHistory.length > _historyLength) {
      _cadenceHistory.removeAt(0);
    }

    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Theme constants
// ---------------------------------------------------------------------------
const Color _kPrimary = Color(0xFF00E5FF); // cyan
const Color _kBackground = Color(0xFF0A0E1A);
const Color _kSurface = Color(0xFF141928);
const Color _kCardBorder = Color(0xFF1E2640);
const Color _kGreen = Color(0xFF00E676);
const Color _kOrange = Color(0xFFFF9800);
const Color _kTextMuted = Color(0xFF6B7A99);

// ---------------------------------------------------------------------------
// RunningScreen
// ---------------------------------------------------------------------------

class RunningScreen extends StatelessWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _buildDarkTheme(),
      child: Scaffold(
        backgroundColor: _kBackground,
        appBar: AppBar(
          backgroundColor: _kBackground,
          elevation: 0,
          centerTitle: false,
          title: const Text(
            'Running Dashboard',
            style: TextStyle(
              color: _kPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(Icons.circle, color: _kGreen, size: 12),
            ),
          ],
        ),
        body: Consumer<SessionProvider>(
          builder: (context, session, _) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Recommendation banner ─────────────────────────────
                    if (session.recommendation != null)
                      _RecommendationBanner(message: session.recommendation!),

                    const SizedBox(height: 12),

                    // ── Cadence (hero metric) ─────────────────────────────
                    _CadenceCard(cadence: session.cadence),

                    const SizedBox(height: 12),

                    // ── Symmetry + Contact time (side by side) ────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _SymmetryCard(
                            leftPct: session.leftContact,
                            rightPct: session.rightContact,
                            inRange: session.symmetryInRange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _ContactTimeCard(ms: session.avgContactTime),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Cadence history chart ─────────────────────────────
                    _CadenceChartCard(history: session.cadenceHistory),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _kBackground,
      colorScheme: const ColorScheme.dark(
        primary: _kPrimary,
        surface: _kSurface,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recommendation Banner
// ---------------------------------------------------------------------------

class _RecommendationBanner extends StatelessWidget {
  final String message;
  const _RecommendationBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003D4F), Color(0xFF001F2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimary.withOpacity(0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded, color: _kPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cadence card (hero)
// ---------------------------------------------------------------------------

class _CadenceCard extends StatelessWidget {
  final double cadence;
  const _CadenceCard({required this.cadence});

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CADENCIA', style: _labelStyle),
              const Icon(Icons.directions_run_rounded, color: _kPrimary, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                cadence.toStringAsFixed(0),
                style: const TextStyle(
                  color: _kPrimary,
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'spm',
                  style: TextStyle(
                    color: _kTextMuted,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _CadenceZoneIndicator(cadence: cadence),
        ],
      ),
    );
  }
}

class _CadenceZoneIndicator extends StatelessWidget {
  final double cadence;
  const _CadenceZoneIndicator({required this.cadence});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (cadence) {
      < 160 => ('Por debajo del rango óptimo', _kOrange),
      >= 160 && <= 180 => ('Zona óptima', _kGreen),
      _ => ('Por encima del rango óptimo', _kOrange),
    };

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Symmetry card
// ---------------------------------------------------------------------------

class _SymmetryCard extends StatelessWidget {
  final double leftPct;
  final double rightPct;
  final bool inRange;

  const _SymmetryCard({
    required this.leftPct,
    required this.rightPct,
    required this.inRange,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = inRange ? _kGreen : _kOrange;
    final labelColor = inRange ? _kGreen : _kOrange;

    return _MetricCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SIMETRÍA L/R', style: _labelStyle),
              Icon(
                inRange ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: labelColor,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bicolor bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 18,
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final leftWidth = constraints.maxWidth * (leftPct / 100);
                  return Row(
                    children: [
                      Container(
                        width: leftWidth,
                        color: barColor,
                      ),
                      Expanded(
                        child: Container(
                          color: barColor.withOpacity(0.28),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FootLabel(side: 'Izq', pct: leftPct, color: barColor),
              _FootLabel(side: 'Der', pct: rightPct, color: barColor, alignRight: true),
            ],
          ),

          const SizedBox(height: 8),

          // 50% target line caption
          Center(
            child: Text(
              inRange ? 'Simetría equilibrada' : 'Fuera del rango 45–55 %',
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FootLabel extends StatelessWidget {
  final String side;
  final double pct;
  final Color color;
  final bool alignRight;

  const _FootLabel({
    required this.side,
    required this.pct,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(side, style: const TextStyle(color: _kTextMuted, fontSize: 11)),
        Text(
          '${pct.toStringAsFixed(1)} %',
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contact-time card
// ---------------------------------------------------------------------------

class _ContactTimeCard extends StatelessWidget {
  final double ms;
  const _ContactTimeCard({required this.ms});

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONTACTO', style: _labelStyle),
          const SizedBox(height: 8),
          Text(
            ms.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'ms',
            style: TextStyle(color: _kTextMuted, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          _ContactTimeRange(ms: ms),
        ],
      ),
    );
  }
}

class _ContactTimeRange extends StatelessWidget {
  final double ms;
  const _ContactTimeRange({required this.ms});

  @override
  Widget build(BuildContext context) {
    // Optimal elite range: 160–200 ms; recreational: 200–300 ms
    final (label, color) = switch (ms) {
      < 160 => ('Muy corto', _kOrange),
      >= 160 && < 200 => ('Élite', _kGreen),
      >= 200 && <= 300 => ('Normal', _kPrimary),
      _ => ('Muy largo', _kOrange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cadence chart card (last 30 s)
// ---------------------------------------------------------------------------

class _CadenceChartCard extends StatelessWidget {
  final List<double> history;
  const _CadenceChartCard({required this.history});

  List<FlSpot> get _spots {
    if (history.isEmpty) return [const FlSpot(0, 0)];
    return history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
  }

  double get _minY {
    if (history.isEmpty) return 100;
    final min = history.reduce((a, b) => a < b ? a : b);
    return (min - 20).clamp(100, 300).toDouble();
  }

  double get _maxY {
    if (history.isEmpty) return 220;
    final max = history.reduce((a, b) => a > b ? a : b);
    return (max + 20).clamp(120, 320).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CADENCIA — ÚLTIMOS 30 s', style: _labelStyle),
              const Text('spm', style: TextStyle(color: _kTextMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      'Esperando datos…',
                      style: TextStyle(color: _kTextMuted, fontSize: 13),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 29,
                      minY: _minY,
                      maxY: _maxY,
                      backgroundColor: Colors.transparent,
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 20,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: _kCardBorder,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            interval: 20,
                            getTitlesWidget: (val, _) => Text(
                              val.toInt().toString(),
                              style: const TextStyle(
                                color: _kTextMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 10,
                            getTitlesWidget: (val, _) {
                              final secs = (29 - val.toInt());
                              return Text(
                                '${secs}s',
                                style: const TextStyle(
                                  color: _kTextMuted,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _spots,
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: _kPrimary,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                _kPrimary.withOpacity(0.25),
                                _kPrimary.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        // Optimal zone reference lines (160 & 180 spm)
                        LineChartBarData(
                          spots: [FlSpot(0, 180), FlSpot(29, 180)],
                          isCurved: false,
                          color: _kGreen.withOpacity(0.4),
                          barWidth: 1,
                          dashArray: [6, 4],
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                        LineChartBarData(
                          spots: [FlSpot(0, 160), FlSpot(29, 160)],
                          isCurved: false,
                          color: _kGreen.withOpacity(0.4),
                          barWidth: 1,
                          dashArray: [6, 4],
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => _kSurface,
                          tooltipRoundedRadius: 8,
                          getTooltipItems: (touchedSpots) => touchedSpots
                              .where((s) => s.barIndex == 0)
                              .map(
                                (s) => LineTooltipItem(
                                  '${s.y.toStringAsFixed(0)} spm',
                                  const TextStyle(
                                    color: _kPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          // Optimal zone legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 18, height: 2, color: _kGreen.withOpacity(0.5)),
              const SizedBox(width: 6),
              const Text(
                'Zona óptima 160–180 spm',
                style: TextStyle(color: _kTextMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card container
// ---------------------------------------------------------------------------

class _MetricCard extends StatelessWidget {
  final Widget child;
  const _MetricCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared text style
// ---------------------------------------------------------------------------

const TextStyle _labelStyle = TextStyle(
  color: _kTextMuted,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
);

// ---------------------------------------------------------------------------
// App entry-point (for standalone testing)
// ---------------------------------------------------------------------------

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SessionProvider()
        ..updateMetrics(
          cadence: 172,
          leftContactPct: 48,
          avgContactMs: 235,
          recommendation:
              'Incrementa ligeramente la cadencia. Apunta a 175 spm para reducir el impacto articular.',
        ),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RunningScreen(),
      ),
    ),
  );
}
