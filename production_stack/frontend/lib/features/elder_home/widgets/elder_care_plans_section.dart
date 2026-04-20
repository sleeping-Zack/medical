import 'package:flutter/material.dart';

import '../../care/models/plan_item.dart';
import '../theme/elder_home_colors.dart';

/// 与看护端计划列表同源，长辈端可核对「今天有哪些用药安排」。
class ElderCarePlansSection extends StatelessWidget {
  const ElderCarePlansSection({super.key, required this.plans, required this.loading});

  final List<PlanItem> plans;
  final bool loading;

  String _timesSummary(PlanItem p) {
    final parts = <String>[];
    for (final raw in p.schedulesJson) {
      if (raw is! Map) continue;
      final h = raw['hour'];
      final m = raw['minute'];
      if (h is! num || m is! num) continue;
      parts.add('${h.toInt().toString().padLeft(2, '0')}:${m.toInt().toString().padLeft(2, '0')}');
    }
    if (parts.isEmpty) return '时间见详情';
    return parts.join('、');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ElderHomeColors.peach.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(color: ElderHomeColors.cardShadow, blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('我的用药计划', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ElderHomeColors.textWarm)),
          const SizedBox(height: 6),
          Text(
            loading ? '正在加载…' : '和家里人手机上看到的是同一份安排',
            style: const TextStyle(fontSize: 17, height: 1.35, color: ElderHomeColors.textSoft),
          ),
          const SizedBox(height: 14),
          if (!loading && plans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂时还没有计划。可以让家人在「计划」里帮您添加，或您用家属端登录后自己添加。',
                style: TextStyle(fontSize: 17, height: 1.45, color: ElderHomeColors.textSoft, fontWeight: FontWeight.w600),
              ),
            )
          else
            ...plans.map((p) {
              final title = (p.label != null && p.label!.trim().isNotEmpty) ? p.label!.trim() : p.medicineName;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ElderHomeColors.cream.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ElderHomeColors.apricot.withValues(alpha: 0.45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ElderHomeColors.deepApricot)),
                      const SizedBox(height: 4),
                      Text('药品：${p.medicineName}', style: const TextStyle(fontSize: 17, color: ElderHomeColors.textWarm)),
                      Text('服药时间：${_timesSummary(p)}', style: const TextStyle(fontSize: 17, color: ElderHomeColors.textSoft)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
