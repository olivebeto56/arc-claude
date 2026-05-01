// widgets/metric_card.dart
// Reusable card widget for displaying a single numeric running metric.

import 'package:flutter/material.dart';

/// Displays one biomechanical metric with a large value, unit, and label.
///
/// [highlight] makes the value text larger — used for the primary cadence card.
/// [color] tints the value text to signal quality (green = good, red = warning).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  /// When true, the value is rendered larger (primary metric style).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final double valueSize = highlight ? 52 : 36;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: color.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Label ────────────────────────────────────────────────────
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 6),

          // ── Value + unit row ─────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Numeric value — animates smoothly when it changes
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                builder: (_, __, ___) => Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: valueSize,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Unit label — aligned to baseline of value
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: color.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
