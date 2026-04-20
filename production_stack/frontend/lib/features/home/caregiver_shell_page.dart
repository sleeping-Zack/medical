import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import 'app_settings_sheet.dart';
import '../../core/providers.dart';
import '../auth/providers/auth_controller.dart';
import '../care/models/adherence_point.dart';
import '../care/models/bound_elder.dart';
import '../care/models/medicine_item.dart';
import '../care/models/plan_item.dart';
import '../care/models/reminder_item.dart';
import '../care/pages/medicine_list_page.dart';
import '../care/providers/care_remote_providers.dart';
import '../care/services/reminder_notification_service.dart';
import '../care/widgets/responsive_adherence_line_chart.dart';

/// 与 Web `App.tsx` 看护端一致：顶栏 + 主区按 Tab 切换 + 底部四键「首页 / 药品 / 计划 / 家人」。
class CaregiverShellPage extends ConsumerStatefulWidget {
  const CaregiverShellPage({super.key});

  @override
  ConsumerState<CaregiverShellPage> createState() => _CaregiverShellPageState();
}

class _CaregiverShellPageState extends ConsumerState<CaregiverShellPage> {
  int _tabIndex = 0;
  int _careTargetUserId = 0;

  final _bindShort = TextEditingController();
  final _bindLast4 = TextEditingController();
  bool _binding = false;

  static const _kWarmTop = Color(0xFFFFE8DC);
  static const _kWarmMid = Color(0xFFFFF0E6);
  static const _kWarmBottom = Color(0xFFFFFBF5);
  static const _kBrown = Color(0xFF5C4A3D);
  static const _kBrownSoft = Color(0xFF8B7A6E);
  static const _kOrange = Color(0xFFE8863D);
  static const _kGreen = Color(0xFF7CB87C);
  static const _kPeachBorder = Color(0xFFFFE4CC);

  @override
  void initState() {
    super.initState();
    final id = ref.read(authControllerProvider).user?.id;
    if (id != null) _careTargetUserId = id;
    void bump() {
      if (mounted) setState(() {});
    }

    _bindShort.addListener(bump);
    _bindLast4.addListener(bump);
  }

  @override
  void dispose() {
    _bindShort.dispose();
    _bindLast4.dispose();
    super.dispose();
  }

  int _resolveTarget(int selfId, List<BoundElder> elders) {
    if (_careTargetUserId == selfId) return selfId;
    final ok = elders.any((e) => e.canManageMedicine && e.elderId == _careTargetUserId);
    return ok ? _careTargetUserId : selfId;
  }

  String _careLabel(int selfId, List<BoundElder> elders, String phone) {
    final t = _resolveTarget(selfId, elders);
    if (t == selfId) {
      final tail = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
      return '本人（用户$tail）';
    }
    final m = elders.where((e) => e.elderId == t).toList();
    if (m.isEmpty) return '家人';
    return '家人 · 短号 ${m.first.shortId}';
  }

  Future<void> _markReminder(ReminderItem r, String action) async {
    final repo = ref.read(careRepositoryProvider);
    await repo.markReminder(
      targetUserId: r.targetUserId,
      planId: r.planId,
      scheduleId: r.scheduleId,
      dueTime: r.dueTime,
      action: action,
    );
    ref.invalidate(remindersForTargetTodayProvider(r.targetUserId));
    ref.invalidate(adherenceForTargetProvider(r.targetUserId));
  }

