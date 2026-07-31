import '../../features/activity/models/activity_summary_state.dart';
import '../../features/food/models/food_summary_state.dart';
import '../../features/morning/models/morning_fact_state.dart';
import '../../features/training/models/training_summary_state.dart';
import '../models/daily_log_confirmation.dart';
import '../models/daily_log_confirmation_status.dart';
import '../repositories/daily_log_confirmation_repository.dart';
import 'daily_log_confirmation_state.dart';
import 'daily_log_confirmation_validation.dart';

class DailyLogValidationException implements Exception {
  final List<DailyLogModule> invalidModules;

  const DailyLogValidationException(this.invalidModules);

  @override
  String toString() {
    final labels = invalidModules
        .map(DailyLogConfirmationValidation.moduleLabel)
        .join(', ');
    return 'Daily Log validation failed: $labels.';
  }
}

class DailyLogConfirmationService {
  DailyLogConfirmationService._();

  static Future<DailyLogConfirmation> confirmToday({
    double? estimatedTotalBurnKcal,
  }) async {
    final now = DateTime.now();
    final confirmation = await buildForLocalDate(
      _formatLocalDate(now),
      estimatedTotalBurnKcal: estimatedTotalBurnKcal,
      confirmedAt: now,
    );

    await DailyLogConfirmationRepository.save(confirmation);
    dailyLogConfirmationNotifier.value = DailyLogConfirmationStatus.confirmed(
      confirmation,
    );
    return confirmation;
  }

  static Future<DailyLogConfirmation> buildForLocalDate(
    String localDate, {
    double? estimatedTotalBurnKcal,
    DateTime? confirmedAt,
  }) async {
    final targetDate = DateTime.parse(localDate);
    if (_formatLocalDate(targetDate) != localDate) {
      throw const FormatException('Invalid confirmation local date.');
    }
    await refreshMorningFact(localDate: localDate);
    await refreshFoodSummary(localDate: localDate);
    await refreshActivitySummary(localDate: localDate);
    await refreshTrainingSummary(localDate: localDate);

    final morning = morningFactNotifier.value;
    final food = foodSummaryNotifier.value;
    final activity = activitySummaryNotifier.value;
    final training = trainingSummaryNotifier.value;
    final validation = DailyLogConfirmationValidation.validate(
      morning: morning,
      food: food,
      activity: activity,
      training: training,
    );
    if (!validation.canFinalize) {
      throw DailyLogValidationException(validation.blockingModules);
    }
    if (estimatedTotalBurnKcal != null &&
        (!estimatedTotalBurnKcal.isFinite || estimatedTotalBurnKcal < 0)) {
      throw const FormatException('Invalid estimated total burn.');
    }

    final confirmation = DailyLogConfirmation(
      date: targetDate,
      confirmedAt: confirmedAt ?? DateTime.now(),
      morning: morning,
      food: food,
      activity: activity,
      training: training,
      estimatedTotalBurnKcal: estimatedTotalBurnKcal,
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

  static String _formatLocalDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
