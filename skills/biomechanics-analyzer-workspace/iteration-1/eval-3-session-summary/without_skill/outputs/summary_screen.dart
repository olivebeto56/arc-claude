/// summary_screen.dart
///
/// Flutter screen that displays a [SessionSummary] produced by
/// [SessionSummaryBuilder]. Self-contained — no external package required
/// beyond the Flutter SDK.

import 'package:flutter/material.dart';

import 'session_summary.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen entry point
// ─────────────────────────────────────────────────────────────────────────────

class SummaryScreen extends StatelessWidget {
  final SessionSummary summary;

  const SummaryScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1923),
        elevation: 0,
        title: const Text(
          'Resumen de sesión',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir',
            onPressed: () => _onShare(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OverallScoreCard(summary: summary),
              const SizedBox(height: 16),
              _DimensionGrid(summary: summary),
              const SizedBox(height: 16),
              _MetaInfoCard(summary: summary),
              const SizedBox(height: 16),
              if (summary.recommendations.isNotEmpty)
                _RecommendationsCard(recommendations: summary.recommendations),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _onShare(BuildContext context) {
    // Placeholder — integrate with share_plus or similar package.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función de compartir próximamente.'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overall score card with circular gauge
// ─────────────────────────────────────────────────────────────────────────────

class _OverallScoreCard extends StatelessWidget {
  final SessionSummary summary;

  const _OverallScoreCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final level = summary.level;
    final scoreColor = _scoreColor(summary.overallScore);

    return Card(
      color: const Color(0xFF1C2B3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              level.displayName.toUpperCase(),
              style: TextStyle(
                color: scoreColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            _CircularScoreGauge(
              score: summary.overallScore,
              color: scoreColor,
            ),
            const SizedBox(height: 16),
            Text(
              level.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF00E5FF);
    if (score >= 70) return const Color(0xFF69F0AE);
    if (score >= 50) return const Color(0xFFFFD740);
    return const Color(0xFFFF5252);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circular gauge drawn with CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _CircularScoreGauge extends StatelessWidget {
  final int score;
  final Color color;
  static const double _size = 130;

  const _CircularScoreGauge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(
        painter: _GaugePainter(score: score, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'de 100',
                style: TextStyle(
                  color: color.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;

    // Background track
    final trackPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -2.356; // -135°
    const fullSweep = 4.712;   // 270°

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fullSweep,
      false,
      trackPaint,
    );

    final sweepAngle = fullSweep * (score / 100.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2×2 grid of dimension score cards
// ─────────────────────────────────────────────────────────────────────────────

class _DimensionGrid extends StatelessWidget {
  final SessionSummary summary;

  const _DimensionGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _DimensionCard(
          dimension: summary.cadenceScore,
          unit: 'ppm',
          icon: Icons.timer_outlined,
          description: 'Óptimo 170–180 ppm',
        ),
        _DimensionCard(
          dimension: summary.symmetryScore,
          unit: '%',
          icon: Icons.balance_outlined,
          description: 'Óptimo 45–55 %',
        ),
        _DimensionCard(
          dimension: summary.contactScore,
          unit: 'ms',
          icon: Icons.touch_app_outlined,
          description: 'Óptimo ≤260 ms',
          lowerIsBetter: true,
        ),
        _DimensionCard(
          dimension: summary.strikeScore,
          unit: '°',
          icon: Icons.directions_run_outlined,
          description: 'Óptimo ≤5°',
          lowerIsBetter: true,
        ),
      ],
    );
  }
}

class _DimensionCard extends StatelessWidget {
  final DimensionScore dimension;
  final String unit;
  final IconData icon;
  final String description;
  final bool lowerIsBetter;

  const _DimensionCard({
    required this.dimension,
    required this.unit,
    required this.icon,
    required this.description,
    this.lowerIsBetter = false,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = _bandColor(dimension.score);

    return Card(
      color: const Color(0xFF1C2B3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scoreColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dimension.label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${dimension.average.toStringAsFixed(1)} $unit',
              style: TextStyle(
                color: scoreColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            _ScoreBar(score: dimension.score, color: scoreColor),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _bandColor(int score) {
    if (score >= 85) return const Color(0xFF00E5FF);
    if (score >= 70) return const Color(0xFF69F0AE);
    if (score >= 50) return const Color(0xFFFFD740);
    return const Color(0xFFFF5252);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin horizontal progress bar for a dimension score
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: score / 100.0,
        backgroundColor: Colors.white12,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session meta information (duration, samples)
// ─────────────────────────────────────────────────────────────────────────────

class _MetaInfoCard extends StatelessWidget {
  final SessionSummary summary;

  const _MetaInfoCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final duration = summary.sessionDuration;
    final durationText = duration != null
        ? _formatDuration(duration)
        : 'No disponible';

    return Card(
      color: const Color(0xFF1C2B3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _MetaTile(
              icon: Icons.access_time_rounded,
              label: 'Duración',
              value: durationText,
            ),
            const _VerticalDivider(),
            _MetaTile(
              icon: Icons.scatter_plot_outlined,
              label: 'Muestras',
              value: '${summary.sampleCount}',
            ),
            const _VerticalDivider(),
            _MetaTile(
              icon: Icons.leaderboard_outlined,
              label: 'Nivel',
              value: summary.level.displayName,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _MetaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white12,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendations card
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationsCard extends StatelessWidget {
  final List<String> recommendations;

  const _RecommendationsCard({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1C2B3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: Color(0xFFFFD740),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Recomendaciones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.asMap().entries.map(
              (e) => _RecommendationItem(
                index: e.key + 1,
                text: e.value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationItem extends StatelessWidget {
  final int index;
  final String text;

  const _RecommendationItem({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD740).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Color(0xFFFFD740),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Example / preview entry point (remove in production)
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a [SessionSummary] with synthetic data for UI previews in
/// flutter run / widget tests.
SessionSummary buildExampleSummary() {
  final builder = SessionSummaryBuilder();

  // Simulated 20 steps with realistic running data
  final samples = [
    RunningMetrics(cadenceSpm: 168, symmetryPercent: 48, contactTimeMs: 255, strikeAngleDeg: 4.2),
    RunningMetrics(cadenceSpm: 172, symmetryPercent: 51, contactTimeMs: 248, strikeAngleDeg: 3.8),
    RunningMetrics(cadenceSpm: 175, symmetryPercent: 50, contactTimeMs: 242, strikeAngleDeg: 3.1),
    RunningMetrics(cadenceSpm: 170, symmetryPercent: 52, contactTimeMs: 258, strikeAngleDeg: 4.5),
    RunningMetrics(cadenceSpm: 174, symmetryPercent: 49, contactTimeMs: 250, strikeAngleDeg: 3.6),
    RunningMetrics(cadenceSpm: 176, symmetryPercent: 53, contactTimeMs: 244, strikeAngleDeg: 2.9),
    RunningMetrics(cadenceSpm: 169, symmetryPercent: 47, contactTimeMs: 262, strikeAngleDeg: 5.1),
    RunningMetrics(cadenceSpm: 173, symmetryPercent: 51, contactTimeMs: 246, strikeAngleDeg: 3.3),
    RunningMetrics(cadenceSpm: 177, symmetryPercent: 50, contactTimeMs: 238, strikeAngleDeg: 2.7),
    RunningMetrics(cadenceSpm: 171, symmetryPercent: 48, contactTimeMs: 260, strikeAngleDeg: 4.8),
    RunningMetrics(cadenceSpm: 175, symmetryPercent: 52, contactTimeMs: 245, strikeAngleDeg: 3.4),
    RunningMetrics(cadenceSpm: 178, symmetryPercent: 50, contactTimeMs: 236, strikeAngleDeg: 2.5),
    RunningMetrics(cadenceSpm: 172, symmetryPercent: 49, contactTimeMs: 255, strikeAngleDeg: 4.1),
    RunningMetrics(cadenceSpm: 174, symmetryPercent: 51, contactTimeMs: 248, strikeAngleDeg: 3.7),
    RunningMetrics(cadenceSpm: 176, symmetryPercent: 50, contactTimeMs: 241, strikeAngleDeg: 3.0),
    RunningMetrics(cadenceSpm: 170, symmetryPercent: 53, contactTimeMs: 259, strikeAngleDeg: 4.6),
    RunningMetrics(cadenceSpm: 173, symmetryPercent: 48, contactTimeMs: 252, strikeAngleDeg: 3.9),
    RunningMetrics(cadenceSpm: 175, symmetryPercent: 50, contactTimeMs: 244, strikeAngleDeg: 3.2),
    RunningMetrics(cadenceSpm: 177, symmetryPercent: 52, contactTimeMs: 239, strikeAngleDeg: 2.8),
    RunningMetrics(cadenceSpm: 174, symmetryPercent: 51, contactTimeMs: 247, strikeAngleDeg: 3.5),
  ];

  builder.addAll(samples);

  return builder.build(
    sessionDuration: const Duration(minutes: 32, seconds: 14),
  );
}

/// Minimal app wrapper for standalone preview.
class SummaryScreenPreviewApp extends StatelessWidget {
  const SummaryScreenPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Sport Monitor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1923),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF69F0AE),
        ),
      ),
      home: SummaryScreen(summary: buildExampleSummary()),
      debugShowCheckedModeBanner: false,
    );
  }
}
