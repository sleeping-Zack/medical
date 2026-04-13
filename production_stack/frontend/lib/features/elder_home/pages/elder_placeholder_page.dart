import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/elder_home_colors.dart';

/// 预留路由：记录详情 / 家人联系 / 统计详情 / 记录列表
class ElderPlaceholderPage extends StatelessWidget {
  const ElderPlaceholderPage({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElderHomeColors.warmWhite,
      appBar: AppBar(
        backgroundColor: ElderHomeColors.cream,
        foregroundColor: ElderHomeColors.textWarm,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle ?? '这里以后会接上真实数据，先回首页继续体验～',
              style: const TextStyle(fontSize: 20, height: 1.5, color: ElderHomeColors.textSoft),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              style: FilledButton.styleFrom(
                backgroundColor: ElderHomeColors.deepApricot,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              ),
              child: const Text('返回', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
