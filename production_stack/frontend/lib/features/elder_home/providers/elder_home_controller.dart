import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/elder_home_mock_data.dart';
import '../models/elder_home_models.dart';

/// 长辈首页状态（Mock 可替换为 repository）
class ElderHomeState {
  const ElderHomeState({
    required this.todayRecords,
    required this.familyMembers,
    required this.weeklyTrend,
    required this.streakDays,
    required this.snoozeUntil,
    required this.snoozeMessage,
  });

  final List<ElderTodayIntakeRecord> todayRecords;
  final List<ElderFamilyMember> familyMembers;
  final List<ElderDayTrend> weeklyTrend;
  final int streakDays;
  final DateTime? snoozeUntil;
  final String? snoozeMessage;

  int get scheduledToday => todayRecords.length;
  int get completedToday => todayRecords.where((r) => r.status == IntakeRecordStatus.taken).length;

  ElderTodayIntakeRecord? get nextPending {
    for (final r in todayRecords) {
      if (r.status == IntakeRecordStatus.pending || r.status == IntakeRecordStatus.snoozed) {
        return r;
      }
    }
    return null;
  }

  bool get hasMissed => todayRecords.any((r) => r.status == IntakeRecordStatus.missed);

  bool get allDone =>
      todayRecords.isNotEmpty && todayRecords.every((r) => r.status == IntakeRecordStatus.taken);

  ElderMainCardPhase get mainPhase {
    if (allDone) return ElderMainCardPhase.allDone;
    final next = nextPending;
    if (next == null) return ElderMainCardPhase.allDone;
    final now = DateTime.now();
    if (snoozeUntil != null && now.isBefore(snoozeUntil!)) {
      return ElderMainCardPhase.snoozed;
    }
    if (hasMissed) return ElderMainCardPhase.hasMissed;
    // 已到计划时间（前后 5 分钟内也算「该吃了」）
    final start = next.scheduledTime.subtract(const Duration(minutes: 5));
    if (!now.isBefore(start)) {
      return ElderMainCardPhase.dueNow;
    }
    return ElderMainCardPhase.upcoming;
  }
}

class ElderHomeController extends StateNotifier<ElderHomeState> {
  ElderHomeController()
      : super(
          ElderHomeState(
            todayRecords: ElderHomeMockData.seedTodayRecords(DateTime.now()),
            familyMembers: ElderHomeMockData.familyMembers(),
            weeklyTrend: ElderHomeMockData.weeklyTrend(),
            streakDays: 4,
            snoozeUntil: null,
            snoozeMessage: null,
          ),
        );

  /// 刷新「今天」数据（例如跨日或拉取接口后）
  void resetTodayFromMock() {
    final records = ElderHomeMockData.seedTodayRecords(DateTime.now());
    state = ElderHomeState(
      todayRecords: records,
      familyMembers: state.familyMembers,
      weeklyTrend: ElderHomeMockData.weeklyTrend(),
      streakDays: state.streakDays,
      snoozeUntil: null,
      snoozeMessage: null,
    );
  }

  /// 标记下一剂已服（Mock：将第一条 pending/snoozed 标为 taken）
  void markNextTaken() {
    final list = [...state.todayRecords];
    final idx = list.indexWhere(
      (r) => r.status == IntakeRecordStatus.pending || r.status == IntakeRecordStatus.snoozed,
    );
    if (idx < 0) return;
    final r = list[idx];
    list[idx] = ElderTodayIntakeRecord(
      id: r.id,
      scheduledTime: r.scheduledTime,
      medicineName: r.medicineName,
      dosageLabel: r.dosageLabel,
      status: IntakeRecordStatus.taken,
    );
    state = ElderHomeState(
      todayRecords: list,
      familyMembers: state.familyMembers,
      weeklyTrend: state.weeklyTrend,
      streakDays: state.streakDays,
      snoozeUntil: null,
      snoozeMessage: null,
    );
    _bumpTodayTrendMock();
  }

  /// 稍后再服 10 分钟（Mock：记录标为「稍后再服」+ 顶部提示）
  void snoozeTenMinutes() {
    final list = [...state.todayRecords];
    final idx = list.indexWhere((r) => r.status == IntakeRecordStatus.pending);
    if (idx >= 0) {
      final r = list[idx];
      list[idx] = ElderTodayIntakeRecord(
        id: r.id,
        scheduledTime: r.scheduledTime,
        medicineName: r.medicineName,
        dosageLabel: r.dosageLabel,
        status: IntakeRecordStatus.snoozed,
      );
    }
    state = ElderHomeState(
      todayRecords: list,
      familyMembers: state.familyMembers,
      weeklyTrend: state.weeklyTrend,
      streakDays: state.streakDays,
      snoozeUntil: DateTime.now().add(const Duration(minutes: 10)),
      snoozeMessage: '好的，大约十分钟后我再轻轻提醒您～',
    );
  }

  void clearSnoozeBanner() {
    state = ElderHomeState(
      todayRecords: state.todayRecords,
      familyMembers: state.familyMembers,
      weeklyTrend: state.weeklyTrend,
      streakDays: state.streakDays,
      snoozeUntil: null,
      snoozeMessage: null,
    );
  }

  /// 模拟更新「今天」在趋势图里最后一个柱（演示联动）
  void _bumpTodayTrendMock() {
    final trend = [...state.weeklyTrend];
    if (trend.isEmpty) return;
    final last = trend.last;
    final bumped = ElderDayTrend(
      weekdayLabel: last.weekdayLabel,
      completedDoses: (last.completedDoses + 1).clamp(0, last.scheduledDoses),
      scheduledDoses: last.scheduledDoses,
    );
    trend[trend.length - 1] = bumped;
    state = ElderHomeState(
      todayRecords: state.todayRecords,
      familyMembers: state.familyMembers,
      weeklyTrend: trend,
      streakDays: state.streakDays,
      snoozeUntil: state.snoozeUntil,
      snoozeMessage: state.snoozeMessage,
    );
  }
}

final elderHomeControllerProvider =
    StateNotifierProvider<ElderHomeController, ElderHomeState>((ref) {
  return ElderHomeController();
});
