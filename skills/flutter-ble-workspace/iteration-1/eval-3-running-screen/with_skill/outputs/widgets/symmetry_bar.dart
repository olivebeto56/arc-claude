// widgets/symmetry_bar.dart
// Bicolor L/R symmetry progress bar for the running dashboard.

import 'package:flutter/material.dart';

/// Renders a bicolor horizontal bar showing the left/right step symmetry.
///
/// [symmetryPct] is the percentage of load on the LEFT foot (0–100).
/// 50 % = perfectly symmetric; < 45 % or > 55 % triggers a warning color.
class SymmetryBar extends StatelessWidget {
  const SymmetryBar({
    super.key,
    required this.symmetryPct,
  });

  final double symmetryPct;

  static const double _balancedMin = 45.0;
  static const double _balancedMax = 55.0;

  bool get _isBalanced =>
      symmetryPct >= _balancedMin && symmetryPct <= _balancedMax;

  @override
  Widget build(BuildContext context) {
    // Left fraction (0.0 – 1.0)
    final leftFraction = (symmetryPct / 100.0).clamp(0.0, 1.0);
    final rightFraction = 1.0 - leftFraction;

    final Color leftColor =
        _isBalanced ? const Color(0xFF00E676) : const Color(0xFFFF9100);
    final Color rightColor =
        _isBalanced ? const Color(0xFF00E676) : const Color(0xFFFF1744);

    final String leftLabel =
        '${symmetryPct.toStringAsFixed(1)} %';
    final String rightLabel =
        '${(100 - symmetryPct).toStringAsFixed(1)} %';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Balance badge ──────────────────────────────────────────────
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: (_isBalanced
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFF9100))
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isBalanced
                    ? const Color(0xFF00E676)
                    : const Color(0xFFFF9100),
                width: 1,
              ),
            ),
            child: Text(
              _isBalanced ? 'Equilibrado' : 'Asimetría detectada',
              style: TextStyle(
                color: _isBalanced
                    ? const Color(0xFF00E676)
                    : const Color(0xFFFF9100),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Bicolor bar ────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 20,
            child: Row(
              children: [
                // Left segment
                Expanded(
                  flex: (leftFraction * 1000).round(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    color: leftColor,
                  ),
                ),
                // Center divider
                Container(width: 2, color: const Color(0xFF0A0A0A)),
                // Right segment
                Expanded(
                  flex: (rightFraction * 1000).round(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    color: rightColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Labels row ─────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _FootLabel(
                text: 'IZQ  $leftLabel', color: leftColor, isLeft: true),
            _FootLabel(
                text: 'DER  $rightLabel',
                color: rightColor,
                isLeft: false),
          ],
        ),
      ],
    );
  }
}

/// Small label shown below each side of the symmetry bar.
class _FootLabel extends StatelessWidget {
  const _FootLabel({
    required this.text,
    required this.color,
    required this.isLeft,
  });

  final String text;
  final Color color;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      textAlign: isLeft ? TextAlign.left : TextAlign.right,
    );
  }
}
