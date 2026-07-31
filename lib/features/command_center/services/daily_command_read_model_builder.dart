import '../../../core/engine/activity_summary.dart';
import '../../../core/engine/food_summary.dart';
import '../../../core/engine/operation_engine.dart';
import '../../../core/engine/operation_input.dart';
import '../../../core/engine/training_summary.dart';
import '../../../core/services/daily_log_confirmation_validation.dart';
import '../../morning/models/morning_fact.dart';
import '../../operation_date/models/operation_state.dart';
import '../models/daily_command_read_model.dart';

abstract final class DailyCommandReadModelBuilder {
  static DailyCommandReadModel build({
    required OperationState operationState,
    required MorningFact? status,
    required FoodSummary? food,
    required TrainingSummary? training,
    required ActivitySummary activity,
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
    final snapshot = input == null
        ? null
        : engine.generateCommanderSnapshot(input);
    final analysis = input == null
        ? null
        : engine.generateCommanderAnalysis(input);
    final phase = operationState.phase;

    return DailyCommandReadModel(
      operationDate: operationState.operationDate.value,
      persistentPhase: phase,
      cycleState: _cycleState(phase, validation),
      operationStatus: snapshot?.status,
      statusReason: analysis?.situation ?? 'STATUSを入力して日次運用を開始してください。',
      commanderIntent: snapshot?.commanderIntent,
      morningBriefSummary: snapshot?.summary,
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
          : engine.estimateTDEE(input) +
                (training?.trainingCardioCaloriesKcal ?? 0),
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
