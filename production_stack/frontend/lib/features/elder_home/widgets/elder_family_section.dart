import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/elder_home_models.dart';
import '../theme/elder_home_colors.dart';

/// 关心您的家人：头像、称呼、关系、打电话 / 发消息（占位）
class ElderFamilySection extends StatelessWidget {
  const ElderFamilySection({super.key, required this.members});

  final List<ElderFamilyMember> members;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ElderHomeColors.softBlue.withValues(alpha: 0.38),
            ElderHomeColors.cream,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ElderHomeColors.softBlue.withValues(alpha: 0.52)),
        boxShadow: [
          BoxShadow(
            color: ElderHomeColors.cardShadow.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💛', style: TextStyle(fontSize: 26)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '已绑定的子女与家人',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: ElderHomeColors.textWarm,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '头像下面是称呼，有事一键联系，不用记号码',
            style: TextStyle(fontSize: 17, height: 1.35, color: ElderHomeColors.textSoft),
          ),
          const SizedBox(height: 18),
          if (members.isEmpty)
            const Text(
              '还没有绑定家人，可以把首页上的短号念给子女听，让他们在手机上添加您。',
              style: TextStyle(fontSize: 18, height: 1.45, color: ElderHomeColors.textSoft),
            )
          else
            ...members.map((m) => _memberCard(context, m)),
        ],
      ),
    );
  }

  Widget _memberCard(BuildContext context, ElderFamilyMember m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => context.push('/elder/family/${m.id}'),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: ElderHomeColors.peach.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ElderHomeColors.apricot.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(child: Text(m.avatarEmoji, style: const TextStyle(fontSize: 34))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ElderHomeColors.textWarm,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.relationLabel,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ElderHomeColors.textSoft),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _miniAction(
                      icon: Icons.phone_in_talk_rounded,
                      label: '电话',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('即将拨打 ${m.phone ?? '家人电话'}（演示）'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _miniAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '消息',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('发消息功能即将上线，先打个电话问候一下吧～'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: ElderHomeColors.apricot.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: ElderHomeColors.textWarm),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ElderHomeColors.textWarm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
