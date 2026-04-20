import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'storage/token_storage.dart';
import '../features/auth/repositories/auth_repository.dart';
import '../features/care/repositories/care_repository.dart';

const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://47.116.25.89:8000',
);

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(secureStorageProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: kApiBaseUrl);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(apiClient: ref.watch(apiClientProvider));
});

final careRepositoryProvider = Provider<CareRepository>((ref) {
  return CareRepository(apiClient: ref.watch(apiClientProvider));
});

