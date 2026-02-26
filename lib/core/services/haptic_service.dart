import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HapticService {
  static bool get _supported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static void light() {
    if (_supported) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (_supported) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (_supported) HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (_supported) HapticFeedback.selectionClick();
  }
}
