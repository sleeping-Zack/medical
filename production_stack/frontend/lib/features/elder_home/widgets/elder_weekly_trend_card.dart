import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/elder_home_models.dart';
import '../theme/elder_home_colors.dart';
import 'elder_adherence_line_chart.dart';

/// 最近 7 天服药完成率：折线图（fl_chart）+ 连续天数说明
class ElderWeeklyTrendCard extends StatelessWidget {
  const ElderWeeklyTrendCard({
    super.key,
    required this.trend,
    required this.streakDays,
    required this.encourageLine,
  });

  final List<ElderDayTrend> trend;
  final int streakDays;
  final String encourageLine;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: ElderHomeColors.cardShadow.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Text(
          '最近一周的数据准备好后，会在这里画出一条暖暖的小曲线～',
          style: TextStyle(fontSize: 18, height: 1.45, color: ElderHomeColors.textSoft),
        ),
      );
    }

    final last = trend.last;
    final todayPct = (last.rate * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/elder/stats'),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: ElderHomeColors.peach.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: ElderHomeColors.cardShadow.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('📈', style: TextStyle(fontSize: 26)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '最近 7 天按时完成率',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: ElderHomeColors.textWarm,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                encourageLine,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: ElderHomeColors.sageDeep,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '今天约 $todayPct% · 已连续认真记录 $streakDays 天 · 点卡片可看更多',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: ElderHomeColors.textSoft,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ElderHomeColors.cream.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  '小提示：点点曲线上的小圆点，能看到那一天吃了几次。',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ElderHomeColors.textSoft,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElderAdherenceLineChart(trend: trend),
            ],
          ),
        ),
      ),
    );
  }
}