  void _openSettings(BuildContext context) {
    showAppSettingsSheet(context, ref, showPersonalModeToggle: true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user!;
    final selfId = user.id;
    final phone = user.phone;

    ref.listen(authControllerProvider, (p, n) {
      final nid = n.user?.id;
      if (nid != null && p?.user?.id != nid) setState(() => _careTargetUserId = nid);
    });

    final eldersAsync = ref.watch(boundEldersProvider);
    final eldersList = eldersAsync.asData?.value ?? const <BoundElder>[];
    final resolved = _resolveTarget(selfId, eldersList);
    if (resolved != _careTargetUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _careTargetUserId = resolved);
      });
    }

    // 看护端首页也会展示今日提醒：必须把同一批实例注册成本地通知（否则只有进长辈首页才会响）
    ref.listen<AsyncValue<List<ReminderItem>>>(remindersForTargetTodayProvider(resolved), (prev, next) {
      next.whenData((rows) {
        Future<void>.microtask(() async {
          try {
            await ref.read(reminderNotificationServiceProvider).syncTodayReminders(reminders: rows);
          } catch (_) {}
        });
      });
    });

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kWarmTop, _kWarmMid, _kWarmBottom],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _AppHeader(
                onBell: () {},
                onUser: () => _openSettings(context),
              ),
              Expanded(
                child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _HomeTab(
                        eldersAsync: eldersAsync,
                        selfId: selfId,
                        phone: phone,
                        resolved: resolved,
                        careLabel: _careLabel(selfId, eldersList, phone),
                        onCareTargetChanged: (v) => setState(() => _careTargetUserId = v),
                        reminders: ref.watch(remindersForTargetTodayProvider(resolved)),
                        onConfirm: (r) => _markReminder(r, 'taken'),
                        onDelete: (r) => _markReminder(r, 'deleted'),
                        onAddMed: () async {
                          final ok = await context.push<bool>('/care/medicines/new?target=$resolved');
                          if (ok == true && mounted) ref.invalidate(medicinesForTargetProvider(resolved));
                        },
                        onAddPlan: () async {
                          final ok = await context.push<bool>('/care/plans/new?target=$resolved');
                          if (ok == true && mounted) {
                            ref.invalidate(plansForTargetProvider(resolved));
                            ref.invalidate(remindersForTargetTodayProvider(resolved));
                          }
                        },
                        kBrown: _kBrown,
                        kBrownSoft: _kBrownSoft,
                        kOrange: _kOrange,
                        kGreen: _kGreen,
                        kPeachBorder: _kPeachBorder,
                      ),
                      _MedicinesTabBody(
                        targetUserId: resolved,
                        selfId: selfId,
                        careLabel: _careLabel(selfId, eldersList, phone),
                        kBrown: _kBrown,
                        kBrownSoft: _kBrownSoft,
                        kOrange: _kOrange,
                        kPeach: _kPeachBorder,
                      ),
                      _PlansTabBody(targetUserId: resolved, kBrown: _kBrown, kBrownSoft: _kBrownSoft, kOrange: _kOrange, kPeach: _kPeachBorder),
                      _FamilyTabBody(
                        bindShort: _bindShort,
                        bindLast4: _bindLast4,
                        binding: _binding,
                        eldersAsync: eldersAsync,
                        onBind: () => _submitBind(context),
                        onManageElder: (elderId) {
                          setState(() {
                            _careTargetUserId = elderId;
                            _tabIndex = 1;
                          });
                        },
                        kBrown: _kBrown,
                        kBrownSoft: _kBrownSoft,
                        kOrange: _kOrange,
                        kPeach: _kPeachBorder,
                        kGreen: _kGreen,
                      ),
                    ],
                  ),
              ),
              const SizedBox(height: 8),
              _BottomCareNav(
                index: _tabIndex,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitBind(BuildContext context) async {
    if (_bindShort.text.length != 6 || _bindLast4.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写 6 位 ID 与手机后四位')));
      return;
    }
    setState(() => _binding = true);
    try {
      await ref.read(careRepositoryProvider).createBinding(
            elderShortId: _bindShort.text.trim(),
            phoneLast4: _bindLast4.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(boundEldersProvider);
      _bindShort.clear();
      _bindLast4.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('绑定成功')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('绑定失败')));
    } finally {
      if (mounted) setState(() => _binding = false);
    }
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.onBell, required this.onUser});

  final VoidCallback onBell;
  final VoidCallback onUser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8863D),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFFE8863D).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.medication_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('药安心', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF5C4A3D), height: 1.1)),
                Text('看护端 · 陪家人好好吃药', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8B7A6E))),
              ],
            ),
          ),
          IconButton(onPressed: onBell, icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF5C4A3D), size: 26)),
          Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: Color(0xFFFFE4CC), width: 2)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onUser,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.person_rounded, color: Color(0xFF8B7A6E), size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCareNav extends StatelessWidget {
  const _BottomCareNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFFE4CC)),
          boxShadow: [BoxShadow(color: Colors.orange.shade900.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavBtn(icon: Icons.dashboard_rounded, label: '首页', active: index == 0, onTap: () => onChanged(0)),
            _NavBtn(icon: Icons.medication_liquid_rounded, label: '药品', active: index == 1, onTap: () => onChanged(1)),
            _NavBtn(icon: Icons.calendar_month_rounded, label: '计划', active: index == 2, onTap: () => onChanged(2)),
            _NavBtn(icon: Icons.groups_rounded, label: '家人', active: index == 3, onTap: () => onChanged(3)),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = active ? const Color(0xFFE8863D) : const Color(0xFF8B7A6E);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFFFE4CC).withValues(alpha: 0.9) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)] : null,
              ),
              child: Icon(icon, size: 24, color: c),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.eldersAsync,
    required this.selfId,
    required this.phone,
    required this.resolved,
    required this.careLabel,
    required this.onCareTargetChanged,
    required this.reminders,
    required this.onConfirm,
    required this.onDelete,
    required this.onAddMed,
    required this.onAddPlan,
    required this.kBrown,
    required this.kBrownSoft,
    required this.kOrange,
    required this.kGreen,
    required this.kPeachBorder,
  });

  final AsyncValue<List<BoundElder>> eldersAsync;
  final int selfId;
  final String phone;
  final int resolved;
  final String careLabel;
  final ValueChanged<int> onCareTargetChanged;
  final AsyncValue<List<ReminderItem>> reminders;
  final void Function(ReminderItem) onConfirm;
  final void Function(ReminderItem) onDelete;
  final VoidCallback onAddMed;
  final VoidCallback onAddPlan;
  final Color kBrown;
  final Color kBrownSoft;
  final Color kOrange;
  final Color kGreen;
  final Color kPeachBorder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        eldersAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (e, _) => Text(e is ApiException ? e.message : '加载失败'),
          data: (elders) => _careTargetCard(context, elders),
        ),
        const SizedBox(height: 16),
        _greeting(),
        const SizedBox(height: 16),
        reminders.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (e, _) => Text(e is ApiException ? e.message : '加载失败'),
          data: (rows) => _stats(rows),
        ),
        const SizedBox(height: 8),
        reminders.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (rows) => _scheduleSection(context, rows),
        ),
        const SizedBox(height: 16),
        _quickActions(context),
      ],
    );
  }

  Widget _careTargetCard(BuildContext context, List<BoundElder> elders) {
    return _warmCard(
      kPeachBorder,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前关心的人', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kBrown)),
          const SizedBox(height: 6),
          Text(
            '切换后，首页日程、药品与计划都会跟着变；可以管自己，也可以帮已绑定的长辈远程打理。',
            style: TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w500, color: kBrownSoft.withValues(alpha: 0.95)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: resolved,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFFFF8F0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: kPeachBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: kPeachBorder)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              DropdownMenuItem(
                value: selfId,
                child: Text(
                  '本人（${phone.length >= 4 ? phone.substring(phone.length - 4) : phone}）',
                  style: TextStyle(fontWeight: FontWeight.w700, color: kBrown),
                ),
              ),
              ...elders.where((e) => e.canManageMedicine).map(
                    (e) => DropdownMenuItem(
                      value: e.elderId,
                      child: Text('家人 · 短号 ${e.shortId}', style: TextStyle(fontWeight: FontWeight.w700, color: kBrown)),
                    ),
                  ),
            ],
            onChanged: (v) {
              if (v != null) onCareTargetChanged(v);
            },
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBrownSoft.withValues(alpha: 0.9)),
              children: [
                const TextSpan(text: '现在在看：'),
                TextSpan(text: careLabel, style: TextStyle(color: kOrange, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _warmCard(Color border, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border.withValues(alpha: 0.9)),
        boxShadow: [BoxShadow(color: Colors.orange.shade900.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _greeting() {
    final tail = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
    final name = '用户$tail';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('您好，$name', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kBrown, height: 1.2)),
              const SizedBox(height: 4),
              Text('今天也一起把用药安排得明明白白', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBrownSoft.withValues(alpha: 0.92))),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE4CC),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(name.characters.take(2).string, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kOrange)),
        ),
      ],
    );
  }

  Widget _stats(List<ReminderItem> reminders) {
    final total = reminders.length;
    final pct = total > 0 ? ((reminders.where((r) => r.status == 'taken').length / total) * 100).round() : 0;
    final pending = reminders.where((r) => r.status == 'pending').length;
    return Row(
      children: [
        Expanded(child: _statCard(kPeachBorder, kBrown, kBrownSoft, Icons.check_circle_outline, const Color(0xFF5A9A5A), kGreen.withValues(alpha: 0.2), '$pct%', '今日完成度')),
        const SizedBox(width: 12),
        Expanded(child: _statCard(kPeachBorder, kBrown, kBrownSoft, Icons.error_outline_rounded, const Color(0xFFC96D2E), const Color(0xFFF4C95D).withValues(alpha: 0.35), '$pending', '还有待确认')),
      ],
    );
  }

  Widget _statCard(Color peach, Color brown, Color soft, IconData icon, Color iconColor, Color iconBg, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: peach.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: brown, height: 1)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: soft.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _scheduleSection(BuildContext context, List<ReminderItem> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('今日日程', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kBrown)),
              const Text('按时间排好了', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8FA894))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFFFB366).withValues(alpha: 0.55), width: 1.2),
            ),
            child: Text(
              '今天还没有提醒，加个计划或药品吧～',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kBrownSoft.withValues(alpha: 0.95)),
            ),
          )
        else
          ...rows.map((rem) => _RemTile(rem: rem, kBrown: kBrown, kBrownSoft: kBrownSoft, kOrange: kOrange, kGreen: kGreen, kPeach: kPeachBorder, onConfirm: onConfirm, onDelete: onDelete)),
      ],
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAddMed,
              borderRadius: BorderRadius.circular(26),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE8863D), Color(0xFFD97830)]),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: kOrange.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 30),
                      SizedBox(height: 6),
                      Text('添加药品', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAddPlan,
              borderRadius: BorderRadius.circular(26),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: kPeachBorder.withValues(alpha: 0.85)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.calendar_month_rounded, color: kOrange, size: 30),
                    const SizedBox(height: 6),
                    Text('新建计划', style: TextStyle(color: kBrown, fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RemTile extends StatelessWidget {
  const _RemTile({
    required this.rem,
    required this.kBrown,
    required this.kBrownSoft,
    required this.kOrange,
    required this.kGreen,
    required this.kPeach,
    required this.onConfirm,
    required this.onDelete,
  });

  final ReminderItem rem;
  final Color kBrown;
  final Color kBrownSoft;
  final Color kOrange;
  final Color kGreen;
  final Color kPeach;
  final void Function(ReminderItem) onConfirm;
  final void Function(ReminderItem) onDelete;

  @override
  Widget build(BuildContext context) {
    final taken = rem.status == 'taken';
    final t = TimeOfDay(hour: rem.dueTime.hour, minute: rem.dueTime.minute).format(context);
    final badge = rem.status == 'taken'
        ? '已服'
        : rem.status == 'missed'
            ? '未服'
            : rem.status == 'snoozed'
                ? '已延后'
                : '待服';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kPeach.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: taken ? kGreen.withValues(alpha: 0.2) : const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.medication_liquid_rounded, color: taken ? const Color(0xFF5A9A5A) : kOrange, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rem.medicineName.isEmpty ? '药品' : rem.medicineName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBrown)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 15, color: kBrownSoft.withValues(alpha: 0.85)),
                    const SizedBox(width: 4),
                    Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBrownSoft.withValues(alpha: 0.9))),
                  ],
                ),
              ],
            ),
          ),
          if (rem.status == 'pending')
            IconButton(
              tooltip: '确认已吃',
              onPressed: () => onConfirm(rem),
              style: IconButton.styleFrom(backgroundColor: kGreen.withValues(alpha: 0.2), foregroundColor: const Color(0xFF3D7A3D)),
              icon: const Icon(Icons.check_rounded, size: 22),
            ),
          IconButton(
            tooltip: '删除日程',
            onPressed: () => onDelete(rem),
            style: IconButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade600),
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: taken ? kGreen : const Color(0xFFFFE4CC), borderRadius: BorderRadius.circular(999)),
            child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: taken ? Colors.white : const Color(0xFF8B4513))),
          ),
        ],
      ),
    );
  }
}

