import 'package:flutter/foundation.dart';

enum PersistenceMode {
  initializing,
  indexedDbReadWrite,
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

  const AppInitializationState({
    required this.mode,
    required this.currentStage,
    this.errorCode,
    this.errorMessage,
    this.failedMigrationId,
    this.retryAllowed = false,
  });

  const AppInitializationState.initializing({
    this.currentStage = InitializationStage.openingDatabase,
  }) : mode = PersistenceMode.initializing,
       errorCode = null,
       errorMessage = null,
       failedMigrationId = null,
       retryAllowed = false;

  bool get isReadOnly => mode == PersistenceMode.legacyReadOnly;
  bool get canWrite => mode == PersistenceMode.indexedDbReadWrite;

  AppInitializationState copyWith({
    PersistenceMode? mode,
    InitializationStage? currentStage,
    String? errorCode,
    String? errorMessage,
    String? failedMigrationId,
    bool? retryAllowed,
  }) {
    return AppInitializationState(
      mode: mode ?? this.mode,
      currentStage: currentStage ?? this.currentStage,
      errorCode: errorCode,
      errorMessage: errorMessage,
      failedMigrationId: failedMigrationId,
      retryAllowed: retryAllowed ?? this.retryAllowed,
    );
  }
}

class AppInitializationController
    extends ValueNotifier<AppInitializationState> {
  AppInitializationController()
    : super(const AppInitializationState.initializing());

  void updateStage(InitializationStage stage) {
    value = AppInitializationState.initializing(currentStage: stage);
  }

  void markReady() {
    value = const AppInitializationState(
      mode: PersistenceMode.indexedDbReadWrite,
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
