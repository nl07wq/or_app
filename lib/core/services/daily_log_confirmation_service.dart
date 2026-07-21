import '../../features/activity/models/activity_summary_state.dart';
import '../../features/food/models/food_summary_state.dart';
import '../../features/morning/models/morning_fact_state.dart';
import '../../features/training/models/training_summary_state.dart';
import '../models/daily_log_confirmation.dart';
import '../models/daily_log_confirmation_status.dart';
import '../repositories/daily_log_confirmation_repository.dart';
import 'daily_log_confirmation_state.dart';

class DailyLogConfirmationService {
  DailyLogConfirmationService._();

  static Future<DailyLogConfirmation> confirmToday() async {
    await refreshMorningFact();
    await refreshFoodSummary();
    await refreshActivitySummary();
    await refreshTrainingSummary();

    final morning = morningFactNotifier.value;
    if (morning == null) {
      throw StateError('Morning record is required before confirmation.');
    }

    final confirmation = DailyLogConfirmation(
      date: DateTime.now(),
      confirmedAt: DateTime.now(),
      morning: morning,
      food: foodSummaryNotifier.value,
      activity: activitySummaryNotifier.value.isRecorded
          ? activitySummaryNotifier.value
          : null,
      training: trainingSummaryNotifier.value,
    );

    await DailyLogConfirmationRepository.save(confirmation);
    dailyLogConfirmationNotifier.value = DailyLogConfirmationStatus.confirmed(
      confirmation,
    );
    return confirmation;
  }

  /// Reopens an explicitly selected confirmed calendar day for normal editing.
  ///
  /// This removes only the confirmation snapshot. Source Morning, Food,
  /// Activity, and Training records are intentionally left unchanged.
  static Future<void> reopenDate(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    await DailyLogConfirmationRepository.deleteByDate(normalizedDate);

    final today = DateTime.now();
    if (normalizedDate.year == today.year &&
        normalizedDate.month == today.month &&
        normalizedDate.day == today.day) {
      dailyLogConfirmationNotifier.value =
          DailyLogConfirmationStatus.unconfirmed(normalizedDate);
    }
  }
}
