import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final biometricEnabledProvider =
    StateNotifierProvider<BiometricEnabledNotifier, bool>((ref) {
  return BiometricEnabledNotifier();
});

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Authenticate to unlock Lunaris'}) async {
    if (!isSupported) return true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}

class BiometricEnabledNotifier extends StateNotifier<bool> {
  static const _key = 'biometric_lock_enabled';

  BiometricEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}
