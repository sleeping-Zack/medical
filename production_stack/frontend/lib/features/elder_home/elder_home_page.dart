import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_controller.dart';
import 'providers/elder_home_controller.dart';
import 'theme/elder_home_colors.dart';
import 'widgets/elder_family_section.dart';
import 'widgets/elder_main_medication_card.dart';
import 'widgets/elder_tip_footer.dart';
import 'widgets/elder_today_records_section.dart';
import 'widgets/elder_weekly_trend_card.dart';
import 'widgets/elder_welcome_header.dart';

/// 长辈端首页：温暖、大字号、信息完整（当前为 Mock + Riverpod，可接 API）
class ElderHomePage extends ConsumerWidget {
  const ElderHomePage({super.key, required this.shortId});

  final String shortId;

  String _encourageLine(ElderHomeState s) {
    final last = s.weeklyTrend.isNotEmpty ? s.weeklyTrend.last : null;
    if (last == null) return '这一周，您已经做得很认真啦';
    final pct = (last.rate * 100).round();
    if (pct >= 90) return '曲线往上走，说明您对自己特别用心';
    if (pct >= 60) return '有起有伏很正常，重要的是您还在坚持';
    return '咱们不和别人比，只要比昨天多一点点就好';
  }

  String? _phoneTailHint(String? phone) {
    final p = phone?.trim() ?? '';
    if (p.length < 4) return null;
    return '尾号 ${p.substring(p.length - 4)}';
  }

  String _companionLine(ElderHomeState s) {
    if (s.scheduledToday <= 0) {
      return '今天还没有用药计划，可以让家人帮您加好，我会按时提醒您。';
    }
    if (s.allDone) {
      return '今天的药都安排完啦，喝口温水，慢慢休息一会儿吧。';
    }
    final left = (s.scheduledToday - s.completedToday).clamp(0, 999);
    final next = s.nextPending;
    if (next != null) {
      final t = _fmtClock(next.scheduledTime);
      return '今天还剩 $left 次，下一剂约在 $t，我在这儿陪着您，别急。';
    }
    return '下面按时间列好了今天的每一次，您慢慢看就好。';
  }

  String _fmtClock(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final s = ref.watch(elderHomeControllerProvider);
    final ctrl = ref.read(elderHomeControllerProvider.notifier);
    final user = auth.user;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ElderHomeColors.blushTop,
            ElderHomeColors.blushMid,
            ElderHomeColors.warmWhite,
          ],
          stops: [0.0, 0.22, 0.55],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '药安心',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: ElderHomeColors.textWarm,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '您的用药小帮手',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ElderHomeColors.textSoft.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: auth.isBusy ? null : () => ref.read(authControllerProvider.notifier).logout(),
                        child: const Text(
                          '退出',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ElderWelcomeHeader(
                      companionLine: _companionLine(s),
                      phoneTailHint: _phoneTailHint(user?.phone),
                    ),
                    const SizedBox(height: 18),
                    if (shortId.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: ElderHomeColors.cream.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: ElderHomeColors.apricot.withValues(alpha: 0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ElderHomeColors.cardShadow.withValues(alpha: 0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Text('🔗', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '给子女看的绑定短号',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: ElderHomeColors.textSoft,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    shortId,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 6,
                                      color: ElderHomeColors.deepApricot,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '告诉孩子这几个数字，他们就能在手机上关心您啦',
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: ElderHomeColors.sageDeep,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ElderMainMedicationCard(
                      phase: s.mainPhase,
                      completedToday: s.completedToday,
                      scheduledToday: s.scheduledToday,
                      nextRecord: s.nextPending,
                      snoozeMessage: s.snoozeMessage,
                      onTaken: () {
                        ctrl.clearSnoozeBanner();
                        ctrl.markNextTaken();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('记下来了，您真棒！'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onSnooze: () {
                        ctrl.snoozeTenMinutes();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('好的，稍后再提醒您～'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onViewSchedule: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('完整日程页即将接入，先在下面看看今天的记录吧'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    ElderTodayRecordsSection(records: s.todayRecords),
                    const SizedBox(height: 22),
                    ElderWeeklyTrendCard(
                      trend: s.weeklyTrend,
                      streakDays: s.streakDays,
                      encourageLine: _encourageLine(s),
                    ),
                    const SizedBox(height: 22),
                    ElderFamilySection(members: s.familyMembers),
                    const SizedBox(height: 22),
                    const ElderTipFooter(),
                    const SizedBox(height: 36),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
