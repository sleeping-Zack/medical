import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../models/adherence_point.dart';
import '../models/bound_elder.dart';
import '../models/plan_item.dart';
import '../models/reminder_item.dart';

final boundEldersProvider = FutureProvider.autoDispose<List<BoundElder>>((ref) async {
  final repo = ref.watch(careRepositoryProvider);
  return repo.listBindings();
});

final plansForTargetProvider = FutureProvider.autoDispose.family<List<PlanItem>, int>((ref, targetUserId) async {
  final repo = ref.watch(careRepositoryProvider);
  return repo.listPlans(targetUserId: targetUserId);
});

final remindersForTargetTodayProvider = FutureProvider.autoDispose.family<List<ReminderItem>, int>((ref, targetUserId) async {
  final repo = ref.watch(careRepositoryProvider);
  final rows = await repo.listTodayReminders(targetUserId: targetUserId, onDate: DateTime.now());
  return rows.where((r) => r.status != 'deleted').toList();
});

final adherenceForTargetProvider = FutureProvider.autoDispose.family<List<AdherencePoint>, int>((ref, targetUserId) async {
  final repo = ref.watch(careRepositoryProvider);
  return repo.getAdherenceTrend(targetUserId: targetUserId, days: 7);
});
