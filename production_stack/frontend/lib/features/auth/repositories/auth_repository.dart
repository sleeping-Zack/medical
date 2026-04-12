import '../../../core/api/api_client.dart';
import '../models/token_pair.dart';
import '../models/user_me.dart';

class AuthRepository {
  AuthRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<String?> sendSmsCode({
    required String phone,
    required String scene,
    String? deviceId,
  }) async {
    final res = await apiClient.post(
      '/api/v1/auth/sms/send',
      data: {'phone': phone, 'scene': scene, 'device_id': deviceId},
    );
    return _unwrap<String?>(res.data,
        mapper: (d) => (d as Map<String, dynamic>)['debug_code'] as String?);
  }

  Future<TokenPair> register({
    required String phone,
    required String code,
    required String password,
    required String role,
  }) async {
    final res = await apiClient.post(
      '/api/v1/auth/register',
      data: {'phone': phone, 'code': code, 'password': password, 'role': role},
    );
    return _unwrap<TokenPair>(res.data,
        mapper: (d) => TokenPair.fromJson(d as Map<String, dynamic>));
  }

  Future<TokenPair> loginWithPassword(
      {required String phone, required String password}) async {
    final res = await apiClient.post(
      '/api/v1/auth/login/password',
      data: {'phone': phone, 'password': password},
    );
    return _unwrap<TokenPair>(res.data,
        mapper: (d) => TokenPair.fromJson(d as Map<String, dynamic>));
  }

  Future<TokenPair> loginWithSms(
      {required String phone, required String code}) async {
    final res = await apiClient.post(
      '/api/v1/auth/login/sms',
      data: {'phone': phone, 'code': code},
    );
    return _unwrap<TokenPair>(res.data,
        mapper: (d) => TokenPair.fromJson(d as Map<String, dynamic>));
  }

  Future<void> resetPassword(
      {required String phone,
      required String code,
      required String newPassword}) async {
    final res = await apiClient.post(
      '/api/v1/auth/password/reset',
      data: {'phone': phone, 'code': code, 'new_password': newPassword},
    );
    _unwrap<void>(res.data, mapper: (_) => null);
  }

  Future<TokenPair> refresh({required String refreshToken}) async {
    final res = await apiClient.post('/api/v1/auth/refresh', data: {'refresh_token': refreshToken});
    return _unwrap<TokenPair>(res.data,
        mapper: (d) => TokenPair.fromJson(d as Map<String, dynamic>));
  }

  Future<void> logout() async {
    final res = await apiClient.post('/api/v1/auth/logout', data: {});
    _unwrap<void>(res.data, mapper: (_) => null);
  }

  Future<UserMe> me() async {
    final res = await apiClient.get('/api/v1/auth/me');
    return _unwrap<UserMe>(res.data,
        mapper: (d) => UserMe.fromJson(d as Map<String, dynamic>));
  }

  T _unwrap<T>(dynamic raw, {required T Function(dynamic data) mapper}) {
    if (raw is! Map<String, dynamic>) {
      throw ApiException('服务返回格式异常');
    }
    final code = raw['code'];
    final message = raw['message'];
    if (code != 0) {
      throw ApiException((message as String?) ?? '请求失败',
          code: (code as num?)?.toInt());
    }
    return mapper(raw['data']);
  }
}
