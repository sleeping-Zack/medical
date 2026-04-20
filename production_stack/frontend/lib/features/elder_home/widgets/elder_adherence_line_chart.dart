import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../care/widgets/responsive_adherence_line_chart.dart';
import '../models/elder_home_models.dart';
import '../theme/elder_home_colors.dart';

/// 最近 7 天「按时完成率」折线图（0–100%），适合长辈一眼看懂趋势
class ElderAdherenceLineChart extends StatelessWidget {
  const ElderAdherenceLineChart({
    super.key,
    required this.trend,
  });

  final List<ElderDayTrend> trend;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();

    final yPercent = trend.map((e) => (e.rate * 100).clamp(0, 100).toDouble()).toList();
    final bottomLabels = trend.map((e) => e.weekdayLabel).toList();

    return ResponsiveAdherenceLineChart(
      yPercent: yPercent,
      bottomLabels: bottomLabels,
      axisLabelScale: 1.38,
      lineColor: ElderHomeColors.deepApricot,
      gridColor: ElderHomeColors.peach.withValues(alpha: 0.45),
      leftTitleColor: ElderHomeColors.textSoft,
      bottomTitleColor: ElderHomeColors.textWarm,
      horizontalDash: false,
      dotFillColor: Colors.white,
      dotStrokeColor: ElderHomeColors.deepApricot,
      belowGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ElderHomeColors.apricot.withValues(alpha: 0.45),
          ElderHomeColors.softPink.withValues(alpha: 0.08),
        ],
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => ElderHomeColors.cream,
          tooltipRoundedRadius: 14,
          getTooltipItems: (touched) {
            return touched.map((e) {
              final i = e.x.toInt();
              if (i < 0 || i >= trend.length) return null;
              final d = trend[i];
              final pct = (d.rate * 100).round();
              return LineTooltipItem(
                '周${d.weekdayLabel}\n完成约 $pct%\n（${d.completedDoses}/${d.scheduledDoses} 次）',
                const TextStyle(
                  color: ElderHomeColors.textWarm,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.35,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}
