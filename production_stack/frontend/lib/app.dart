import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';
import 'shared/ui/app_theme.dart';

class MedApp extends ConsumerWidget {
  const MedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: '药安心',
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}

