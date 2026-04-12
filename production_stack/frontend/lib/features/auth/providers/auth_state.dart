import '../models/user_me.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.isBusy = false,
  });

  final AuthStatus status;
  final UserMe? user;
  final String? accessToken;
  final String? refreshToken;
  final bool isBusy;

  AuthState copyWith({
    AuthStatus? status,
    UserMe? user,
    String? accessToken,
    String? refreshToken,
    bool? isBusy,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isBusy: isBusy ?? this.isBusy,
    );
  }

  static const unknown = AuthState(status: AuthStatus.unknown);
  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);
}

