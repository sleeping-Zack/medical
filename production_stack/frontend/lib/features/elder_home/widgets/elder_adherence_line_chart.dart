import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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

    final spots = List<FlSpot>.generate(
      trend.length,
      (i) => FlSpot(i.toDouble(), (trend[i].rate * 100).clamp(0, 100)),
    );

    final lastX = (trend.length - 1).clamp(0, 64).toDouble();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: lastX,
          minY: 0,
          maxY: 100,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (v) => FlLine(
              color: ElderHomeColors.peach.withValues(alpha: 0.45),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (v, m) => Text(
                  '${v.toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ElderHomeColors.textSoft,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      trend[i].weekdayLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ElderHomeColors.textWarm,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
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
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              barWidth: 4,
              color: ElderHomeColors.deepApricot,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 5,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: ElderHomeColors.deepApricot,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ElderHomeColors.apricot.withValues(alpha: 0.45),
                    ElderHomeColors.softPink.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
