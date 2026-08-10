import '../../../core/engine/activity_summary.dart';
import '../../../core/engine/food_summary.dart';
import '../../../core/engine/operation_engine.dart';
import '../../../core/engine/operation_input.dart';
import '../../../core/engine/operation_status.dart';
import '../../../core/engine/training_summary.dart';
import '../../../core/services/daily_log_confirmation_validation.dart';
import '../../morning/models/morning_fact.dart';
import '../../operation_date/models/operation_state.dart';
import '../../report_sync/models/morning_brief_record.dart';
import '../models/daily_command_read_model.dart';

abstract final class DailyCommandReadModelBuilder {
  static DailyCommandReadModel build({
    required OperationState operationState,
    required MorningFact? status,
    required FoodSummary? food,
    required TrainingSummary? training,
    required ActivitySummary activity,
    double? burnWeightKg,
    MorningBriefRecord? morningBrief,
    bool isHistoricalView = false,
  }) {
    final validation = DailyLogConfirmationValidation.validate(
      morning: status,
      food: food,
      training: training,
      activity: activity,
    );
    final input = status == null
        ? null
        : OperationInput(
            morning: status,
            food: food,
            training: training,
            activity: activity,
          );
    final engine = const OperationEngine();
    final phase = operationState.phase;
    final currentMorningBrief =
        morningBrief?.localDate == operationState.operationDate.value
        ? morningBrief
        : null;

    return DailyCommandReadModel(
      operationDate: operationState.operationDate.value,
      persistentPhase: phase,
      cycleState: _cycleState(phase, validation),
      operationStatus: currentMorningBrief == null
          ? null
          : OperationStatus.values.byName(
              currentMorningBrief.operationStatus.stableId,
            ),
      statusReason:
          currentMorningBrief?.situationAnalysis ?? '当日のMORNING BRIEFが未登録です。',
      commanderIntent: currentMorningBrief?.commanderIntent,
      morningBriefSummary: currentMorningBrief?.argoComment,
      statusModuleState: _requiredState(
        recorded: status != null,
        valid: validation.statusValid,
      ),
      foodModuleState: _requiredState(
        recorded: food != null && food.mealCount > 0,
        valid: validation.foodValid,
      ),
      trainingModuleState: !validation.trainingValid
          ? DailyCommandModuleState.invalid
          : validation.trainingRecorded
          ? DailyCommandModuleState.recorded
          : DailyCommandModuleState.optionalMissing,
      activityModuleState: _requiredState(
        recorded: activity.isRecorded,
        valid: validation.activityValid,
      ),
      validation: validation,
      finalizeBlockingReasons: validation.blockingModules,
      backupState: phase == OperationPhase.open
          ? DailyCommandBackupState.notRequired
          : DailyCommandBackupState.recoveryRequired,
      lastUpdatedAt: operationState.updatedAt,
      isHistoricalView: isHistoricalView,
      estimatedTotalBurnKcal: input == null
          ? null
          : switch (engine.estimateTDEE(input, weightKg: burnWeightKg)) {
              final double base =>
                base + (training?.trainingCardioCaloriesKcal ?? 0),
              null => null,
            },
    );
  }

  static DailyCommandCycleState _cycleState(
    OperationPhase phase,
    DailyLogValidationResult validation,
  ) {
    if (phase == OperationPhase.finalizing) {
      return DailyCommandCycleState.finalizing;
    }
    if (phase == OperationPhase.finalizedPendingBackup ||
        phase == OperationPhase.advancing) {
      return DailyCommandCycleState.recoveryRequired;
    }
    if (!validation.statusValid) return DailyCommandCycleState.standby;
    if (validation.canFinalize) return DailyCommandCycleState.reviewReady;
    return DailyCommandCycleState.active;
  }

  static DailyCommandModuleState _requiredState({
    required bool recorded,
    required bool valid,
  }) {
    if (!recorded) return DailyCommandModuleState.missing;
    return valid
        ? DailyCommandModuleState.recorded
        : DailyCommandModuleState.invalid;
  }
}
