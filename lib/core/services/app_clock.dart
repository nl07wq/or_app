import 'package:flutter/foundation.dart';

class AppClock {
  AppClock._();

  static DateTime? _testDateOverride;
  static DateTime Function() _systemNow = DateTime.now;

  static DateTime now() {
    final override = _testDateOverride;
    if (kDebugMode && override != null) return override;
    return _systemNow();
  }

  static DateTime today() {
    final now = AppClock.now();
    return DateTime(now.year, now.month, now.day);
  }

  @visibleForTesting
  static bool get hasDebugDateOverride =>
      kDebugMode && _testDateOverride != null;

  @visibleForTesting
  static void setDebugDate(DateTime date) {
    if (!kDebugMode) return;
    _testDateOverride = DateTime(date.year, date.month, date.day);
  }

  @visibleForTesting
  static void clearDebugDateOverride() {
    if (!kDebugMode) return;
    _testDateOverride = null;
  }

  @visibleForTesting
  static void resetForTesting() {
    _testDateOverride = null;
    _systemNow = DateTime.now;
  }

  @visibleForTesting
  static void setSystemNowForTesting(DateTime Function() systemNow) {
    _systemNow = systemNow;
  }
}
