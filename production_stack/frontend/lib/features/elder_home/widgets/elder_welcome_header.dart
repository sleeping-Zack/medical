import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/elder_home_colors.dart';

/// 顶部欢迎区：大号时间、日期星期、分时段问候 + 陪伴感副文案（卡片 + 柔和阴影）
class ElderWelcomeHeader extends StatefulWidget {
  const ElderWelcomeHeader({
    super.key,
    this.companionLine,
    this.phoneTailHint,
  });

  /// 来自首页状态的轻量提示，例如「今天还剩 2 次…」
  final String? companionLine;

  /// 如 `尾号 1234`，无昵称时用电话尾号增加亲切感
  final String? phoneTailHint;

  @override
  State<ElderWelcomeHeader> createState() => _ElderWelcomeHeaderState();
}

class _ElderWelcomeHeaderState extends State<ElderWelcomeHeader> {
  late DateTime _now;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _greeting() {
    final h = _now.hour;
    if (h < 11) return '早上好呀，今天也从一口温水开始吧';
    if (h < 14) return '中午好，慢慢吃、慢慢歇，身体最要紧';
    if (h < 18) return '下午好，累了就坐一会儿，我在这儿陪着您';
    return '晚上好，把今天的事放下，好好放松';
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final week = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'][_now.weekday - 1];
    final dateStr = '${_now.year} 年 ${_now.month} 月 ${_now.day} 日 · $week';

    final hint = widget.phoneTailHint;
    final who = (hint != null && hint.isNotEmpty) ? '（$hint）' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            ElderHomeColors.blushMid.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ElderHomeColors.peach.withValues(alpha: 0.65)),
        boxShadow: const [
          BoxShadow(
            color: ElderHomeColors.cardShadow,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    height: 1.02,
                    color: ElderHomeColors.textWarm,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: ElderHomeColors.textSoft,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _greeting(),
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: ElderHomeColors.deepApricot,
                  ),
                ),
                if (who.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '亲爱的长辈$who',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: ElderHomeColors.textSoft,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  widget.companionLine ?? '不着急，一步一步来，今天的事我们一起看。',
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: ElderHomeColors.sageDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: ElderHomeColors.gentleAmber.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ElderHomeColors.apricot.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🌤️', style: TextStyle(fontSize: 42)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '陪您',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ElderHomeColors.textSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
