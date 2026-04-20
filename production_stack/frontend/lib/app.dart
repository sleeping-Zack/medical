import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/care/services/reminder_notification_service.dart';
import 'routing/app_router.dart';
import 'shared/ui/app_theme.dart';

class MedApp extends ConsumerStatefulWidget {
  const MedApp({super.key});

  @override
  ConsumerState<MedApp> createState() => _MedAppState();
}

class _MedAppState extends ConsumerState<MedApp> {
  @override
  void initState() {
    super.initState();
    // 尽早初始化通知插件与时区，避免用户未进首页前系统已拒绝排程或时区未就绪导致「到点不响」。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reminderNotificationServiceProvider).ensureInitialized();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: '药安心',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}

