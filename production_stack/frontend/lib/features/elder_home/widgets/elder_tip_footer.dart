import 'package:flutter/material.dart';

import '../mock/elder_home_mock_data.dart';
import '../theme/elder_home_colors.dart';

/// 底部温馨小贴士（按日期轮换，非医疗建议）
class ElderTipFooter extends StatelessWidget {
  const ElderTipFooter({super.key});

  @override
  Widget build(BuildContext context) {
    const tips = ElderHomeMockData.warmTips;
    final i = DateTime.now().day % tips.length;
    const softLine = '您不用一次做完所有事，慢慢来，我们陪着您。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: ElderHomeColors.gentleAmber.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ElderHomeColors.apricot.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: ElderHomeColors.cardShadow.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌸', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tips[i],
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: ElderHomeColors.textWarm,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  softLine,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: ElderHomeColors.sageDeep.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
