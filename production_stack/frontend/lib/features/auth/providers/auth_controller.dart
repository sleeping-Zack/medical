import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_storage.dart';
import '../models/token_pair.dart';
import '../repositories/auth_repository.dart';
import 'auth_state.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final storage = ref.watch(tokenStorageProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AuthController(repo: repo, storage: storage, apiClient: apiClient);
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository repo,
    required TokenStorage storage,
    required ApiClient apiClient,
  })  : _repo = repo,
        _storage = storage,
        _apiClient = apiClient,
        super(AuthState.unknown);

  final AuthRepository _repo;
  final TokenStorage _storage;
  final ApiClient _apiClient;

  Future<void> bootstrap() async {
    state = state.copyWith(isBusy: true);
    try {
      final accessToken = await _storage.readAccessToken();
      final refreshToken = await _storage.readRefreshToken();
      if (accessToken == null || refreshToken == null) {
        _apiClient.setAccessToken(null);
        state = AuthState.unauthenticated;
        return;
      }

      _apiClient.setAccessToken(accessToken);
      state = state.copyWith(accessToken: accessToken, refreshToken: refreshToken);

      try {
        final user = await _repo.me();
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } catch (_) {
        try {
          final pair = await _repo.refresh(refreshToken: refreshToken);
          await _persistTokens(pair);
          final user = await _repo.me();
          state = AuthState(
            status: AuthStatus.authenticated,
            user: user,
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
          );
        } catch (_) {
          await _storage.clear();
          _apiClient.setAccessToken(null);
          state = AuthState.unauthenticated;
        }
      }
    } catch (e, st) {
      // 本地存储异常等会导致一直停在 unknown，路由永远留在启动页
      debugPrint('Auth bootstrap 失败: $e\n$st');
      try {
        await _storage.clear();
      } catch (_) {}
      _apiClient.setAccessToken(null);
      state = AuthState.unauthenticated;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<String?> sendSmsCode({required String phone, required String scene, String? deviceId}) async {
    return _repo.sendSmsCode(phone: phone, scene: scene, deviceId: deviceId);
  }

  Future<void> register({
    required String phone,
    required String code,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(isBusy: true);
    try {
      final pair = await _repo.register(phone: phone, code: code, password: password, role: role);
      await _persistTokens(pair);
      final user = await _repo.me();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> loginWithPassword({required String phone, required String password}) async {
    state = state.copyWith(isBusy: true);
    try {
      final pair = await _repo.loginWithPassword(phone: phone, password: password);
      await _persistTokens(pair);
      final user = await _repo.me();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> loginWithSms({required String phone, required String code}) async {
    state = state.copyWith(isBusy: true);
    try {
      final pair = await _repo.loginWithSms(phone: phone, code: code);
      await _persistTokens(pair);
      final user = await _repo.me();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> resetPassword({required String phone, required String code, required String newPassword}) async {
    state = state.copyWith(isBusy: true);
    try {
      await _repo.resetPassword(phone: phone, code: code, newPassword: newPassword);
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isBusy: true);
    try {
      try {
        await _repo.logout();
      } catch (_) {}
      await _storage.clear();
      _apiClient.setAccessToken(null);
      state = AuthState.unauthenticated;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> _persistTokens(TokenPair pair) async {
    await _storage.saveTokens(accessToken: pair.accessToken, refreshToken: pair.refreshToken);
    _apiClient.setAccessToken(pair.accessToken);
  }
}

