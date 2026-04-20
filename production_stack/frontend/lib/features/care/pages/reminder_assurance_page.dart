import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/reminder_notification_service.dart';

/// 安卓服药「闹钟式」提醒所需权限与系统项的集中说明与跳转（国产机仍需用户手动配合电池与自启动）。
class ReminderAssurancePage extends ConsumerStatefulWidget {
  const ReminderAssurancePage({super.key});

  @override
  ConsumerState<ReminderAssurancePage> createState() => _ReminderAssurancePageState();
}

class _ReminderAssurancePageState extends ConsumerState<ReminderAssurancePage> with WidgetsBindingObserver {
  bool _loading = true;
  bool _notifyOk = false;
  bool _exactOk = false;
  bool _batteryOk = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await ref.read(reminderNotificationServiceProvider).ensureInitialized();

    if (!_isAndroid) {
      setState(() {
        _loading = false;
        _notifyOk = false;
        _exactOk = false;
        _batteryOk = false;
      });
      return;
    }

    final notify = await Permission.notification.status;
    final exact = await Permission.scheduleExactAlarm.status;
    final battery = await Permission.ignoreBatteryOptimizations.status;

    setState(() {
      _loading = false;
      _notifyOk = notify.isGranted;
      _exactOk = exact.isGranted;
      _batteryOk = battery.isGranted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒保障设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (!_isAndroid) ...[
            const _InfoBanner(
              text:
                  'iPhone 上第三方应用无法做到与系统「时钟闹钟」同等级别的强打断与全屏叫醒；此处以安卓为重点说明。',
            ),
            const SizedBox(height: 16),
          ],
          if (_isAndroid) ...[
            const _InfoBanner(
              text:
                  '到点提醒会尽量使用「精确闹钟 + 全屏意图」在锁屏时亮屏并进入处理页；是否真正全屏由系统与各厂商策略决定，无法 100% 保证。',
            ),
            const SizedBox(height: 20),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _StatusTile(
              title: '通知权限',
              ok: _notifyOk,
              subtitle: '关闭时只会静默或完全不提醒。',
              actionLabel: _notifyOk ? null : '去开启',
              onAction: () async {
                await Permission.notification.request();
                await _reload();
              },
            ),
            if (_isAndroid) ...[
              _StatusTile(
                title: '精确闹钟',
                ok: _exactOk,
                subtitle: 'Android 14 起多数新装应用默认不授予，需手动打开「闹钟和提醒」权限。',
                actionLabel: _exactOk ? null : '去开启',
                onAction: () async {
                  await Permission.scheduleExactAlarm.request();
                  await ref.read(reminderNotificationServiceProvider).ensureInitialized();
                  await _reload();
                },
              ),
              _CtaCard(
                title: '全屏提醒（来电式）',
                subtitle:
                    '在支持的系统版本上请求「全屏通知」能力；插件无法可靠读取是否已授予，若按钮无反应请到应用信息页手动开启。',
                buttonLabel: '请求全屏提醒授权',
                onPressed: () async {
                  await ref.read(reminderNotificationServiceProvider).requestAndroidFullScreenIntentPermission();
                  await _reload();
                },
              ),
              _StatusTile(
                title: '忽略电池优化',
                ok: _batteryOk,
                subtitle: '建议关闭对本应用的限制，降低后台被杀、不响铃的概率。',
                actionLabel: _batteryOk ? null : '去设置',
                onAction: () async {
                  await Permission.ignoreBatteryOptimizations.request();
                  await _reload();
                },
              ),
              const SizedBox(height: 8),
              const _InfoBanner(
                text: '部分机型还需在系统设置中开启「自启动」「后台弹出界面」「锁屏显示通知」等，请在手机管家中查找本应用逐项放行。',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('打开应用信息页'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.title,
    required this.ok,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final bool ok;
  final String subtitle;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: ok ? Colors.green.shade700 : Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ),
                Text(
                  ok ? '已就绪' : '待处理',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ok ? Colors.green.shade800 : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 14, height: 1.35, color: Colors.brown.shade700)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => onAction!(),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 14, height: 1.35, color: Colors.brown.shade700)),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => onPressed(),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: Colors.brown.shade900)),
    );
  }
}
