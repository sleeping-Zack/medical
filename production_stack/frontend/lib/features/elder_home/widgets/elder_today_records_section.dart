import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/elder_home_models.dart';
import '../theme/elder_home_colors.dart';

/// 今日吃药记录（时间轴风格，最多展示若干条 + 查看更多）
class ElderTodayRecordsSection extends StatelessWidget {
  const ElderTodayRecordsSection({
    super.key,
    required this.records,
    this.maxVisible = 32,
  });

  final List<ElderTodayIntakeRecord> records;

  /// 长辈端默认展示当天全部条目；超过此数量时出现「查看更多」
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final sorted = [...records]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final visible = sorted.length > maxVisible ? sorted.sublist(0, maxVisible) : sorted;
    final hasMore = sorted.length > maxVisible;

    return _sectionCard(
      title: '今日吃药记录',
      subtitle: '按时间排好了，从上到下慢慢看就好',
      child: Column(
        children: [
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '今天还没有安排服药时间，可以让家人帮您加一下计划哦。',
                style: TextStyle(fontSize: 18, color: ElderHomeColors.textSoft, height: 1.45),
              ),
            )
          else
            ...visible.asMap().entries.map((e) => _timelineTile(context, e.value, e.key == visible.length - 1)),
          if (hasMore)
            TextButton(
              onPressed: () => context.push('/elder/records'),
              child: const Text(
                '查看更多记录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ElderHomeColors.deepApricot,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timelineTile(BuildContext context, ElderTodayIntakeRecord r, bool isLast) {
    final icon = _statusIcon(r.status);
    final lineColor = ElderHomeColors.peach.withValues(alpha: 0.8);

    return InkWell(
      onTap: () => context.push('/elder/record/${r.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 26)),
                  if (!isLast)
                    Container(
                      width: 3,
                      height: 36,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: ElderHomeColors.peach.withValues(alpha: 0.55)),
                  boxShadow: [
                    BoxShadow(
                      color: ElderHomeColors.cardShadow.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.scheduledTime.hour.toString().padLeft(2, '0')}:${r.scheduledTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ElderHomeColors.textWarm,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.medicineName,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: ElderHomeColors.deepApricot,
                      ),
                    ),
                    Text(
                      '数量：${r.dosageLabel}',
                      style: const TextStyle(fontSize: 17, color: ElderHomeColors.textSoft),
                    ),
                    const SizedBox(height: 6),
                    _statusChip(r.status),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(IntakeRecordStatus s) {
    final (label, bg, fg) = switch (s) {
      IntakeRecordStatus.notified => ('已提醒，待处理', ElderHomeColors.gentleAmber.withValues(alpha: 0.45), ElderHomeColors.textWarm),
      IntakeRecordStatus.taken => ('已服下 ✓', ElderHomeColors.successLeaf.withValues(alpha: 0.25), ElderHomeColors.sageDeep),
      IntakeRecordStatus.snoozed => ('稍后再服', ElderHomeColors.softBlue.withValues(alpha: 0.45), ElderHomeColors.textWarm),
      IntakeRecordStatus.missed => ('没赶上，别太担心', ElderHomeColors.softPink.withValues(alpha: 0.6), ElderHomeColors.deepApricot),
      IntakeRecordStatus.skipped => ('今日不吃', ElderHomeColors.peach.withValues(alpha: 0.55), ElderHomeColors.deepApricot),
      IntakeRecordStatus.pending => ('待服用', ElderHomeColors.gentleAmber.withValues(alpha: 0.4), ElderHomeColors.textWarm),
      IntakeRecordStatus.deleted => ('已删除', ElderHomeColors.peach.withValues(alpha: 0.45), ElderHomeColors.textSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ElderHomeColors.peach.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: ElderHomeColors.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ElderHomeColors.textWarm)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 17, height: 1.35, color: ElderHomeColors.textSoft)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  String _statusIcon(IntakeRecordStatus s) {
    return switch (s) {
      IntakeRecordStatus.notified => '🔔',
      IntakeRecordStatus.taken => '✅',
      IntakeRecordStatus.snoozed => '⏳',
      IntakeRecordStatus.missed => '🌿',
      IntakeRecordStatus.skipped => '⏭️',
      IntakeRecordStatus.pending => '☀️',
      IntakeRecordStatus.deleted => '🗑️',
    };
  }
}
