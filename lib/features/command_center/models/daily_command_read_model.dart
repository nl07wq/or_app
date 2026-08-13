import '../../../core/engine/operation_status.dart';
import '../../../core/services/daily_log_confirmation_validation.dart';
import '../../operation_date/models/operation_state.dart';

enum DailyCommandCycleState {
  standby,
  active,
  reviewReady,
  awaitingDebrief,
  finalizing,
  recoveryRequired,
}

enum DailyCommandModuleState { missing, recorded, invalid, optionalMissing }

enum DailyCommandBackupState { notRequired, recoveryRequired }

class DailyCommandReadModel {
  final String operationDate;
  final OperationPhase persistentPhase;
  final DailyCommandCycleState cycleState;
  final OperationStatus? operationStatus;
  final String statusReason;
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
}