class _MedicinesTabBody extends ConsumerWidget {
  const _MedicinesTabBody({
    required this.targetUserId,
    required this.selfId,
    required this.careLabel,
    required this.kBrown,
    required this.kBrownSoft,
    required this.kOrange,
    required this.kPeach,
  });

  final int targetUserId;
  final int selfId;
  final String careLabel;
  final Color kBrown;
  final Color kBrownSoft;
  final Color kOrange;
  final Color kPeach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(medicinesForTargetProvider(targetUserId));
    final label = targetUserId == selfId ? '我的药品' : '${careLabel.split('（').first}的药品';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kBrown, height: 1.1))),
            Material(
              color: kOrange,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () async {
                  final ok = await context.push<bool>('/care/medicines/new?target=$targetUserId');
                  if (ok == true && context.mounted) ref.invalidate(medicinesForTargetProvider(targetUserId));
                },
                child: const Padding(padding: EdgeInsets.all(14), child: Icon(Icons.add, color: Colors.white, size: 26)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          readOnly: true,
          onTap: () {},
          decoration: InputDecoration(
            hintText: '搜索药品…',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.95),
            prefixIcon: Icon(Icons.search, color: kOrange.withValues(alpha: 0.55)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: kPeach)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: kPeach)),
          ),
        ),
        const SizedBox(height: 16),
        async.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Text(e is ApiException ? e.message : '加载失败'),
          data: (list) {
            if (list.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFFFB366).withValues(alpha: 0.45), style: BorderStyle.solid),
                ),
                child: Text('还没有药品，点右上角加一颗吧', textAlign: TextAlign.center, style: TextStyle(color: kBrownSoft, fontWeight: FontWeight.w500)),
              );
            }
            return Column(
              children: list.map((med) => _medCard(context, ref, med)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _medCard(BuildContext context, WidgetRef ref, MedicineItem med) {
    final sub = [if (med.specification != null && med.specification!.isNotEmpty) med.specification!].join();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kPeach.withValues(alpha: 0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPeach),
            ),
            child: Icon(Icons.medication_liquid_rounded, color: kOrange, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: kBrown)),
                if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 13, color: kBrownSoft, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: kBrownSoft),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('编辑药品将后续与 Web 表单对齐')));
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: kBrownSoft),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除药品请在后端管理端操作或后续接入')));
            },
          ),
        ],
      ),
    );
  }
}

