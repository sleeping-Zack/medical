import '../models/elder_home_models.dart';

/// 初始 Mock，后续可换为 API + Riverpod 异步加载
class ElderHomeMockData {
  ElderHomeMockData._();

  static List<ElderFamilyMember> familyMembers() {
    return const [
      ElderFamilyMember(
        id: '1',
        displayName: '小明',
        relationLabel: '儿子',
        phone: '13800138000',
        avatarEmoji: '👨',
      ),
      ElderFamilyMember(
        id: '2',
        displayName: '丽丽',
        relationLabel: '女儿',
        phone: '13900139000',
        avatarEmoji: '👩',
      ),
      ElderFamilyMember(
        id: '3',
        displayName: '阿伟',
        relationLabel: '孙子',
        phone: '13700137000',
        avatarEmoji: '🧒',
      ),
    ];
  }

  /// 生成「今天」相对时间的示例记录（在 Controller 里会再对齐到当天）
  static List<ElderTodayIntakeRecord> seedTodayRecords(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    return [
      ElderTodayIntakeRecord(
        id: 'r0',
        targetUserId: 0,
        planId: 0,
        scheduleId: '0-0',
        scheduledTime: d.add(const Duration(hours: 7)),
        medicineName: '阿司匹林',
        dosageLabel: '1 片',
        status: IntakeRecordStatus.missed,
      ),
      ElderTodayIntakeRecord(
        id: 'r1',
        targetUserId: 0,
        planId: 0,
        scheduleId: '0-1',
        scheduledTime: d.add(const Duration(hours: 8)),
        medicineName: '降压药',
        dosageLabel: '1 片',
        status: IntakeRecordStatus.taken,
      ),
      ElderTodayIntakeRecord(
        id: 'r2',
        targetUserId: 0,
        planId: 0,
        scheduleId: '0-2',
        scheduledTime: d.add(const Duration(hours: 12)),
        medicineName: '钙片',
        dosageLabel: '2 粒',
        status: IntakeRecordStatus.taken,
      ),
      ElderTodayIntakeRecord(
        id: 'r3',
        targetUserId: 0,
        planId: 0,
        scheduleId: '0-3',
        scheduledTime: d.add(const Duration(hours: 16)),
        medicineName: '维生素',
        dosageLabel: '1 粒',
        status: IntakeRecordStatus.pending,
      ),
      ElderTodayIntakeRecord(
        id: 'r4',
        targetUserId: 0,
        planId: 0,
        scheduleId: '0-4',
        scheduledTime: d.add(const Duration(hours: 20)),
        medicineName: '助眠胶囊',
        dosageLabel: '1 粒',
        status: IntakeRecordStatus.pending,
      ),
    ];
  }

  static List<ElderDayTrend> weeklyTrend() {
    return const [
      ElderDayTrend(weekdayLabel: '一', completedDoses: 2, scheduledDoses: 3),
      ElderDayTrend(weekdayLabel: '二', completedDoses: 3, scheduledDoses: 3),
      ElderDayTrend(weekdayLabel: '三', completedDoses: 1, scheduledDoses: 3),
      ElderDayTrend(weekdayLabel: '四', completedDoses: 3, scheduledDoses: 3),
      ElderDayTrend(weekdayLabel: '五', completedDoses: 2, scheduledDoses: 3),
      ElderDayTrend(weekdayLabel: '六', completedDoses: 2, scheduledDoses: 2),
      ElderDayTrend(weekdayLabel: '日', completedDoses: 2, scheduledDoses: 3),
    ];
  }

  static const List<String> warmTips = [
    '记得慢慢喝几口温水，对身体更舒服。',
    '今天按时吃药，心里也会更踏实。',
    '您认真照顾自己的样子，真的很棒。',
    '吃完饭歇一会儿再吃药也可以哦。',
    '天气变化时，多注意休息。',
  ];
}
