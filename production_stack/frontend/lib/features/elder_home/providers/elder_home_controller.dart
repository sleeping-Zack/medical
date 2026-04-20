import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../../core/providers.dart';
import '../../auth/providers/auth_controller.dart';
import '../../care/models/adherence_point.dart';
import '../../care/models/bound_caregiver.dart';
import '../../care/models/plan_item.dart';
import '../../care/models/reminder_item.dart';
import '../../care/repositories/care_repository.dart';
import '../../care/services/reminder_notification_service.dart';
import '../models/elder_home_models.dart';

class ElderHomeState {
  const ElderHomeState({
    required this.todayRecords,
    required this.carePlans,
    required this.familyMembers,
    required this.weeklyTrend,
    required this.streakDays,
    required this.snoozeUntil,
    required this.snoozeMessage,
    required this.loading,
  });

  final List<ElderTodayIntakeRecord> todayRecords;
  /// 与看护端「计划」同源：本人账号下的用药计划（含家属代本人创建）
  final List<PlanItem> carePlans;
  final List<ElderFamilyMember> familyMembers;
  final List<ElderDayTrend> weeklyTrend;
  final int streakDays;
  final DateTime? snoozeUntil;
  final String? snoozeMessage;
  final bool loading;

  int get scheduledToday => todayRecords.length;
  int get completedToday => todayRecords.where((r) => r.status == IntakeRecordStatus.taken).length;

