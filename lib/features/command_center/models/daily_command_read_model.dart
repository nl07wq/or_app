import '../../../core/engine/operation_status.dart';
import '../../../core/services/daily_log_confirmation_validation.dart';
import '../../operation_date/models/operation_state.dart';

enum DailyCommandCycleState {
  standby,
  active,
  reviewReady,
  awaitingDebrief,
  finalizeReady,
  finalizing,
  recoveryRequired,
}

enum DailyCommandModuleState { missing, recorded, invalid, optionalMissing }

enum DailyCommandBackupState { notRequired, recoveryRequired }

/// Presentation-neutral completion detail sourced from the canonical Daily Log
/// validation result. Consumers may format this for their own surface without
/// re-evaluating completion requirements.
class DailyCommandCompletionItem {
  const DailyCommandCompletionItem({
    required this.label,
    required this.state,
    required this.missingRequirements,
  });

  final String label;
  final DailyCommandModuleState state;
  final List<String> missingRequirements;

  bool get isComplete => state == DailyCommandModuleState.recorded;

  String get displayState => switch (state) {
    DailyCommandModuleState.missing => 'NOT RECORDED',
    DailyCommandModuleState.invalid => 'INCOMPLETE',
    DailyCommandModuleState.recorded => 'COMPLETE',
    DailyCommandModuleState.optionalMissing => 'NOT RECORDED',
  };
}

class DailyCommandReadModel {
  final String operationDate;
  final OperationPhase persistentPhase;
  final DailyCommandCycleState cycleState;
  final OperationStatus? operationStatus;
  final String statusReason;

  /// The canonical concise status rationale when the current DAILY BRIEF
  /// provides one. The full [statusReason] remains available to the surfaces
  /// that need the complete analysis.
  final String statusReasonSummary;
  final String? commanderIntent;
  final String? morningBriefSummary;
  final DailyCommandModuleState statusModuleState;
  final DailyCommandModuleState foodModuleState;
  final DailyCommandModuleState trainingModuleState;
  final DailyCommandModuleState activityModuleState;
  final DailyLogValidationResult validation;
  final List<DailyLogModule> finalizeBlockingReasons;
  final DailyCommandBackupState backupState;
  final DateTime lastUpdatedAt;
  final bool isHistoricalView;
  final double? estimatedTotalBurnKcal;

  const DailyCommandReadModel({
    required this.operationDate,
    required this.persistentPhase,
    required this.cycleState,
    required this.operationStatus,
    required this.statusReason,
    required this.statusReasonSummary,
    required this.commanderIntent,
    required this.morningBriefSummary,
    required this.statusModuleState,
    required this.foodModuleState,
    required this.trainingModuleState,
    required this.activityModuleState,
    required this.validation,
    required this.finalizeBlockingReasons,
    required this.backupState,
    required this.lastUpdatedAt,
    required this.isHistoricalView,
    required this.estimatedTotalBurnKcal,
  });

  bool get canPrepareDailyDebrief =>
      !isHistoricalView &&
      persistentPhase == OperationPhase.open &&
      validation.canFinalize;

  bool get recoveryRequired =>
      cycleState == DailyCommandCycleState.recoveryRequired;

  DailyCommandCompletionItem get statusCompletion => DailyCommandCompletionItem(
    label: 'STATUS',
    state: statusModuleState,
    missingRequirements: validation.statusCompleteness.missingRequirements,
  );

  DailyCommandCompletionItem get foodCompletion => DailyCommandCompletionItem(
    label: 'FOOD',
    state: foodModuleState,
    missingRequirements: validation.foodCompleteness.missingRequirements,
  );

  DailyCommandCompletionItem get activityCompletion =>
      DailyCommandCompletionItem(
        label: 'ACTIVITY',
        state: activityModuleState,
        missingRequirements:
            validation.activityCompleteness.missingRequirements,
      );

  DailyCommandCompletionItem get trainingCompletion =>
      DailyCommandCompletionItem(
        label: 'TRAINING',
        state: trainingModuleState,
        missingRequirements: const [],
      );
}
