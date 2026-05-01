// lib/screens/summary_screen.dart
//
// SummaryScreen — Flutter widget that renders a [SessionSummary] after a run.
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => SummaryScreen(summary: sessionProvider.sessionSummary!),
//   ));
//
// Design notes:
//   - Scaffold with a scrollable Column so it adapts to all screen sizes.
//   - Each metric card shows the raw value + a colored progress bar for the score.
//   - Score colors: green ≥ 75, amber 50–74, red < 50.
//   - The overall score uses a large circular indicator for quick at-a-glance reading.
//   - Recommendations are listed at the bottom as expandable chips.

import 'package:flutter/material.dart';
import '../analysis/session_summary.dart';

// ---------------------------------------------------------------------------
// Main screen widget
// ---------------------------------------------------------------------------

class SummaryScreen extends StatelessWidget {
  final SessionSummary summary;

  const SummaryScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1117),
        foregroundColor: Colors.white,
        title: const Text('Resumen de sesión'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Overall score hero
              _OverallScoreCard(summary: summary),
              const SizedBox(height: 24),

              // Session stats row (duration + steps)
              _SessionStatsRow(summary: summary),
              const SizedBox(height: 24),

              // Assessment text
              _AssessmentCard(text: summary.overallAssessment),
              const SizedBox(height: 24),

              // Dimension score cards
              Text(
                'Análisis por dimensión',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _DimensionScoreCard(
                label: 'Cadencia',
                icon: Icons.directions_run,
                score: summary.dimensionScores['cadence'] ?? 0,
                value: '${summary.avgCadence.toStringAsFixed(0)} spm',
                detail: 'Pico: ${summary.peakCadence.toStringAsFixed(0)} spm',
                optimalRange: '170–180 spm',
              ),
              const SizedBox(height: 10),
              _DimensionScoreCard(
                label: 'Simetría',
                icon: Icons.balance,
                score: summary.dimensionScores['symmetry'] ?? 0,
                value: '${summary.avgSymmetry.toStringAsFixed(1)}% izq.',
                detail: 'Desviación: ${(summary.avgSymmetry - 50).abs().toStringAsFixed(1)}%',
                optimalRange: '45–55%',
              ),
              const SizedBox(height: 10),
              _DimensionScoreCard(
                label: 'Tiempo de contacto',
                icon: Icons.touch_app,
                score: summary.dimensionScores['contact_time'] ?? 0,
                value: '${summary.avgContactTimeMs.toStringAsFixed(0)} ms',
                detail: 'Menor es mejor',
                optimalRange: '≤ 220 ms',
              ),
              const SizedBox(height: 10),
              _DimensionScoreCard(
                label: 'Ángulo de pisada',
                icon: Icons.show_chart,
                score: summary.dimensionScores['strike'] ?? 0,
                value: '${summary.avgStrikeAngleDeg.toStringAsFixed(1)}°',
                detail: _strikeTypeLabel(summary.avgStrikeAngleDeg),
                optimalRange: '-5° a 5°',
              ),
              const SizedBox(height: 24),

              // Recommendations section
              if (summary.recommendations.isNotEmpty) ...[
                Text(
                  'Aspectos a trabajar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _RecommendationsList(recommendations: summary.recommendations),
                const SizedBox(height: 24),
              ],

              // Variability footnote
              _VariabilityFootnote(variability: summary.avgVariability),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _strikeTypeLabel(double angle) {
    if (angle < -5) return 'Forefoot (punta)';
    if (angle <= 5) return 'Midfoot (óptimo)';
    if (angle <= 12) return 'Leve heel strike';
    return 'Heel strike pronunciado';
  }
}

// ---------------------------------------------------------------------------
// Overall score hero card
// ---------------------------------------------------------------------------

class _OverallScoreCard extends StatelessWidget {
  final SessionSummary summary;

  const _OverallScoreCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final score = summary.overallScore;
    final color = _scoreColor(score);
    final levelLabel = _levelLabel(summary.athleteLevel);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            levelLabel,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Circular score indicator
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      '/100',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Score general',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 75) return const Color(0xFF4CAF50);   // green
    if (score >= 50) return const Color(0xFFFFC107);   // amber
    return const Color(0xFFF44336);                     // red
  }

  String _levelLabel(AthleteLevel level) {
    switch (level) {
      case AthleteLevel.elite:        return 'NIVEL ELITE';
      case AthleteLevel.advanced:     return 'NIVEL AVANZADO';
      case AthleteLevel.intermediate: return 'NIVEL INTERMEDIO';
      case AthleteLevel.beginner:     return 'NIVEL PRINCIPIANTE';
      case AthleteLevel.developing:   return 'EN DESARROLLO';
    }
  }
}

// ---------------------------------------------------------------------------
// Session stats row (duration + steps)
// ---------------------------------------------------------------------------

class _SessionStatsRow extends StatelessWidget {
  final SessionSummary summary;

  const _SessionStatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final mins = summary.totalDuration.inMinutes;
    final secs = summary.totalDuration.inSeconds % 60;
    final durationStr = '$mins:${secs.toString().padLeft(2, '0')} min';

    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: Icons.timer_outlined,
            label: 'Duración',
            value: durationStr,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            icon: Icons.format_list_numbered,
            label: 'Pasos',
            value: '${summary.totalSteps}',
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Assessment text card
// ---------------------------------------------------------------------------

class _AssessmentCard extends StatelessWidget {
  final String text;

  const _AssessmentCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights, color: Color(0xFF7C83FD), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dimension score card
// ---------------------------------------------------------------------------

class _DimensionScoreCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final double score;       // 0–100
  final String value;       // formatted metric value
  final String detail;      // secondary info line
  final String optimalRange;

  const _DimensionScoreCard({
    required this.label,
    required this.icon,
    required this.score,
    required this.value,
    required this.detail,
    required this.optimalRange,
  });

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + label + score badge
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${score.toStringAsFixed(0)}/100',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Score progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),

          // Value + detail row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    detail,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    'Óptimo: $optimalRange',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 75) return const Color(0xFF4CAF50);
    if (score >= 50) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }
}

// ---------------------------------------------------------------------------
// Recommendations list
// ---------------------------------------------------------------------------

class _RecommendationsList extends StatelessWidget {
  final List<String> recommendations;

  const _RecommendationsList({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: recommendations.asMap().entries.map((entry) {
        final index = entry.key;
        final message = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RecommendationTile(index: index + 1, message: message),
        );
      }).toList(),
    );
  }
}

