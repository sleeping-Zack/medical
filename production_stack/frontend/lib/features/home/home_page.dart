import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          TextButton(
            onPressed: auth.isBusy ? null : () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('退出登录'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '登录成功',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text('用户：${user?.phone ?? '-'}'),
                const SizedBox(height: 6),
                Text('角色：${_roleLabel(user?.role)}'),
                const SizedBox(height: 6),
                Text('用户ID：${user?.id ?? '-'}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(String? role) {
    if (role == 'personal') return '家属端';
    if (role == 'elderly') return '老人端';
    return '-';
  }
}

