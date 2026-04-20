import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/pages/auth_screen_page.dart';
import '../features/auth/pages/forgot_password_page.dart';
import '../features/auth/providers/auth_controller.dart';
import '../features/auth/providers/auth_state.dart';
import '../features/care/pages/bind_elder_page.dart';
import '../features/care/pages/bound_elders_page.dart';
import '../features/care/pages/medicine_create_page.dart';
import '../features/care/pages/medicine_list_page.dart';
import '../features/care/pages/plan_create_page.dart';
import '../features/care/pages/plan_list_page.dart';
import '../features/care/pages/reminder_assurance_page.dart';
import '../features/elder_home/elder_home_page.dart';
import '../features/elder_home/pages/elder_placeholder_page.dart';
import '../features/elder_home/pages/elder_reminder_action_page.dart';
import '../features/home/home_page.dart';
import '../features/splash/splash_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      final isAuthFlow = location == '/login' || location == '/register' || location == '/forgot-password';

      if (auth.status == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }

      if (auth.status == AuthStatus.unauthenticated) {
        if (location == '/splash') return '/login';
        return isAuthFlow ? null : '/login';
      }

      if (auth.status == AuthStatus.authenticated) {
        return isAuthFlow || location == '/splash' ? '/home' : null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final reg = state.uri.queryParameters['register'] == '1' || state.uri.queryParameters['mode'] == 'register';
          return AuthScreenPage(initialRegister: reg);
        },
      ),
      GoRoute(
        path: '/register',
        redirect: (context, state) => '/login?register=1',
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      /// 家属端也可打开，用于查看新版长辈 UI（与长辈账号登录后 `/home` 为同一套页面）
      GoRoute(
        path: '/elder/preview',
        builder: (context, state) => const ElderHomePage(shortId: ''),
      ),
      GoRoute(
        path: '/elder/records',
        builder: (context, state) => const ElderPlaceholderPage(
          title: '今日记录',
          subtitle: '完整的今日服药记录将在这里展示，敬请期待。',
        ),
      ),
      GoRoute(
        path: '/elder/record/:id',
        builder: (context, state) => ElderPlaceholderPage(
          title: '记录详情',
          subtitle: '记录编号：${state.pathParameters['id'] ?? ''}\n详情页接入接口后即可查看照片与说明。',
        ),
      ),
      GoRoute(
        path: '/elder/reminder/:id',
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
          return MaterialPage<void>(
            fullscreenDialog: true,
            name: state.name,
            arguments: state.extra,
            key: state.pageKey,
            child: ElderReminderActionPage(reminderId: id),
          );
        },
      ),
      GoRoute(
        path: '/elder/reminder-assurance',
        builder: (context, state) => const ReminderAssurancePage(),
      ),
      GoRoute(
        path: '/elder/family/:id',
        builder: (context, state) => const ElderPlaceholderPage(
          title: '联系家人',
          subtitle: '与家人通话、发消息的入口将放在这里，当前为演示占位。',
        ),
      ),
      GoRoute(
        path: '/elder/stats',
        builder: (context, state) => const ElderPlaceholderPage(
          title: '服药统计',
          subtitle: '更详细的周报、月报会在这里呈现，让您和家人都安心。',
        ),
      ),
      GoRoute(
        path: '/care/bind',
        builder: (context, state) => const BindElderPage(),
      ),
      GoRoute(
        path: '/care/elders',
        builder: (context, state) => const BoundEldersPage(),
      ),
      GoRoute(
        path: '/care/medicines/new',
        builder: (context, state) {
          final t = state.uri.queryParameters['target'];
          final id = int.tryParse(t ?? '');
          if (id == null) {
            return const Scaffold(body: Center(child: Text('缺少 target 参数')));
          }
          return MedicineCreatePage(targetUserId: id);
        },
      ),
      GoRoute(
        path: '/care/medicines',
        builder: (context, state) {
          final t = state.uri.queryParameters['target'];
          final id = int.tryParse(t ?? '');
          if (id == null) {
            return const Scaffold(body: Center(child: Text('缺少 target 参数')));
          }
          return MedicineListPage(targetUserId: id);
        },
      ),
      GoRoute(
        path: '/care/plans/new',
        builder: (context, state) {
          final t = state.uri.queryParameters['target'];
          final id = int.tryParse(t ?? '');
          if (id == null) {
            return const Scaffold(body: Center(child: Text('缺少 target 参数')));
          }
          return PlanCreatePage(targetUserId: id);
        },
      ),
      GoRoute(
        path: '/care/plans',
        builder: (context, state) {
          final t = state.uri.queryParameters['target'];
          final id = int.tryParse(t ?? '');
          if (id == null) {
            return const Scaffold(body: Center(child: Text('缺少 target 参数')));
          }
          return PlanListPage(targetUserId: id);
        },
      ),
    ],
  );
});

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
  }

  final Ref ref;
}

