import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_controller.dart';
import '../elder_home/elder_home_page.dart';
import 'app_settings_sheet.dart';
import 'caregiver_shell_page.dart';
import 'personal_ui_mode_provider.dart';

/// 路由 `/home`：与 Web 一致 —— 家属端可持久切换「看护人 / 长辈」视图（`personalUiModeProvider`）。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未登录')));
    }
    if (user.role == 'elderly') {
      return ElderHomePage(
        shortId: user.shortId,
        onOpenSettings: () => showAppSettingsSheet(context, ref, showPersonalModeToggle: false),
      );
    }
    if (user.role == 'personal') {
      final mode = ref.watch(personalUiModeProvider);
      if (mode == 'elder') {
        return ElderHomePage(
          shortId: user.shortId,
          onOpenSettings: () => showAppSettingsSheet(context, ref, showPersonalModeToggle: true),
        );
      }
      return const CaregiverShellPage();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('药安心')),
      body: const Center(child: Text('当前账号角色暂不支持，请使用家属端或长辈端。')),
    );
  }
}