class _RecommendationTile extends StatefulWidget {
  final int index;
  final String message;

  const _RecommendationTile({required this.index, required this.message});

  @override
  State<_RecommendationTile> createState() => _RecommendationTileState();
}

class _RecommendationTileState extends State<_RecommendationTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Show the first ~60 chars when collapsed, full text when expanded
    final isLong = widget.message.length > 60;
    final displayText = (!_expanded && isLong)
        ? '${widget.message.substring(0, 60)}…'
        : widget.message;

    return GestureDetector(
      onTap: isLong ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF252836),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index badge
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF7C83FD),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${widget.index}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  if (isLong) ...[
                    const SizedBox(height: 4),
                    Text(
                      _expanded ? 'Ver menos' : 'Ver más',
                      style: const TextStyle(
                        color: Color(0xFF7C83FD),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Variability footnote
// ---------------------------------------------------------------------------

class _VariabilityFootnote extends StatelessWidget {
  final double variability;

  const _VariabilityFootnote({required this.variability});

  @override
  Widget build(BuildContext context) {
    // Only show if variability is noteworthy (> 4%)
    if (variability <= 4) return const SizedBox.shrink();

    final label = variability > 7 ? 'Alta variabilidad' : 'Variabilidad moderada';
    final note  = variability > 7
        ? 'El ritmo fue irregular (CV ${variability.toStringAsFixed(1)}%). '
          'Puede indicar fatiga o cambios de terreno.'
        : 'Algo de irregularidad en el ritmo (CV ${variability.toStringAsFixed(1)}%). '
          'Normal en sesiones largas.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFC107), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, height: 1.4),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: note,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
