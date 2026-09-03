import 'package:flutter/foundation.dart';

enum PersistenceMode {
  initializing,
  indexedDbReadWrite,
  maintenance,
  legacyReadOnly,
  failed,
}

enum InitializationStage {
  openingDatabase,
  upgradingSchema,
  checkingMigrations,
  migratingStatus,
  migratingActivity,
  migratingFood,
  migratingTraining,
  migratingCustomTrainingExercises,
  migratingConfirmation,
  verifyingCustomTrainingExercises,
  verifyingRepositories,
  restoringDailyState,
  complete,
}

class AppInitializationState {
  final PersistenceMode mode;
  final InitializationStage currentStage;
  final String? errorCode;
  final String? errorMessage;
  final String? failedMigrationId;
  final bool retryAllowed;
  final bool operationRecoveryRequired;
  final String? operationPhase;
  final bool operationSyncRecoveryRequired;
  final String? operationSyncPhase;

  const AppInitializationState({
    required this.mode,
    required this.currentStage,
    this.errorCode,
    this.errorMessage,
    this.failedMigrationId,
    this.retryAllowed = false,
    this.operationRecoveryRequired = false,
    this.operationPhase,
    this.operationSyncRecoveryRequired = false,
    this.operationSyncPhase,
  });

  const AppInitializationState.initializing({
    this.currentStage = InitializationStage.openingDatabase,
  }) : mode = PersistenceMode.initializing,
       errorCode = null,
       errorMessage = null,
       failedMigrationId = null,
       retryAllowed = false,
       operationRecoveryRequired = false,
       operationPhase = null,
       operationSyncRecoveryRequired = false,
       operationSyncPhase = null;

  bool get isReadOnly => mode == PersistenceMode.legacyReadOnly;
  bool get canWrite => mode == PersistenceMode.indexedDbReadWrite;

  AppInitializationState copyWith({
    PersistenceMode? mode,
    InitializationStage? currentStage,
    String? errorCode,
    String? errorMessage,
    String? failedMigrationId,
    bool? retryAllowed,
    bool? operationRecoveryRequired,
    String? operationPhase,
    bool? operationSyncRecoveryRequired,
    String? operationSyncPhase,
  }) {
    return AppInitializationState(
      mode: mode ?? this.mode,
      currentStage: currentStage ?? this.currentStage,
      errorCode: errorCode,
      errorMessage: errorMessage,
      failedMigrationId: failedMigrationId,
      retryAllowed: retryAllowed ?? this.retryAllowed,
      operationRecoveryRequired:
          operationRecoveryRequired ?? this.operationRecoveryRequired,
      operationPhase: operationPhase ?? this.operationPhase,
      operationSyncRecoveryRequired:
          operationSyncRecoveryRequired ?? this.operationSyncRecoveryRequired,
      operationSyncPhase: operationSyncPhase ?? this.operationSyncPhase,
    );
  }
}

class AppInitializationController
    extends ValueNotifier<AppInitializationState> {
  AppInitializationController()
    : super(const AppInitializationState.initializing());

  // The initial boot presentation belongs to an application initialization
  // session, not to any particular StartupGate widget instance. A root can be
  // rebuilt while the same controller is reinitializing; that must never turn
  // the rebuild into another visual boot sequence.
  bool _initialBootPresentationClaimed = false;

  bool claimInitialBootPresentation() {
    if (_initialBootPresentationClaimed) return false;
    _initialBootPresentationClaimed = true;
    return true;
  }

  void updateStage(InitializationStage stage) {
    value = AppInitializationState.initializing(currentStage: stage);
  }

  void markReady({
    bool operationRecoveryRequired = false,
    String? operationPhase,
    bool operationSyncRecoveryRequired = false,
    String? operationSyncPhase,
  }) {
    value = AppInitializationState(
      mode: PersistenceMode.indexedDbReadWrite,
      currentStage: InitializationStage.complete,
      operationRecoveryRequired: operationRecoveryRequired,
      operationPhase: operationPhase,
      operationSyncRecoveryRequired: operationSyncRecoveryRequired,
      operationSyncPhase: operationSyncPhase,
    );
  }

  void markMaintenance() {
    value = const AppInitializationState(
      mode: PersistenceMode.maintenance,
      currentStage: InitializationStage.complete,
    );
  }

  void markLegacyReadOnly({String? message}) {
    value = AppInitializationState(
      mode: PersistenceMode.legacyReadOnly,
      currentStage: InitializationStage.complete,
      errorMessage: message,
    );
  }

  void markFailed({
    required String errorCode,
    required String errorMessage,
    String? failedMigrationId,
  }) {
    value = AppInitializationState(
      mode: PersistenceMode.failed,
      currentStage: value.currentStage,
      errorCode: errorCode,
      errorMessage: errorMessage,
      failedMigrationId: failedMigrationId,
      retryAllowed: true,
    );
  }
}

final appInitializationController = AppInitializationController();
