import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/providers/auth_controller.dart';
import '../elder_home/elder_home_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final isPersonal = user?.role == 'personal';
    final isElder = user?.role == 'elderly';

    if (isElder) {
      return ElderHomePage(shortId: user?.shortId ?? '');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('药安心'),
        actions: [
          TextButton(
            onPressed: auth.isBusy ? null : () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('退出登录'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isPersonal) ...[
            Card(
              color: const Color(0xFFFFF3E0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFFB74D)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '新版「长辈首页」在哪？',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '您当前是家属端账号，首页仍是管理入口。长辈专属大字号首页只在「老人端」账号登录后出现；也可点下面先预览界面。',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Colors.brown.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => context.push('/elder/preview'),
                      child: const Text('打开长辈首页预览'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前账号',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('手机：${user?.phone ?? '-'}'),
                  Text('角色：${_roleLabel(user?.role)}'),
                  Text('用户 ID：${user?.id ?? '-'}'),
                ],
              ),
            ),
          ),
          if (isPersonal) ...[
            const SizedBox(height: 16),
            Text('家庭代管', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('绑定长辈'),
              subtitle: const Text('输入长辈绑定短号 + 手机后四位'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/care/bind'),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('已绑定的长辈'),
              subtitle: const Text('为长辈添加药品与服药计划'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/care/elders'),
            ),
            const Divider(height: 32),
            Text('本人用药', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.medication_liquid_outlined),
              title: const Text('我的药品与计划'),
              subtitle: const Text('家属端也可管理本人用药'),
              trailing: const Icon(Icons.chevron_right),
              onTap: user?.id != null ? () => context.push('/care/medicines?target=${user!.id}') : null,
            ),
          ],
        ],
      ),
    );
  }

  String _roleLabel(String? role) {
    if (role == 'personal') return '家属端（个人端）';
    if (role == 'elderly') return '长辈端';
    return '-';
  }
}

