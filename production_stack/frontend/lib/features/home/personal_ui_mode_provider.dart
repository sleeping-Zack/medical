import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/providers/auth_controller.dart';
import '../auth/providers/auth_state.dart';

/// 与 Web `UserProfile.defaultMode`（`caregiver` | `elder`）一致：仅家属端账号（`role == personal`）可切换；
/// 按用户 id 持久化，对应 Web 的 `profile_${uid}` 中的 defaultMode。
final personalUiModeProvider = StateNotifierProvider<PersonalUiModeNotifier, String>((ref) {
  return PersonalUiModeNotifier(ref);
});

class PersonalUiModeNotifier extends StateNotifier<String> {
  PersonalUiModeNotifier(this._ref) : super('caregiver') {
    _ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (prev?.user?.id != next.user?.id || prev?.user?.role != next.user?.role) {
        Future.microtask(_reloadFromPrefs);
      }
    });
    Future.microtask(_reloadFromPrefs);
  }

  final Ref _ref;

  static String _prefsKey(int userId) => 'personal_default_mode_$userId';

  Future<void> _reloadFromPrefs() async {
    final user = _ref.read(authControllerProvider).user;
    if (user == null || user.role != 'personal') {
      state = 'caregiver';
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(user.id));
    state = (raw == 'elder') ? 'elder' : 'caregiver';
  }

  /// Web：`updateProfile({ defaultMode: 'caregiver' | 'elder' })`
  Future<void> setMode(String mode) async {
    if (mode != 'caregiver' && mode != 'elder') return;
    final user = _ref.read(authControllerProvider).user;
    if (user == null || user.role != 'personal') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(user.id), mode);
    state = mode;
  }
}
