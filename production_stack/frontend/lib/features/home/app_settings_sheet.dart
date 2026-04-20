import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../routing/app_router.dart';
import '../auth/providers/auth_controller.dart';
import 'personal_ui_mode_provider.dart';

/// 与 Web `App.tsx` 设置面板一致：标题、应用模式（看护人/长辈）、个人信息、退出登录。
Future<void> showAppSettingsSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool showPersonalModeToggle,
}) async {
  final user = ref.read(authControllerProvider).user;
  if (user == null) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Consumer(
      builder: (_, ref, __) {
        final mode = ref.watch(personalUiModeProvider);
        return _AppSettingsSheetBody(
          phone: user.phone,
          shortId: user.shortId,
          showPersonalModeToggle: showPersonalModeToggle,
          currentMode: mode,
          showReminderAssuranceEntry: !kIsWeb && Platform.isAndroid,
          onClose: () => Navigator.pop(ctx),
          onLogout: () {
            Navigator.pop(ctx);
            ref.read(authControllerProvider.notifier).logout();
          },
          onSetCaregiver: () async {
            await ref.read(personalUiModeProvider.notifier).setMode('caregiver');
            if (ctx.mounted) Navigator.pop(ctx);
          },
          onSetElder: () async {
            await ref.read(personalUiModeProvider.notifier).setMode('elder');
            if (ctx.mounted) Navigator.pop(ctx);
          },
          onOpenReminderAssurance: () {
            Navigator.pop(ctx);
            ref.read(goRouterProvider).push('/elder/reminder-assurance');
          },
        );
      },
    ),
  );
}

class _AppSettingsSheetBody extends StatelessWidget {
  const _AppSettingsSheetBody({
    required this.phone,
    required this.shortId,
    required this.showPersonalModeToggle,
    required this.currentMode,
    required this.showReminderAssuranceEntry,
    required this.onClose,
    required this.onLogout,
    required this.onSetCaregiver,
    required this.onSetElder,
    required this.onOpenReminderAssurance,
  });

  final String phone;
  final String shortId;
  final bool showPersonalModeToggle;
  final String currentMode;
  final bool showReminderAssuranceEntry;
  final VoidCallback onClose;
  final VoidCallback onLogout;
  final Future<void> Function() onSetCaregiver;
  final Future<void> Function() onSetElder;
  final VoidCallback onOpenReminderAssurance;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (ctx, scroll) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFBF5), Color(0xFFFFF8F0)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFFFFE4CC)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF5C4A3D))),
                  IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Color(0xFF8B7A6E))),
                ],
              ),
              const SizedBox(height: 8),
              if (showPersonalModeToggle) ...[
                _setCard(
                  title: '应用模式',
                  subtitle: '在看护人和长辈视图之间切换',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE4CC)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ModeChip(
                            label: '看护人',
                            selected: currentMode == 'caregiver',
                            onTap: onSetCaregiver,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ModeChip(
                            label: '长辈',
                            selected: currentMode == 'elder',
                            onTap: onSetElder,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (showReminderAssuranceEntry) ...[
                _setCard(
                  title: '提醒保障（安卓）',
                  subtitle: '精确闹钟、全屏提醒、电池优化等，帮助到点更可靠地叫醒与处理。',
                  child: FilledButton.icon(
                    onPressed: onOpenReminderAssurance,
                    icon: const Icon(Icons.alarm_on_rounded),
                    label: const Text('打开提醒保障设置'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _setCard(
                title: '个人信息',
                subtitle: null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('我的 6 位 ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8B7A6E))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE4CC)),
                      ),
                      child: Text(shortId.isEmpty ? '---' : shortId, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4)),
                    ),
                    const SizedBox(height: 14),
                    const Text('手机号 (用于家人绑定验证)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8B7A6E))),
                    const SizedBox(height: 6),
                    Text(phone, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF5C4A3D))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                  side: BorderSide(color: Colors.red.shade100),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('退出登录', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _setCard({required String title, String? subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFE4CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5C4A3D))),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF8B7A6E), fontWeight: FontWeight.w500, height: 1.35)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? const Color(0xFFE8863D) : const Color(0xFF8B7A6E),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
