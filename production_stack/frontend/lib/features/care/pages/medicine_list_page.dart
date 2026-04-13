import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../models/medicine_item.dart';

final medicinesForTargetProvider =
    FutureProvider.autoDispose.family<List<MedicineItem>, int>((ref, targetUserId) async {
  final repo = ref.watch(careRepositoryProvider);
  return repo.listMedicines(targetUserId: targetUserId);
});

class MedicineListPage extends ConsumerWidget {
  const MedicineListPage({super.key, required this.targetUserId});

  final int targetUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(medicinesForTargetProvider(targetUserId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('长辈药品'),
        actions: [
          TextButton(
            onPressed: () => context.push('/care/plans?target=$targetUserId'),
            child: const Text('服药计划'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await context.push<bool>('/care/medicines/new?target=$targetUserId');
          if (ok == true && context.mounted) {
            ref.invalidate(medicinesForTargetProvider(targetUserId));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('新增药品'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e is ApiException ? e.message : '加载失败')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('暂无药品，请点击右下角添加。'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(medicinesForTargetProvider(targetUserId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = list[i];
                return ListTile(
                  tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [
                      if (m.specification != null && m.specification!.isNotEmpty) m.specification!,
                      if (m.note != null && m.note!.isNotEmpty) m.note!,
                    ].join(' · '),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
