import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../models/plan_item.dart';

final plansForTargetProvider = FutureProvider.autoDispose.family<List<PlanItem>, int>((ref, targetUserId) async {
  final repo = ref.watch(careRepositoryProvider);
  return repo.listPlans(targetUserId: targetUserId);
});

class PlanListPage extends ConsumerWidget {
  const PlanListPage({super.key, required this.targetUserId});

  final int targetUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(plansForTargetProvider(targetUserId));

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
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('新建计划'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e is ApiException ? e.message : '加载失败')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('暂无计划，请先添加药品再创建计划。'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(plansForTargetProvider(targetUserId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = list[i];
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
}
