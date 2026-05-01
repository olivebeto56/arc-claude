// widgets/cadence_chart.dart
// fl_chart LineChart showing cadence (spm) over the last 30 seconds.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Renders a real-time cadence line chart using fl_chart.
///
/// [spots] is a list of [FlSpot] where:
///   - x = elapsed seconds (rolling window, rightmost = now)
///   - y = cadence in steps per minute
///
/// The Y axis is fixed at 120–220 spm to avoid jumpy rescaling.
class CadenceChart extends StatelessWidget {
  const CadenceChart({
    super.key,
    required this.spots,
  });

  final List<FlSpot> spots;

  // Y-axis bounds (physiological running range)
  static const double _minY = 120;
  static const double _maxY = 220;

  // Optimal cadence zone markers
  static const double _optimalLow = 170;
  static const double _optimalHigh = 190;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      _buildChartData(),
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  LineChartData _buildChartData() {
    return LineChartData(
      minY: _minY,
      maxY: _maxY,

      // ── Clip behavior ────────────────────────────────────────────────
      clipData: const FlClipData.all(),

      // ── Background grid ──────────────────────────────────────────────
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (value) {
          // Highlight the optimal cadence zone in green
          final bool inZone = value >= _optimalLow && value <= _optimalHigh;
          return FlLine(
            color: inZone
                ? const Color(0xFF00E676).withOpacity(0.25)
                : Colors.white.withOpacity(0.06),
            strokeWidth: inZone ? 1.5 : 1,
          );
        },
      ),

      // ── Border ───────────────────────────────────────────────────────
      borderData: FlBorderData(show: false),

      // ── Axis titles ──────────────────────────────────────────────────
      titlesData: FlTitlesData(
        // Left axis: spm values
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            interval: 20,
            getTitlesWidget: (value, _) => Text(
              value.toInt().toString(),
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // All other axes hidden
        bottomTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),

      // ── Optional extra lines (optimal zone shading via horizontal markers) ─
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          // Lower bound of optimal zone
          HorizontalLine(
            y: _optimalLow,
            color: const Color(0xFF00E676).withOpacity(0.4),
            strokeWidth: 1,
            dashArray: [4, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              style: const TextStyle(
                  color: Color(0xFF00E676), fontSize: 9),
              labelResolver: (_) => '170',
            ),
          ),
          // Upper bound of optimal zone
          HorizontalLine(
            y: _optimalHigh,
            color: const Color(0xFF00E676).withOpacity(0.4),
            strokeWidth: 1,
            dashArray: [4, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              style: const TextStyle(
                  color: Color(0xFF00E676), fontSize: 9),
              labelResolver: (_) => '190',
            ),
          ),
        ],
      ),

      // ── Touch / tooltip ──────────────────────────────────────────────
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1A1A2E),
          tooltipRoundedRadius: 8,
          getTooltipItems: (touchedSpots) => touchedSpots
              .map(
                (spot) => LineTooltipItem(
                  '${spot.y.toStringAsFixed(0)} spm',
                  const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              )
              .toList(),
        ),
      ),

      // ── Line data ────────────────────────────────────────────────────
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: const Color(0xFF00E5FF),
          barWidth: 2.5,
          // No dot markers — too cluttered at 2 Hz update rate
          dotData: const FlDotData(show: false),
          // Gradient fill under the line
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF00E5FF).withOpacity(0.25),
                const Color(0xFF00E5FF).withOpacity(0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
