import 'package:flutter/material.dart';

import '../models/elder_home_models.dart';
import '../theme/elder_home_colors.dart';

/// 今日服药主卡片：下一剂、进度、状态、主操作按钮
class ElderMainMedicationCard extends StatelessWidget {
  const ElderMainMedicationCard({
    super.key,
    required this.phase,
    required this.completedToday,
    required this.scheduledToday,
    required this.nextRecord,
    required this.snoozeMessage,
    required this.onTaken,
    required this.onSnooze,
    required this.onMissed,
    required this.onViewSchedule,
  });

  final ElderMainCardPhase phase;
  final int completedToday;
  final int scheduledToday;
  final ElderTodayIntakeRecord? nextRecord;
  final String? snoozeMessage;
  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onMissed;
  final VoidCallback onViewSchedule;

  @override
  Widget build(BuildContext context) {
    final progress = scheduledToday <= 0 ? 0.0 : completedToday / scheduledToday;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: phase == ElderMainCardPhase.allDone
              ? [const Color(0xFFE8F5E9), ElderHomeColors.sage.withValues(alpha: 0.5)]
              : [ElderHomeColors.peach, ElderHomeColors.softPink.withValues(alpha: 0.62)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: ElderHomeColors.cardShadow.withValues(alpha: 0.55),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💊', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _title(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ElderHomeColors.textWarm,
                  ),
                ),
              ),
            ],
          ),
          if (snoozeMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                snoozeMessage!,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: ElderHomeColors.deepApricot,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (phase == ElderMainCardPhase.allDone) ...[
            const Text(
              '🌟 今天的药都吃完啦，真棒！',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ElderHomeColors.textWarm,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '好好休息，明天我继续陪着您。',
              style: TextStyle(fontSize: 17, color: ElderHomeColors.textSoft),
            ),
          ] else if (nextRecord != null) ...[
            Text(
              '下一次：${_fmtTime(nextRecord!.scheduledTime)}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: ElderHomeColors.textWarm,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              nextRecord!.medicineName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: ElderHomeColors.deepApricot,
              ),
            ),
            Text(
              '数量：${nextRecord!.dosageLabel}',
              style: const TextStyle(fontSize: 18, color: ElderHomeColors.textSoft),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitleCountdown(nextRecord!),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ElderHomeColors.sageDeep,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _progressRow(completedToday, scheduledToday, progress),
          const SizedBox(height: 20),
          if (phase == ElderMainCardPhase.allDone)
            _bigButton(
              label: '查看今日安排',
              icon: Icons.calendar_today_rounded,
              color: ElderHomeColors.sageDeep,
              onTap: onViewSchedule,
            )
          else if (phase == ElderMainCardPhase.upcoming ||
              phase == ElderMainCardPhase.hasMissed)
            Row(
              children: [
                Expanded(
                  child: _bigButton(
                    label: '我已服药',
                    icon: Icons.check_circle_rounded,
                    color: ElderHomeColors.successLeaf,
                    onTap: onTaken,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _bigButton(
                    label: '稍后再服',
                    icon: Icons.schedule_rounded,
                    color: ElderHomeColors.softBlue,
                    foreground: ElderHomeColors.textWarm,
                    onTap: onSnooze,
                  ),
                ),
              ],
            )
          else if (phase == ElderMainCardPhase.dueNow)
            Row(
              children: [
                Expanded(
                  child: _bigButton(
                    label: '我已服药',
                    icon: Icons.check_circle_rounded,
                    color: ElderHomeColors.successLeaf,
                    onTap: onTaken,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _bigButton(
                    label: '今日不吃',
                    icon: Icons.close_rounded,
                    color: ElderHomeColors.deepApricot,
                    onTap: onMissed,
                  ),
                ),
              ],
            )
          else if (phase == ElderMainCardPhase.snoozed)
            Row(
              children: [
                Expanded(
                  child: _bigButton(
                    label: '我已服药',
                    icon: Icons.check_circle_rounded,
                    color: ElderHomeColors.successLeaf,
                    onTap: onTaken,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _bigButton(
                    label: '查看安排',
                    icon: Icons.list_alt_rounded,
                    color: ElderHomeColors.deepApricot,
                    onTap: onViewSchedule,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _title() {
    switch (phase) {
      case ElderMainCardPhase.allDone:
        return '今日服药已完成';
      case ElderMainCardPhase.dueNow:
        return '到点啦，该吃药啦';
      case ElderMainCardPhase.snoozed:
        return '先歇一会儿';
      case ElderMainCardPhase.hasMissed:
        return '有一剂没赶上，别灰心';
      case ElderMainCardPhase.upcoming:
        return '下一剂还早，先放心';
    }
  }

  String _subtitleCountdown(ElderTodayIntakeRecord r) {
    final now = DateTime.now();
    if (now.isBefore(r.scheduledTime)) {
      final d = r.scheduledTime.difference(now);
      if (d.inHours >= 1) {
        return '还有大约 ${d.inHours} 小时';
      }
      return '还有大约 ${d.inMinutes.clamp(1, 59)} 分钟';
    }
    return '已经到了计划时间，吃完点下面「我已服药」哦';
  }

  String _fmtTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _progressRow(int done, int total, double p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日已完成  $done / $total  次',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ElderHomeColors.textWarm,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: p.clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: Colors.white.withValues(alpha: 0.55),
            valueColor: const AlwaysStoppedAnimation<Color>(ElderHomeColors.deepApricot),
          ),
        ),
      ],
    );
  }

  Widget _bigButton({
    required String label,
    required IconData icon,
    required Color color,
    Color foreground = Colors.white,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 26),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
