import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 0–100% 依从性折线图：显式 X/Y 域、裁剪溢出、曲线不越界、随屏幕宽度调整边距与字号。
/// 用于看护端计划页 / Shell 与长辈端周趋势。
class ResponsiveAdherenceLineChart extends StatelessWidget {
  const ResponsiveAdherenceLineChart({
    super.key,
    required this.yPercent,
    required this.bottomLabels,
    this.lineColor = const Color(0xFFE8863D),
    this.gridColor = const Color(0xFFFFD9BA),
    this.leftTitleColor = const Color(0xFF8B7A6E),
    this.bottomTitleColor = const Color(0xFF8B7A6E),
    this.belowGradient,
    this.lineTouchData,
    this.dotFillColor,
    this.dotStrokeColor,
    this.horizontalDash = true,
    this.axisLabelScale = 1.0,
  });

  /// 每日完成率 0–100，左到右一天一个点
  final List<double> yPercent;

  /// 与 [yPercent] 等长的横轴文案
  final List<String> bottomLabels;

  final Color lineColor;
  final Color gridColor;
  final Color leftTitleColor;
  final Color bottomTitleColor;
  final Gradient? belowGradient;
  final LineTouchData? lineTouchData;
  final Color? dotFillColor;
  final Color? dotStrokeColor;
  final bool horizontalDash;

  /// 横纵轴字号倍率（长辈端可 >1 以更易读）
  final double axisLabelScale;

  @override
  Widget build(BuildContext context) {
    final n = yPercent.length;
    if (n == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : MediaQuery.sizeOf(context).width;
        final hBudget = c.maxHeight.isFinite && c.maxHeight > 0 ? c.maxHeight : null;
        final leftR = (w * 0.11 * axisLabelScale.clamp(0.85, 1.6)).clamp(26.0, 52.0);
        final bottomR = (w * 0.085 * axisLabelScale.clamp(0.85, 1.6)).clamp(22.0, 44.0);
        var chartH = (w * 0.36).clamp(132.0, 220.0);
        if (hBudget != null && chartH > hBudget) {
          chartH = hBudget.clamp(96.0, chartH);
        }
        final fsLeft = ((11 * (w / 360)).clamp(8.5, 12.0) * axisLabelScale).clamp(7.0, 18.0);
        final fsBottom = ((10 * (w / 360)).clamp(8.0, 12.0) * axisLabelScale).clamp(7.0, 18.0);
        final dotR = (w / 72).clamp(3.0, 6.0);
        final strokeW = (w / 140).clamp(2.0, 3.5);

        final maxX = n > 1 ? (n - 1).toDouble() : 1.0;
        final spots = List<FlSpot>.generate(
          n,
          (i) => FlSpot(i.toDouble(), yPercent[i].clamp(0, 100)),
        );

        // 窄屏减少横轴标签密度，始终保留首尾
        final stride = w < 300 && n >= 6 ? 2 : (w < 260 && n >= 5 ? 2 : 1);

        return SizedBox(
          height: chartH,
          width: w,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: 100,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: gridColor.withValues(alpha: horizontalDash ? 0.85 : 0.55),
                  strokeWidth: 1,
                  dashArray: horizontalDash ? const [4, 4] : null,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: leftR,
                    interval: 25,
                    getTitlesWidget: (v, _) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${v.toInt()}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: fsLeft, fontWeight: FontWeight.w600, color: leftTitleColor),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: bottomR,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= n) return const SizedBox.shrink();
                      if (i % stride != 0 && i != 0 && i != n - 1) {
                        return const SizedBox.shrink();
                      }
                      final label = bottomLabels[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: fsBottom, fontWeight: FontWeight.w600, color: bottomTitleColor),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: lineTouchData ?? const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.32,
                  preventCurveOverShooting: true,
                  barWidth: strokeW,
                  color: lineColor,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) {
                      return FlDotCirclePainter(
                        radius: dotR,
                        color: dotFillColor ?? Colors.white,
                        strokeWidth: strokeW,
                        strokeColor: dotStrokeColor ?? lineColor,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: belowGradient != null,
                    gradient: belowGradient,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
