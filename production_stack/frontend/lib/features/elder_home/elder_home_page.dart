import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/providers/auth_controller.dart';
import 'providers/elder_home_controller.dart';
import 'theme/elder_home_colors.dart';
import 'widgets/elder_care_plans_section.dart';
import 'widgets/elder_family_section.dart';
import 'widgets/elder_main_medication_card.dart';
import 'widgets/elder_tip_footer.dart';
import 'widgets/elder_today_records_section.dart';
import 'widgets/elder_weekly_trend_card.dart';
import 'widgets/elder_welcome_header.dart';

/// 长辈端首页：温暖、大字号、信息完整（当前为 Mock + Riverpod，可接 API）。
/// [onOpenSettings] 与 Web 长辈顶栏「设置」一致；家属端切到长辈模式时传入以打开设置（含切回看护人）。
class ElderHomePage extends ConsumerStatefulWidget {
  const ElderHomePage({super.key, required this.shortId, this.onOpenSettings});

  final String shortId;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<ElderHomePage> createState() => _ElderHomePageState();
}

class _ElderHomePageState extends ConsumerState<ElderHomePage> with WidgetsBindingObserver {
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // StateNotifier 在「看护 ↔ 长辈」切换时不会销毁，仅依赖构造器里 microtask 会永远拿不到新计划/提醒
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(elderHomeControllerProvider.notifier).refreshFromApi();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(elderHomeControllerProvider.notifier).refreshFromApi();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              '长辈版 · 大字好读',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ElderHomeColors.textSoft.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onOpenSettings != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: ElderHomeColors.textWarm,
                              backgroundColor: Colors.white.withValues(alpha: 0.92),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: ElderHomeColors.apricot.withValues(alpha: 0.55)),
                              ),
                            ),
                            onPressed: widget.onOpenSettings,
                            icon: const Icon(Icons.settings_outlined, size: 22),
                            label: const Text('设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      TextButton(
                        onPressed: auth.isBusy ? null : () => ref.read(authControllerProvider.notifier).logout(),
                        style: TextButton.styleFrom(
                          foregroundColor: ElderHomeColors.textWarm,
                          backgroundColor: Colors.white.withValues(alpha: 0.92),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: ElderHomeColors.apricot.withValues(alpha: 0.55)),
                          ),
                        ),
                        child: const Text(
                          '退出',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                    ElderCarePlansSection(plans: s.carePlans, loading: s.loading),
                    const SizedBox(height: 18),
                    if (widget.shortId.isNotEmpty)
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
                                    widget.shortId,
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
                      onMissed: () {
                        final next = s.nextPending;
                        if (next != null) {
                          ctrl.skipById(next.id);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已记为今日不吃，这一剂今天不再提醒'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onViewSchedule: () {
                        final next = s.nextPending;
                        if (next != null) {
                          context.push('/elder/reminder/${Uri.encodeComponent(next.id)}');
                        }
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
