import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../models/bound_elder.dart';

final boundEldersProvider = FutureProvider.autoDispose<List<BoundElder>>((ref) async {
  final repo = ref.watch(careRepositoryProvider);
  return repo.listBindings();
});

class BoundEldersPage extends ConsumerWidget {
  const BoundEldersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(boundEldersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('已绑定的长辈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: '绑定长辈',
            onPressed: () => context.push('/care/bind'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/care/bind'),
        icon: const Icon(Icons.add),
        label: const Text('绑定长辈'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? e.message : '加载失败',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('暂无绑定，请先添加长辈账号。'),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => context.push('/care/bind'), child: const Text('去绑定')),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(boundEldersProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = list[i];
                return Card(
                  child: ListTile(
                    title: Text('长辈 ${e.phoneMasked}'),
                    subtitle: Text('短号 ${e.shortId}${e.canManageMedicine ? '' : '（无代管权限）'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: e.canManageMedicine
                        ? () => context.push('/care/medicines?target=${e.elderId}')
                        : null,
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
