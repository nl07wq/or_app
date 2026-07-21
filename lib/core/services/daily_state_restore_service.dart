import '../../features/activity/models/activity_summary_state.dart';
import '../../features/food/models/food_summary_state.dart';
import '../../features/morning/models/morning_fact_state.dart';
import '../../features/training/models/training_summary_state.dart';
import 'package:flutter/foundation.dart';
import 'daily_log_confirmation_state.dart';

class DailyStateRestoreService {
  DailyStateRestoreService._();

  static Future<void>? _inFlightRestore;
  static bool _hasRestored = false;

  static Future<void> restore() {
    if (_hasRestored) {
      return Future<void>.value();
    }

    final inFlightRestore = _inFlightRestore;
    if (inFlightRestore != null) {
      return inFlightRestore;
    }

    final restoreFuture = _restore();
    _inFlightRestore = restoreFuture;
    return restoreFuture;
  }

  static Future<void> _restore() async {
    try {
      await Future.wait<void>([
        refreshMorningFact(),
        refreshActivitySummary(),
        refreshFoodSummary(),
        refreshTrainingSummary(),
        refreshDailyLogConfirmationStatus(),
      ]);
      _hasRestored = true;
    } finally {
      _inFlightRestore = null;
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _inFlightRestore = null;
    _hasRestored = false;
  }
}
