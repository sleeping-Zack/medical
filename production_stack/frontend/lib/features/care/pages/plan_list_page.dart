import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../models/adherence_point.dart';
import '../models/reminder_item.dart';
import '../providers/care_remote_providers.dart';
import '../widgets/responsive_adherence_line_chart.dart';

class PlanListPage extends ConsumerWidget {
  const PlanListPage({super.key, required this.targetUserId});

  final int targetUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(plansForTargetProvider(targetUserId));
    final remindersAsync = ref.watch(remindersForTargetTodayProvider(targetUserId));
    final adherenceAsync = ref.watch(adherenceForTargetProvider(targetUserId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('服药计划'),
        actions: [
          TextButton(
            onPressed: () => context.push('/care/medicines?target=$targetUserId'),
            child: const Text('药品'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await context.push<bool>('/care/plans/new?target=$targetUserId');
          if (ok == true && context.mounted) {
            ref.invalidate(plansForTargetProvider(targetUserId));
            ref.invalidate(remindersForTargetTodayProvider(targetUserId));
            ref.invalidate(adherenceForTargetProvider(targetUserId));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('新建计划'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e is ApiException ? e.message : '加载失败')),
        data: (list) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(plansForTargetProvider(targetUserId));
              ref.invalidate(remindersForTargetTodayProvider(targetUserId));
              ref.invalidate(adherenceForTargetProvider(targetUserId));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: (list.isEmpty ? 1 : list.length) + 2,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _buildAdherenceCard(context, adherenceAsync);
                }
                if (i == 1) {
                  return _buildTodayRemindersCard(context, ref, remindersAsync);
                }
                if (list.isEmpty && i == 2) {
                  return const ListTile(
                    title: Text('暂无计划，请先添加药品再创建计划。'),
                  );
                }
                final p = list[i - 2];
                final times = p.schedulesJson
                    .map((s) {
                      if (s is Map<String, dynamic>) {
                        final h = s['hour'];
                        final m = s['minute'];
                        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
                      }
                      return '';
                    })
                    .where((x) => x.isNotEmpty)
                    .join('、');
                return ListTile(
                  tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(p.medicineName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('开始 ${p.startDate} · $times · ${p.status}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayRemindersCard(BuildContext context, WidgetRef ref, AsyncValue<List<ReminderItem>> async) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今日日程', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(e is ApiException ? e.message : '加载失败'),
              data: (rows) {
                if (rows.isEmpty) return const Text('今天还没有提醒记录。');
                return Column(
                  children: rows.map((r) {
                    final statusText = switch (r.status) {
                      'taken' => '已服',
                      'snoozed' => '已延后',
                      'missed' => '未服',
                      _ => '待服',
                    };
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        title: Text('${r.medicineName} · ${_hhmm(r.dueTime)}'),
                        subtitle: Text(statusText),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            if (r.status == 'pending')
                              IconButton(
                                tooltip: '确认已服',
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () => _markAction(ref, r, 'taken'),
                              ),
                            if (r.status == 'pending')
                              IconButton(
                                tooltip: '稍后10分钟',
                                icon: const Icon(Icons.schedule),
                                onPressed: () => _snooze(ref, r),
                              ),
                            if (r.status == 'pending')
                              IconButton(
                                tooltip: '今日不吃',
                                icon: const Icon(Icons.close),
                                onPressed: () => _markAction(ref, r, 'missed'),
                              ),
                            IconButton(
                              tooltip: '删除本次提醒',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _markAction(ref, r, 'deleted'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAction(WidgetRef ref, ReminderItem r, String action) async {
    final repo = ref.read(careRepositoryProvider);
    await repo.markReminder(
      targetUserId: r.targetUserId,
      planId: r.planId,
      scheduleId: r.scheduleId,
      dueTime: r.dueTime,
      action: action,
    );
    ref.invalidate(remindersForTargetTodayProvider(targetUserId));
    ref.invalidate(adherenceForTargetProvider(targetUserId));
  }

  Future<void> _snooze(WidgetRef ref, ReminderItem r) async {
    final repo = ref.read(careRepositoryProvider);
    await repo.snoozeReminder(
      targetUserId: r.targetUserId,
      planId: r.planId,
      scheduleId: r.scheduleId,
      dueTime: r.dueTime,
      snoozeMinutes: 10,
    );
    ref.invalidate(remindersForTargetTodayProvider(targetUserId));
    ref.invalidate(adherenceForTargetProvider(targetUserId));
  }

  Widget _buildAdherenceCard(BuildContext context, AsyncValue<List<AdherencePoint>> async) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('服药依从性', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('过去7天完成率（真实数据）'),
            const SizedBox(height: 10),
            async.when(
              loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text(e is ApiException ? e.message : '加载失败'),
              data: (rows) {
                if (rows.isEmpty) return const Text('暂无趋势数据');
                final yPercent = rows.map((e) => e.rate.toDouble()).toList();
                final bottomLabels = rows.map((e) => '${e.date.month}/${e.date.day}').toList();
                return ResponsiveAdherenceLineChart(
                  yPercent: yPercent,
                  bottomLabels: bottomLabels,
                  lineColor: const Color(0xFFE8863D),
                  gridColor: const Color(0xFFFFD9BA),
                  leftTitleColor: const Color(0xFF8B7A6E),
                  bottomTitleColor: const Color(0xFF8B7A6E),
                  belowGradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromRGBO(34, 197, 94, 0.35),
                      Color.fromRGBO(59, 130, 246, 0.30),
                      Color.fromRGBO(255, 255, 255, 0.22),
                      Color.fromRGBO(239, 68, 68, 0.28),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _hhmm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
