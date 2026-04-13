import '../../../core/api/api_client.dart';
import '../models/bound_elder.dart';
import '../models/medicine_item.dart';
import '../models/plan_item.dart';

class CareRepository {
  CareRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<BoundElder> createBinding({
    required String elderShortId,
    required String phoneLast4,
  }) async {
    final res = await apiClient.post(
      '/api/v1/bindings',
      data: {
        'elder_short_id': elderShortId.trim(),
        'phone_last4': phoneLast4.trim(),
      },
    );
    return _unwrap(res.data, (d) => BoundElder.fromJson(d as Map<String, dynamic>));
  }

  Future<List<BoundElder>> listBindings() async {
    final res = await apiClient.get('/api/v1/bindings');
    return _unwrap(res.data, (d) {
      final list = d as List<dynamic>;
      return list.map((e) => BoundElder.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  Future<List<MedicineItem>> listMedicines({required int targetUserId}) async {
    final res = await apiClient.get(
      '/api/v1/care/medicines',
      queryParameters: {'target_user_id': targetUserId},
    );
    return _unwrap(res.data, (d) {
      final list = d as List<dynamic>;
      return list.map((e) => MedicineItem.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  Future<MedicineItem> createMedicine({
    required int targetUserId,
    required String name,
    String? specification,
    String? note,
  }) async {
    final spec = specification?.trim();
    final nt = note?.trim();
    final res = await apiClient.post(
      '/api/v1/care/medicines',
      data: {
        'target_user_id': targetUserId,
        'name': name.trim(),
        'specification': (spec == null || spec.isEmpty) ? null : spec,
        'note': (nt == null || nt.isEmpty) ? null : nt,
      },
    );
    return _unwrap(res.data, (d) => MedicineItem.fromJson(d as Map<String, dynamic>));
  }

  Future<List<PlanItem>> listPlans({required int targetUserId}) async {
    final res = await apiClient.get(
      '/api/v1/care/plans',
      queryParameters: {'target_user_id': targetUserId},
    );
    return _unwrap(res.data, (d) {
      final list = d as List<dynamic>;
      return list.map((e) => PlanItem.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  Future<PlanItem> createPlan({
    required int targetUserId,
    required int medicineId,
    required String startDateIso,
    required List<Map<String, dynamic>> schedules,
    String? label,
  }) async {
    final lb = label?.trim();
    final res = await apiClient.post(
      '/api/v1/care/plans',
      data: {
        'target_user_id': targetUserId,
        'medicine_id': medicineId,
        'start_date': startDateIso,
        'schedules': schedules,
        'label': (lb == null || lb.isEmpty) ? null : lb,
      },
    );
    return _unwrap(res.data, (d) => PlanItem.fromJson(d as Map<String, dynamic>));
  }

  T _unwrap<T>(dynamic raw, T Function(dynamic data) mapper) {
    if (raw is! Map<String, dynamic>) {
      throw ApiException('服务返回格式异常');
    }
    final code = raw['code'];
    final message = raw['message'];
    if (code != 0) {
      throw ApiException((message as String?) ?? '请求失败', code: (code as num?)?.toInt());
    }
    return mapper(raw['data']);
  }
}
