import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/providers.dart';
import '../../../routing/app_router.dart';
import '../models/reminder_item.dart';

const _kTakeActionId = 'take_now';
const _kSnoozeActionId = 'snooze_10m';
const _kSkipActionId = 'skip_today';
const _kOverdueCatchupWindow = Duration(minutes: 1);

/// 独立高优先级渠道，与普通消息区分；首次安装后渠道属性不可改，故使用 v2 id 以便升级默认铃声用途为闹钟。
const _kAlarmChannelId = 'medication_reminders_alarm_v2';

bool get _isAndroid => !kIsWeb && Platform.isAndroid;

bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

@pragma('vm:entry-point')
void reminderNotificationTapBackground(NotificationResponse response) {}

final reminderNotificationServiceProvider = Provider<ReminderNotificationService>((ref) {
  final service = ReminderNotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class ReminderNotificationService {
  ReminderNotificationService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: reminderNotificationTapBackground,
    );
    await _ensureAndroidAlarmChannel();
    await _requestAndroidPermissions();
    if (_isIos) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
    _initialized = true;
  }

  /// 请求「全屏通知」相关系统授权（Android 14+ 常见）；无插件状态查询，建议在「提醒保障设置」页引导用户。
  Future<void> requestAndroidFullScreenIntentPermission() async {
    await ensureInitialized();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestFullScreenIntentPermission();
  }

  /// 必须与设备时区一致，否则 zonedSchedule 会排到错误时刻（常见为「完全不响」）。
  Future<void> _configureLocalTimeZone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('[reminder] tz.local set to $name');
    } catch (e) {
      debugPrint('[reminder] timezone fallback: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      } catch (_) {
        // 最后兜底：保持 package 默认
      }
    }
  }

  Future<void> _ensureAndroidAlarmChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kAlarmChannelId,
        '服药闹钟提醒',
        description: '到点全屏/高优先级服药提醒，与普通消息分离',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  Future<void> syncTodayReminders({
    required List<ReminderItem> reminders,
  }) async {
    await ensureInitialized();
    await _plugin.cancelAll();
    debugPrint('[reminder] syncing ${reminders.length} reminders');
    final now = DateTime.now();
    final canExact = await _androidCanScheduleExactAlarms();
    if (_isAndroid && canExact == false) {
      debugPrint('[reminder] exact alarms not allowed — using inexact scheduling (see 提醒保障设置)');
    }
    for (final r in reminders) {
      if (_isDone(r.status)) continue;
      final rawWhen = (r.snoozeUntil ?? r.dueTime).toLocal();
      var when = rawWhen;
      // 仅对「刚刚过期」的提醒做一次短时补排；历史过期项直接跳过，避免一次性同时轰炸提醒。
      final overdueBy = now.difference(when);
      final bumpedForOverdue = overdueBy > Duration.zero;
      if (bumpedForOverdue && overdueBy <= _kOverdueCatchupWindow) {
        when = now.add(const Duration(seconds: 4));
      } else if (bumpedForOverdue) {
        debugPrint(
          '[reminder] skip overdue reminder ${r.id}: overdue=${overdueBy.inMinutes}m status=${r.status}',
        );
        continue;
      }
      debugPrint('[reminder] schedule ${r.id} at $when, status=${r.status} bumped=$bumpedForOverdue');
      await _scheduleReminder(
        item: r,
        at: when,
        preferExact: canExact != false,
      );
    }
  }

  Future<bool?> _androidCanScheduleExactAlarms() async {
    if (!_isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return android?.canScheduleExactNotifications();
  }

  NotificationDetails _notificationDetails({
    required ReminderItem item,
    required bool fullScreenIntent,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _kAlarmChannelId,
        '服药闹钟提醒',
        channelDescription: '到点全屏/高优先级服药提醒',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ticker: '该吃药啦',
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        fullScreenIntent: fullScreenIntent,
        actions: const [
          AndroidNotificationAction(_kTakeActionId, '我已服药'),
          AndroidNotificationAction(_kSnoozeActionId, '稍后 10 分钟'),
          AndroidNotificationAction(_kSkipActionId, '今日不吃'),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  Future<void> _scheduleReminder({
    required ReminderItem item,
    required DateTime at,
    required bool preferExact,
  }) async {
    final id = _notificationId(item);
    final payload = jsonEncode({
      'id': item.id,
      'target_user_id': item.targetUserId,
      'plan_id': item.planId,
      'schedule_id': item.scheduleId,
      'due_time': item.dueTime.toIso8601String(),
      'medicine_name': item.medicineName,
    });

    final scheduledDetails = _notificationDetails(item: item, fullScreenIntent: _isAndroid);
    final scheduled = tz.TZDateTime.from(at, tz.local);

    Future<void> doSchedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          '该吃药啦',
          '请服用${item.medicineName}，点开可立即处理',
          scheduled,
          scheduledDetails,
          payload: payload,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: null,
        );

    // Android：优先 alarmClock（setAlarmClock），在多数机型上比「无精确闹钟权限时的 inexact」准时得多。
    if (_isAndroid) {
      try {
        await doSchedule(AndroidScheduleMode.alarmClock);
        debugPrint('[reminder] zoned id=$id mode=alarmClock when=$scheduled');
      } catch (e) {
        debugPrint('[reminder] alarmClock failed, try exact: $e');
        if (preferExact) {
          try {
            await doSchedule(AndroidScheduleMode.exactAllowWhileIdle);
            debugPrint('[reminder] zoned id=$id mode=exactAllowWhileIdle when=$scheduled');
          } catch (e2) {
            debugPrint('[reminder] exact failed, fallback inexact: $e2');
            await doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
            debugPrint('[reminder] zoned id=$id mode=inexactAllowWhileIdle when=$scheduled');
          }
        } else {
          await doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
          debugPrint('[reminder] zoned id=$id mode=inexactAllowWhileIdle when=$scheduled');
        }
      }
    } else {
      await doSchedule(AndroidScheduleMode.exactAllowWhileIdle);
      debugPrint('[reminder] zoned id=$id (non-Android) when=$scheduled');
    }

  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final targetUserId = (map['target_user_id'] as num?)?.toInt();
    final planId = (map['plan_id'] as num?)?.toInt();
    final scheduleId = map['schedule_id'] as String?;
    final dueTime = DateTime.tryParse(map['due_time'] as String? ?? '');
    if (targetUserId == null || planId == null || scheduleId == null || dueTime == null) return;

    final actionId = response.actionId;
    if (actionId == _kTakeActionId || actionId == _kSnoozeActionId || actionId == _kSkipActionId) {
      final repo = _ref.read(careRepositoryProvider);
      if (actionId == _kTakeActionId) {
        await repo.markReminder(
          targetUserId: targetUserId,
          planId: planId,
          scheduleId: scheduleId,
          dueTime: dueTime,
          action: 'taken',
          actionSource: 'elder_notify',
        );
      } else if (actionId == _kSkipActionId) {
        await repo.markReminder(
          targetUserId: targetUserId,
          planId: planId,
          scheduleId: scheduleId,
          dueTime: dueTime,
          action: 'skipped',
          actionSource: 'elder_notify',
        );
      } else {
        await repo.snoozeReminder(
          targetUserId: targetUserId,
          planId: planId,
          scheduleId: scheduleId,
          dueTime: dueTime,
          snoozeMinutes: 10,
          actionSource: 'elder_notify',
        );
      }
    }

    final id = Uri.encodeComponent(map['id'] as String? ?? '');
    _ref.read(goRouterProvider).go('/elder/reminder/$id');
  }

  Future<void> _requestAndroidPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
  }

  bool _isDone(String status) {
    final s = status.toLowerCase();
    return s == 'taken' || s == 'missed' || s == 'skipped' || s == 'deleted';
  }

  int _notificationId(ReminderItem r) {
    return Object.hash(r.planId, r.scheduleId, r.dueTime.millisecondsSinceEpoch) & 0x7fffffff;
  }

  void dispose() {}
}
