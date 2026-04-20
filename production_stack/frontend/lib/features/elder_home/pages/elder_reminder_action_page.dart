import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/elder_home_models.dart';
import '../providers/elder_home_controller.dart';

/// 通知点入或全屏意图拉起后的服药处理页：大字号、高对比、少跳转。
class ElderReminderActionPage extends ConsumerStatefulWidget {
  const ElderReminderActionPage({super.key, required this.reminderId});

  final String reminderId;

  @override
  ConsumerState<ElderReminderActionPage> createState() => _ElderReminderActionPageState();
}

class _ElderReminderActionPageState extends ConsumerState<ElderReminderActionPage> {
  static const _kVoicePrefKey = 'elder_reminder_voice_enabled';
  bool _voiceOn = false;
  bool _voiceLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadVoicePref();
  }

  Future<void> _loadVoicePref() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _voiceOn = p.getBool(_kVoicePrefKey) ?? false;
      _voiceLoaded = true;
    });
  }

  Future<void> _setVoicePref(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kVoicePrefKey, v);
    if (!mounted) return;
    setState(() => _voiceOn = v);
  }

  String _fmt(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int? _todayDoseIndex(ElderTodayIntakeRecord record, List<ElderTodayIntakeRecord> all) {
    final sorted = [...all]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final i = sorted.indexWhere((r) => r.id == record.id);
    if (i < 0) return null;
    return i + 1;
  }

  void _goHome() {
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(elderHomeControllerProvider);
    final ctrl = ref.read(elderHomeControllerProvider.notifier);
    final ElderTodayIntakeRecord? record = ctrl.findById(widget.reminderId) ?? state.nextPending;

    const bgTop = Color(0xFF2A221C);
    const bgBottom = Color(0xFF1A1512);
    const cardBg = Color(0xFFFFE8D2);
    const accent = Color(0xFFC45D28);

    return Scaffold(
      backgroundColor: bgBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: SafeArea(
          child: record == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '当前没有待处理提醒',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFFFF2E8)),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _goHome,
                          child: const Text('回首页'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFFE8D8CC), size: 30),
                        onPressed: _goHome,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        '现在该吃药了',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          color: Colors.orange.shade50,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.medicineName,
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF4A3020),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _kvRow('数量', record.dosageLabel, accent),
                                  const SizedBox(height: 10),
                                  _kvRow('时间', _fmt(record.scheduledTime), accent),
                                  if (_todayDoseIndex(record, state.todayRecords) != null) ...[
                                    const SizedBox(height: 10),
                                    _kvRow('今天第几次', '第 ${_todayDoseIndex(record, state.todayRecords)} 次', accent),
                                  ],
                                  if (record.snoozeUntil != null) ...[
                                    const SizedBox(height: 10),
                                    _kvRow('已延后到', _fmt(record.snoozeUntil!), accent),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            _bigAction(
                              label: '我已服药',
                              bg: const Color(0xFF3D7A4E),
                              onTap: () async {
                                await ctrl.markTakenById(record.id);
                                if (!mounted) return;
                                _goHome();
                              },
                            ),
                            const SizedBox(height: 14),
                            _bigAction(
                              label: '稍后 10 分钟',
                              bg: const Color(0xFF2F5FA8),
                              onTap: () async {
                                await ctrl.snoozeById(record.id, minutes: 10);
                                if (!mounted) return;
                                _goHome();
                              },
                            ),
                            const SizedBox(height: 14),
                            _bigAction(
                              label: '今日不吃',
                              bg: accent,
                              onTap: () async {
                                await ctrl.skipById(record.id);
                                if (!mounted) return;
                                _goHome();
                              },
                            ),
                            const SizedBox(height: 22),
                            if (state.familyMembers.isNotEmpty) ...[
                              const Text(
                                '家人在关心您',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFFE8D8CC)),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: state.familyMembers
                                    .map(
                                      (m) => Chip(
                                        avatar: Text(m.avatarEmoji, style: const TextStyle(fontSize: 18)),
                                        label: Text(
                                          m.displayName,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                        backgroundColor: const Color(0xFF3A322C),
                                        labelStyle: const TextStyle(color: Color(0xFFFFF2E8)),
                                        side: BorderSide(color: Colors.orange.shade200.withValues(alpha: 0.35)),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '孩子正在关心您',
                                style: TextStyle(fontSize: 15, color: Color(0xFFC4B5A8)),
                              ),
                            ],
                            if (_voiceLoaded) ...[
                              const SizedBox(height: 18),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  '语音播报（稍后版本）',
                                  style: TextStyle(color: Color(0xFFE8D8CC), fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                subtitle: const Text(
                                  '开启后将在后续更新中朗读药名与时间',
                                  style: TextStyle(color: Color(0xFFB0A090), fontSize: 13),
                                ),
                                value: _voiceOn,
                                onChanged: (v) async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  await _setVoicePref(v);
                                  if (!mounted) return;
                                  if (v) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('语音播报将在后续版本开通')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _kvRow(String k, String v, Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            k,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.brown.shade700),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: accent),
          ),
        ),
      ],
    );
  }

  Widget _bigAction({
    required String label,
    required Color bg,
    required Future<void> Function() onTap,
  }) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(62),
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
      ),
      onPressed: () async {
        await onTap();
      },
      child: Text(label),
    );
  }
}