  ElderTodayIntakeRecord? get nextPending {
    for (final r in todayRecords) {
      if (r.status == IntakeRecordStatus.pending ||
          r.status == IntakeRecordStatus.snoozed ||
          r.status == IntakeRecordStatus.notified) {
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
  ElderHomeController(this._ref)
      : super(
          const ElderHomeState(
            todayRecords: [],
            carePlans: [],
            familyMembers: [],
            weeklyTrend: [],
            streakDays: 0,
            snoozeUntil: null,
            snoozeMessage: null,
            loading: true,
          ),
        );

  final Ref _ref;
  CareRepository get _repo => _ref.read(careRepositoryProvider);

  int? get _targetUserId => _ref.read(authControllerProvider).user?.id;

  Future<void> refreshFromApi() async {
    final uid = _targetUserId;
    if (uid == null) {
      debugPrint('[elder-home] refreshFromApi skipped: no logged-in user id');
      return;
    }
    debugPrint('[elder-home] refreshFromApi start target=$uid');
    state = ElderHomeState(
      todayRecords: state.todayRecords,
      carePlans: state.carePlans,
      familyMembers: state.familyMembers,
      weeklyTrend: state.weeklyTrend,
      streakDays: state.streakDays,
      snoozeUntil: state.snoozeUntil,
      snoozeMessage: state.snoozeMessage,
      loading: true,
    );
    final now = DateTime.now();
    try {
      final results = await Future.wait([
        _repo.listTodayReminders(targetUserId: uid, onDate: now),
        _repo.listIncomingBindings(),
        _repo.getAdherenceTrend(targetUserId: uid, days: 7),
        _repo.listPlans(targetUserId: uid),
      ]);
      final reminders = results[0] as List<ReminderItem>;
      final incoming = results[1] as List<BoundCaregiver>;
      final adherence = results[2] as List<AdherencePoint>;
      final plans = results[3] as List<PlanItem>;
      debugPrint(
        '[elder-home] refresh ok reminders=${reminders.length} plans=${plans.length} '
        'incoming=${incoming.length} adherence=${adherence.length}',
      );
      final mappedRecords = _toTodayRecords(reminders);
      final mappedFamily = incoming
          .map((e) => ElderFamilyMember(
                id: '${e.caregiverId}',
                displayName: '家人（${e.phoneMasked}）',
                relationLabel: e.role == 'personal' ? '家人' : '看护',
                phone: e.phoneMasked,
                avatarEmoji: '👨',
              ))
          .toList();
      final trend = _toTrend(adherence);
      final activeSnooze = _findActiveSnooze(mappedRecords);
      await _ref.read(reminderNotificationServiceProvider).syncTodayReminders(
            reminders: reminders,
          );
      state = ElderHomeState(
        todayRecords: mappedRecords,
        carePlans: plans,
        familyMembers: mappedFamily,
        weeklyTrend: trend,
        streakDays: _computeStreak(adherence),
        snoozeUntil: activeSnooze,
        snoozeMessage: activeSnooze != null ? '好的，大约十分钟后我再轻轻提醒您～' : null,
        loading: false,
      );
    } catch (e, st) {
      debugPrint('[elder-home] refreshFromApi failed: $e\n$st');
      state = ElderHomeState(
        todayRecords: state.todayRecords,
        carePlans: state.carePlans,
        familyMembers: state.familyMembers,
        weeklyTrend: state.weeklyTrend,
        streakDays: state.streakDays,
        snoozeUntil: state.snoozeUntil,
        snoozeMessage: state.snoozeMessage,
        loading: false,
      );
    }
  }

  Future<void> markNextTaken() async {
    final next = state.nextPending;
    if (next == null) return;
    await _repo.markReminder(
      targetUserId: next.targetUserId,
      planId: next.planId,
      scheduleId: next.scheduleId,
      dueTime: next.scheduledTime,
      action: 'taken',
    );
    await refreshFromApi();
  }

  Future<void> snoozeTenMinutes() async {
    final next = state.nextPending;
    if (next == null) return;
    await _repo.snoozeReminder(
      targetUserId: next.targetUserId,
      planId: next.planId,
      scheduleId: next.scheduleId,
      dueTime: next.scheduledTime,
      snoozeMinutes: 10,
    );
    await refreshFromApi();
  }

  Future<void> markNextMissed() async {
    final next = state.nextPending;
    if (next == null) return;
    await _repo.markReminder(
      targetUserId: next.targetUserId,
      planId: next.planId,
      scheduleId: next.scheduleId,
      dueTime: next.scheduledTime,
      action: 'missed',
    );
    await refreshFromApi();
  }

  ElderTodayIntakeRecord? findById(String reminderId) {
    for (final r in state.todayRecords) {
      if (r.id == reminderId) return r;
    }
    return null;
  }

  Future<void> markTakenById(String reminderId) async {
    final target = findById(reminderId);
    if (target == null) return;
    await _repo.markReminder(
      targetUserId: target.targetUserId,
      planId: target.planId,
      scheduleId: target.scheduleId,
      dueTime: target.scheduledTime,
      action: 'taken',
      actionSource: 'elder_page',
    );
    await refreshFromApi();
  }

  Future<void> snoozeById(String reminderId, {int minutes = 10}) async {
    final target = findById(reminderId);
    if (target == null) return;
    await _repo.snoozeReminder(
      targetUserId: target.targetUserId,
      planId: target.planId,
      scheduleId: target.scheduleId,
      dueTime: target.scheduledTime,
      snoozeMinutes: minutes,
      actionSource: 'elder_page',
    );
    await refreshFromApi();
  }

  Future<void> skipById(String reminderId) async {
    final target = findById(reminderId);
    if (target == null) return;
    await _repo.markReminder(
      targetUserId: target.targetUserId,
      planId: target.planId,
      scheduleId: target.scheduleId,
      dueTime: target.scheduledTime,
      action: 'skipped',
      actionSource: 'elder_page',
    );
    await refreshFromApi();
  }

  void clearSnoozeBanner() {
    state = ElderHomeState(
      todayRecords: state.todayRecords,
      carePlans: state.carePlans,
      familyMembers: state.familyMembers,
      weeklyTrend: state.weeklyTrend,
      streakDays: state.streakDays,
      snoozeUntil: null,
      snoozeMessage: null,
      loading: state.loading,
    );
  }

  List<ElderTodayIntakeRecord> _toTodayRecords(List<ReminderItem> rows) {
    final items = rows
        .where((r) => r.status != 'deleted')
        .map(
          (r) => ElderTodayIntakeRecord(
            id: r.id,
            targetUserId: r.targetUserId,
            planId: r.planId,
            scheduleId: r.scheduleId,
            scheduledTime: r.dueTime.toLocal(),
            medicineName: r.medicineName,
            dosageLabel: '按医嘱',
            status: _mapStatus(r.status),
            snoozeUntil: r.snoozeUntil?.toLocal(),
          ),
        )
        .toList();
    items.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return items;
  }

  List<ElderDayTrend> _toTrend(List<AdherencePoint> rows) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return rows
        .map((r) => ElderDayTrend(
              weekdayLabel: labels[r.date.weekday - 1],
              completedDoses: r.taken,
              scheduledDoses: r.total,
            ))
        .toList();
  }

  int _computeStreak(List<AdherencePoint> rows) {
    var streak = 0;
    for (final r in rows.reversed) {
      if (r.total > 0 && r.taken >= r.total) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  DateTime? _findActiveSnooze(List<ElderTodayIntakeRecord> rows) {
    final now = DateTime.now();
    DateTime? latest;
    for (final r in rows) {
      if (r.status == IntakeRecordStatus.snoozed && r.snoozeUntil != null && r.snoozeUntil!.isAfter(now)) {
        if (latest == null || r.snoozeUntil!.isAfter(latest)) latest = r.snoozeUntil;
      }
    }
    return latest;
  }

  IntakeRecordStatus _mapStatus(String raw) {
    switch (raw) {
      case 'taken':
        return IntakeRecordStatus.taken;
      case 'snoozed':
        return IntakeRecordStatus.snoozed;
      case 'notified':
        return IntakeRecordStatus.notified;
      case 'missed':
        return IntakeRecordStatus.missed;
      case 'skipped':
        return IntakeRecordStatus.skipped;
      case 'deleted':
        return IntakeRecordStatus.deleted;
      default:
        return IntakeRecordStatus.pending;
    }
  }
}

final elderHomeControllerProvider =
    StateNotifierProvider<ElderHomeController, ElderHomeState>((ref) {
  return ElderHomeController(ref);
});
