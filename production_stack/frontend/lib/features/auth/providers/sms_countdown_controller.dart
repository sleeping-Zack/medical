import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SmsScene { register, login, resetPassword, bind }

String smsSceneToApi(SmsScene scene) {
  switch (scene) {
    case SmsScene.register:
      return 'register';
    case SmsScene.login:
      return 'login';
    case SmsScene.resetPassword:
      return 'reset_password';
    case SmsScene.bind:
      return 'bind';
  }
}

final smsCountdownProvider =
    StateNotifierProvider.family<SmsCountdownController, int, SmsScene>((ref, scene) {
  return SmsCountdownController();
});

class SmsCountdownController extends StateNotifier<int> {
  SmsCountdownController() : super(0);

  Timer? _timer;

  bool get isRunning => state > 0;

  void start({int seconds = 60}) {
    _timer?.cancel();
    state = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state <= 1) {
        timer.cancel();
        state = 0;
      } else {
        state = state - 1;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

