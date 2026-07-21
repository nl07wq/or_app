import 'package:flutter/foundation.dart';

class AppClock {
  AppClock._();

  static final ValueNotifier<DateTime?> _debugDateOverride = ValueNotifier(
    null,
  );
  static DateTime Function() _systemNow = DateTime.now;

  static ValueListenable<DateTime?> get debugDateOverride => _debugDateOverride;

  static DateTime now() {
    final override = _debugDateOverride.value;
    if (kDebugMode && override != null) return override;
    return _systemNow();
  }

  static DateTime today() {
    final now = AppClock.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool get hasDebugDateOverride =>
      kDebugMode && _debugDateOverride.value != null;

  static void setDebugDate(DateTime date) {
    if (!kDebugMode) return;
    _debugDateOverride.value = DateTime(date.year, date.month, date.day);
  }

  static void clearDebugDateOverride() {
    if (!kDebugMode) return;
    _debugDateOverride.value = null;
  }

  @visibleForTesting
  static void resetForTesting() {
    _debugDateOverride.value = null;
    _systemNow = DateTime.now;
  }

  @visibleForTesting
  static void setSystemNowForTesting(DateTime Function() systemNow) {
    _systemNow = systemNow;
  }
}