class _PlansTabBody extends ConsumerWidget {
  const _PlansTabBody({required this.targetUserId, required this.kBrown, required this.kBrownSoft, required this.kOrange, required this.kPeach});

  final int targetUserId;
  final Color kBrown;
  final Color kBrownSoft;
  final Color kOrange;
  final Color kPeach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansForTargetProvider(targetUserId));
    final remAsync = ref.watch(remindersForTargetTodayProvider(targetUserId));
    final adhAsync = ref.watch(adherenceForTargetProvider(targetUserId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Row(
          children: [
            const Expanded(child: Text('健康与计划', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF5C4A3D)))),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () async {
                final ok = await context.push<bool>('/care/plans/new?target=$targetUserId');
                if (ok == true && context.mounted) {
                  ref.invalidate(plansForTargetProvider(targetUserId));
                  ref.invalidate(remindersForTargetTodayProvider(targetUserId));
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新计划', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _achievementCard(kBrown, kBrownSoft, kOrange, kPeach),
        const SizedBox(height: 16),
        _adherenceCard(adhAsync, kBrown, kBrownSoft, kOrange, kPeach),
        const SizedBox(height: 20),
        Text('正在进行的计划', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kBrown)),
        const SizedBox(height: 10),
        plansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(e is ApiException ? e.message : '加载失败'),
          data: (plans) => remAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (rems) => _planAggList(plans, rems, kBrown, kBrownSoft, kOrange, kPeach),
          ),
        ),
      ],
    );
  }

  Widget _achievementCard(Color brown, Color soft, Color orange, Color peach) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFFF8F0), peach.withValues(alpha: 0.55), const Color(0xFFFFD6CC).withValues(alpha: 0.35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFFFB366).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('陪伴小成就', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFFC96D2E))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: peach),
                ),
                child: Text('加油中', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: orange)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('1,280', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: brown, height: 1)),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 6),
                child: Text('分', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: soft)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('每一次按时确认，都是对家人温柔的支持～', style: TextStyle(fontSize: 13, color: soft, fontWeight: FontWeight.w500, height: 1.35)),
          const SizedBox(height: 12),
          Container(
            height: 10,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(999), border: Border.all(color: peach.withValues(alpha: 0.5))),
            child: FractionallySizedBox(
              widthFactor: 0.75,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(colors: [orange, const Color(0xFFF4C95D)]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adherenceCard(AsyncValue<List<AdherencePoint>> async, Color brown, Color soft, Color orange, Color peach) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFFF7EE), const Color(0xFFFFECD8).withValues(alpha: 0.85), const Color(0xFFFFE3C9).withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFFFDDBE).withValues(alpha: 0.9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('服药依从性', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: brown)),
                  Text('过去 7 天完成率', style: TextStyle(fontSize: 13, color: soft, fontWeight: FontWeight.w500)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7CB87C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF7CB87C).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up_rounded, size: 15, color: Colors.green.shade800),
                    const SizedBox(width: 4),
                    Text('稳步', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green.shade800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text(e is ApiException ? e.message : '加载失败'),
            data: (rows) {
              if (rows.isEmpty) return const SizedBox(height: 120, child: Center(child: Text('暂无趋势数据')));
              final yPercent = rows.map((e) => e.rate.toDouble()).toList();
              final bottomLabels = rows.map((e) => '${e.date.month}/${e.date.day}').toList();
              return ResponsiveAdherenceLineChart(
                yPercent: yPercent,
                bottomLabels: bottomLabels,
                lineColor: orange,
                gridColor: const Color(0xFFFFD9BA).withValues(alpha: 0.9),
                leftTitleColor: soft,
                bottomTitleColor: soft,
                belowGradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromRGBO(34, 197, 94, 0.4),
                    Color.fromRGBO(59, 130, 246, 0.34),
                    Color.fromRGBO(255, 255, 255, 0.24),
                    Color.fromRGBO(239, 68, 68, 0.3),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _planAggList(List<PlanItem> plans, List<ReminderItem> rems, Color brown, Color soft, Color orange, Color peach) {
    if (plans.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFFFB366).withValues(alpha: 0.45), style: BorderStyle.solid),
        ),
        child: Text('暂无进行中的计划', textAlign: TextAlign.center, style: TextStyle(color: soft, fontWeight: FontWeight.w500)),
      );
    }
    final byMed = <int, _Agg>{};
    for (final p in plans) {
      byMed.putIfAbsent(p.medicineId, () => _Agg(medicineId: p.medicineId, planIds: [], status: p.status, name: p.medicineName));
      byMed[p.medicineId]!.planIds.add(p.id);
      if (p.status == 'active') byMed[p.medicineId]!.status = 'active';
    }
    for (final a in byMed.values) {
      a.totalSchedules = rems.where((r) => a.planIds.contains(r.planId)).length;
    }
    final list = byMed.values.toList();
    return Column(
      children: list.asMap().entries.map((e) {
        final idx = e.key;
        final agg = e.value;
        final medName = plans.firstWhere((p) => p.medicineId == agg.medicineId, orElse: () => plans.first).medicineName;
        final medicineRems = rems.where((r) => agg.planIds.contains(r.planId)).toList();
        final taken = medicineRems.where((r) => r.status == 'taken').length;
        final total = medicineRems.length;
        final rate = total > 0 ? ((taken / total) * 100).round() : 0;
        final highlight = idx == 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: highlight ? const LinearGradient(colors: [Color(0xFFE8863D), Color(0xFFD97830)]) : null,
            color: highlight ? null : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: highlight ? const Color(0xFFE8863D) : peach.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: highlight ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(16),
                  border: highlight ? null : Border.all(color: peach),
                ),
                child: Icon(Icons.medication_liquid_rounded, color: highlight ? Colors.white : orange, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(medName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: highlight ? Colors.white : brown)),
                    const SizedBox(height: 4),
                    Text(
                      '今日共 ${agg.totalSchedules} 次 · ${agg.status == 'active' ? '进行中' : '已暂停'}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: highlight ? Colors.white.withValues(alpha: 0.85) : soft),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: highlight ? Colors.white : const Color(0xFFFFF8F0),
                  shape: BoxShape.circle,
                  border: highlight ? null : Border.all(color: peach),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$rate%', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: highlight ? orange : soft)),
                    Text('今日', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: highlight ? orange.withValues(alpha: 0.85) : soft.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Agg {
  _Agg({required this.medicineId, required this.planIds, required this.status, required this.name});
  final int medicineId;
  final List<int> planIds;
  String status;
  final String name;
  int totalSchedules = 0;
}

class _FamilyTabBody extends StatelessWidget {
  const _FamilyTabBody({
    required this.bindShort,
    required this.bindLast4,
    required this.binding,
    required this.eldersAsync,
    required this.onBind,
    required this.onManageElder,
    required this.kBrown,
    required this.kBrownSoft,
    required this.kOrange,
    required this.kPeach,
    required this.kGreen,
  });

  final TextEditingController bindShort;
  final TextEditingController bindLast4;
  final bool binding;
  final AsyncValue<List<BoundElder>> eldersAsync;
  final VoidCallback onBind;
  final void Function(int elderUserId) onManageElder;
  final Color kBrown;
  final Color kBrownSoft;
  final Color kOrange;
  final Color kPeach;
  final Color kGreen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('家人绑定', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kBrown)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: kPeach),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '输入长辈的 6 位 ID 和手机尾号后四位，就能陪 Ta 一起管理用药啦。',
                style: TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w500, color: kBrownSoft),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: bindShort,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '长辈的 6 位 ID',
                  filled: true,
                  fillColor: const Color(0xFFFFF8F0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: kPeach)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bindLast4,
                maxLength: 4,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '长辈手机尾号后 4 位',
                  filled: true,
                  fillColor: const Color(0xFFFFF8F0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: kPeach)),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: binding || bindShort.text.length != 6 || bindLast4.text.length != 4 ? null : onBind,
                child: Text(binding ? '绑定中…' : '确认绑定', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text('已绑定的长辈', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kBrown)),
        const SizedBox(height: 10),
        eldersAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, _) => Text(e is ApiException ? e.message : '加载失败'),
          data: (elders) {
            if (elders.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFFFB366).withValues(alpha: 0.45), style: BorderStyle.solid),
                ),
                child: Text('还没有绑定，填上面信息即可邀请长辈', textAlign: TextAlign.center, style: TextStyle(color: kBrownSoft, fontSize: 13, fontWeight: FontWeight.w500)),
              );
            }
            return Column(
              children: elders.map((b) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: kPeach.withValues(alpha: 0.8)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4CC).withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text('长辈', style: TextStyle(fontWeight: FontWeight.w900, color: kBrown, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('家人 ${b.phoneMasked}', style: TextStyle(fontWeight: FontWeight.w700, color: kBrown)),
                            Text('短号 ${b.shortId}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBrownSoft)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: kGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: kGreen.withValues(alpha: 0.25)),
                            ),
                            child: Text('已绑定', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green.shade800)),
                          ),
                          if (b.canManageMedicine)
                            TextButton(
                              onPressed: () => onManageElder(b.elderId),
                              child: const Text('管理用药 →', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
