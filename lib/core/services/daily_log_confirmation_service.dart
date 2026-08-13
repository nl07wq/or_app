import '../engine/activity_summary.dart';
import '../engine/food_summary.dart';
import '../engine/training_summary.dart';
import '../../features/activity/models/activity_summary_state.dart';
import '../../features/food/models/food_summary_state.dart';
import '../../features/morning/models/morning_fact_state.dart';
import '../../features/training/models/training_summary_state.dart';
import '../../features/morning/models/morning_fact.dart';
import '../../features/daily_log_confirmation/services/daily_log_reopen_service.dart';
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

class DailyLogSourceSnapshot {
  const DailyLogSourceSnapshot({
    required this.morning,
    required this.food,
    required this.activity,
    required this.training,
    required this.validation,
  });

  final MorningFact? morning;
  final FoodSummary? food;
  final ActivitySummary activity;
  final TrainingSummary? training;
  final DailyLogValidationResult validation;
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
    final snapshot = await loadSourceSnapshot(localDate);
    if (!snapshot.validation.canFinalize) {
      throw DailyLogValidationException(snapshot.validation.blockingModules);
    }
    if (estimatedTotalBurnKcal != null &&
        (!estimatedTotalBurnKcal.isFinite || estimatedTotalBurnKcal < 0)) {
      throw const FormatException('Invalid estimated total burn.');
    }

    final confirmation = DailyLogConfirmation(
      date: targetDate,
      confirmedAt: confirmedAt ?? DateTime.now(),
      morning: snapshot.morning,
      food: snapshot.food,
      activity: snapshot.activity,
      training: snapshot.training,
      estimatedTotalBurnKcal: estimatedTotalBurnKcal,
    );

    return confirmation;
  }

  static Future<DailyLogValidationResult> validateLocalDate(
    String localDate,
  ) async => (await loadSourceSnapshot(localDate)).validation;

  static Future<DailyLogSourceSnapshot> loadSourceSnapshot(
    String localDate,
  ) async {
    final targetDate = DateTime.parse(localDate);
    if (_formatLocalDate(targetDate) != localDate) {
      throw const FormatException('Invalid confirmation local date.');
    }
    final morning = await loadMorningFact(localDate: localDate);
    final food = await loadFoodSummary(localDate: localDate);
    final activity = await loadActivitySummary(localDate: localDate);
    final training = await loadTrainingSummary(localDate: localDate);
    return DailyLogSourceSnapshot(
      morning: morning,
      food: food,
      activity: activity,
      training: training,
      validation: DailyLogConfirmationValidation.validate(
        morning: morning,
        food: food,
        activity: activity,
        training: training,
      ),
    );
  }

  /// Reopens an explicitly selected finalized day without deleting its
  /// confirmation Snapshot.
  static Future<void> reopenDate(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    await DailyLogReopenService.production().reopen(
      _formatLocalDate(normalizedDate),
    );
  }

  static String _formatLocalDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
