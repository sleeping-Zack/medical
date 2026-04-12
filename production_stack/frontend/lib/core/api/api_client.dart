import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({required String baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
            validateStatus: (status) => status != null && status < 500,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final accessToken = _accessToken;
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  String? _accessToken;

  Dio get dio => _dio;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// 业务错误（4xx）也会返回 JSON，不抛 DioException，交给 Repository 解析 code/message。
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    try {
      return await _dio.post<dynamic>(path, data: data);
    } on DioException catch (e) {
      throw _mapDioFailure(e);
    }
  }

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get<dynamic>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _mapDioFailure(e);
    }
  }

  ApiException _mapDioFailure(DioException e) {
    final body = e.response?.data;
    if (body is Map<String, dynamic>) {
      final msg = body['message'];
      final code = body['code'];
      if (msg is String) {
        return ApiException(
          msg,
          code: code is int ? code : (code is num ? code.toInt() : null),
        );
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('连接超时，请检查网络或 API 地址（模拟器不要用 127.0.0.1）');
      case DioExceptionType.connectionError:
        return ApiException(
          '无法连接服务器。请确认后端已启动；Android 模拟器请使用：'
          'flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000',
        );
      default:
        return ApiException('网络异常，请稍后再试');
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => 'ApiException(code: $code, message: $message)';
}
