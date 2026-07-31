import 'package:flutter/foundation.dart';

import '../../data/indexed_db/indexed_db_database.dart';
import '../../data/indexed_db/indexed_db_migration_metadata.dart';
import '../../data/indexed_db/indexed_db_schema.dart';
import '../../data/indexed_db/indexed_db_store_names.dart';
import '../../features/activity/migration/activity_legacy_reader.dart';
import '../../features/activity/migration/activity_migration_service.dart';
import '../../features/daily_log_confirmation/migration/daily_log_confirmation_legacy_reader.dart';
import '../../features/daily_log_confirmation/migration/daily_log_confirmation_migration_service.dart';
import '../../features/food/migration/food_legacy_reader.dart';
import '../../features/food/migration/food_migration_service.dart';
import '../../features/operation_date/services/operation_state_bootstrap_service.dart';
import '../../features/repositories/app_repository_container.dart';
import '../../features/repositories/repository_exception.dart';
import '../../features/status/migration/status_legacy_reader.dart';
import '../../features/status/migration/status_migration_service.dart';
import '../../features/training/migration/training_legacy_reader.dart';
import '../../features/training/migration/legacy_trainings_migration_service.dart';
import '../../features/training/migration/training_migration_service.dart';
import '../../features/training/migration/training_record_shadow_migration_service.dart';
import '../../features/training/migration/custom_training_exercise_legacy_reader.dart';
import '../../features/training/migration/custom_training_exercise_migration_service.dart';
import '../../features/training/repository/indexed_db_custom_training_exercise_repository.dart';
import '../state/app_initialization_state.dart';
import 'daily_state_restore_service.dart';

typedef DatabaseOpener = Future<IndexedDbDatabase> Function();
typedef RestoreDailyState = Future<void> Function();

class StartupInitializationService {
  final AppInitializationController controller;
  final DatabaseOpener _openDatabase;
  final RestoreDailyState _restore;
  final bool _isWeb;
  final Future<void> Function(Duration duration) _delay;

  Future<void>? _inFlight;
  String? _failedMigrationId;

  StartupInitializationService({
    AppInitializationController? controller,
    DatabaseOpener? openDatabase,
    RestoreDailyState? restore,
    bool? isWeb,
    Future<void> Function(Duration duration)? delay,
  }) : controller = controller ?? appInitializationController,
       _openDatabase = openDatabase ?? openIndexedDbDatabase,
       _restore =
           restore ?? (() => DailyStateRestoreService.restore(force: true)),
       _isWeb = isWeb ?? kIsWeb,
       _delay = delay ?? Future<void>.delayed;

  Future<void> initialize() {
    final active = _inFlight;
    if (active != null) return active;
    final future = _initialize();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<void> retry() => initialize();

  Future<void> openLegacyReadOnly() async {
    AppRepositoryRegistry.clear();
    controller.markLegacyReadOnly(
      message: 'Legacy data is available in read-only mode.',
    );
    try {
      final invalidRecordCount = await _legacyInvalidRecordCount();
      if (invalidRecordCount > 0) {
        controller.markLegacyReadOnly(
          message:
              '$invalidRecordCount legacy record(s) could not be read. '
              'Valid records remain available.',
        );
      }
      await _restore();
    } catch (error) {
      controller.markFailed(
        errorCode: RepositoryErrorCode.verificationFailed.name,
        errorMessage: 'Legacy data could not be restored.',
      );
      rethrow;
    }
  }

  Future<int> _legacyInvalidRecordCount() async {
    final counts = await Future.wait<int>([
      StatusLegacyReader().read().then((value) => value.invalidRecords.length),
      ActivityLegacyReader().read().then(
        (value) => value.invalidRecords.length,
      ),
      FoodLegacyReader().read().then((value) => value.invalidRecords.length),
      TrainingLegacyReader().read().then(
        (value) => value.invalidRecords.length,
      ),
      CustomTrainingExerciseLegacyReader().read().then(
        (value) => value.invalidRecords.length,
      ),
      DailyLogConfirmationLegacyReader().read().then(
        (value) => value.invalidRecords.length,
      ),
    ]);
    return counts.fold<int>(0, (total, count) => total + count);
  }

  Future<void> _initialize() async {
    AppRepositoryRegistry.beginStartup(controller: controller);
    _failedMigrationId = null;
    controller.updateStage(InitializationStage.openingDatabase);

    if (!_isWeb) {
      await openLegacyReadOnly();
      return;
    }

    try {
      final database = await _openDatabase();
      controller.updateStage(InitializationStage.upgradingSchema);
      if (IndexedDbSchema.databaseVersion != 5) {
        throw RepositoryException(
          operation: 'startup.schema',
          code: RepositoryErrorCode.verificationFailed,
          cause: StateError('IndexedDB Schema Version 5 is required.'),
        );
      }

      controller.updateStage(InitializationStage.checkingMigrations);
      await _runMigration(
        database,
        StatusMigrationService.migrationId,
        InitializationStage.migratingStatus,
        () => StatusMigrationService(database).migrate(),
      );
      await _runMigration(
        database,
        ActivityMigrationService.migrationId,
        InitializationStage.migratingActivity,
        () => ActivityMigrationService(database).migrate(),
      );
      await _runMigration(
        database,
        FoodMigrationService.migrationId,
        InitializationStage.migratingFood,
        () => FoodMigrationService(database).migrate(),
      );
      await _runMigration(
        database,
        TrainingMigrationService.migrationId,
        InitializationStage.migratingTraining,
        () => TrainingMigrationService(database).migrate(),
      );
      await _runMigration(
        database,
        TrainingRecordShadowMigrationService.migrationId,
        InitializationStage.migratingTraining,
        () => TrainingRecordShadowMigrationService(database).migrate(),
      );
      await _runMigration(
        database,
        LegacyTrainingsMigrationService.migrationId,
        InitializationStage.migratingTraining,
        () => LegacyTrainingsMigrationService(database).migrate(),
      );
      await _runMigration(
        database,
        CustomTrainingExerciseMigrationService.migrationId,
        InitializationStage.migratingCustomTrainingExercises,
        () => CustomTrainingExerciseMigrationService(database).migrate(),
      );
      await _runMigration(
        database,
        DailyLogConfirmationMigrationService.migrationId,
        InitializationStage.migratingConfirmation,
        () => DailyLogConfirmationMigrationService(database).migrate(),
      );

      controller.updateStage(InitializationStage.verifyingRepositories);
      await _verifyMetadata(database);
      final container = AppRepositoryContainer.indexedDb(database);
      await _verifyRepositories(container);
      final operationState = await OperationStateBootstrapService(
        container.operationState,
        container.confirmation,
      ).bootstrap();
      AppRepositoryRegistry.install(container);

      controller.updateStage(InitializationStage.restoringDailyState);
      await _restore();
      controller.markReady(
        operationRecoveryRequired: operationState.recoveryRequired,
        operationPhase: operationState.state.phase.name,
      );
    } catch (error) {
      AppRepositoryRegistry.clear();
      final repositoryError = error is RepositoryException ? error : null;
      controller.markFailed(
        errorCode: (repositoryError?.code ?? _errorCodeFor(error)).name,
        errorMessage: 'Application data initialization failed.',
        failedMigrationId: _failedMigrationId,
      );
    }
  }

  RepositoryErrorCode _errorCodeFor(Object error) {
    if (error is UnsupportedError) {
      return RepositoryErrorCode.platformUnsupported;
    }
    return switch (controller.value.currentStage) {
      InitializationStage.openingDatabase ||
      InitializationStage.upgradingSchema =>
        RepositoryErrorCode.databaseOpenFailed,
      InitializationStage.checkingMigrations ||
      InitializationStage.migratingStatus ||
      InitializationStage.migratingActivity ||
      InitializationStage.migratingFood ||
      InitializationStage.migratingTraining ||
      InitializationStage.migratingCustomTrainingExercises ||
      InitializationStage.migratingConfirmation =>
        RepositoryErrorCode.migrationFailed,
      InitializationStage.verifyingCustomTrainingExercises ||
      InitializationStage.verifyingRepositories ||
      InitializationStage.restoringDailyState ||
      InitializationStage.complete => RepositoryErrorCode.verificationFailed,
    };
  }

  Future<void> _runMigration(
    IndexedDbDatabase database,
    String migrationId,
    InitializationStage stage,
    Future<Object?> Function() run,
  ) async {
    _failedMigrationId = migrationId;
    controller.updateStage(stage);

    while (true) {
      final metadata = await _readMetadata(database, migrationId);
      final now = DateTime.now().toUtc();
      if (metadata != null &&
          metadata.status != IndexedDbMigrationStatus.completed &&
          metadata.leaseExpiresAt?.isAfter(now) == true) {
        await _delay(const Duration(milliseconds: 250));
        continue;
      }
      try {
        await run();
        _failedMigrationId = null;
        return;
      } on RepositoryException {
        final latest = await _readMetadata(database, migrationId);
        if (latest != null &&
            latest.status != IndexedDbMigrationStatus.failed &&
            latest.status != IndexedDbMigrationStatus.completed &&
            latest.leaseExpiresAt?.isAfter(DateTime.now().toUtc()) == true) {
          await _delay(const Duration(milliseconds: 250));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<IndexedDbMigrationMetadata?> _readMetadata(
    IndexedDbDatabase database,
    String id,
  ) async {
    final value = await database.findById(
      IndexedDbStoreNames.migrationMetadata,
      id,
    );
    return value == null ? null : IndexedDbMigrationMetadata.fromRecord(value);
  }

  Future<void> _verifyMetadata(IndexedDbDatabase database) async {
    for (final id in [
      StatusMigrationService.migrationId,
      ActivityMigrationService.migrationId,
      FoodMigrationService.migrationId,
      TrainingMigrationService.migrationId,
      TrainingRecordShadowMigrationService.migrationId,
      LegacyTrainingsMigrationService.migrationId,
      CustomTrainingExerciseMigrationService.migrationId,
      DailyLogConfirmationMigrationService.migrationId,
    ]) {
      final metadata = await _readMetadata(database, id);
      if (metadata?.status != IndexedDbMigrationStatus.completed ||
          !IndexedDbSchema.supportsMigrationMetadataVersion(
            metadata!.targetDatabaseVersion,
          )) {
        throw RepositoryException(
          operation: 'startup.verifyMetadata',
          code: RepositoryErrorCode.verificationFailed,
          cause: StateError('Migration is incomplete: $id'),
        );
      }
    }
  }

  Future<void> _verifyRepositories(AppRepositoryContainer container) async {
    final status = await container.status.findAllCanonical();
    if (status.hasIssues) {
      throw _verificationFailure('STATUS contains unreadable records.');
    }
    await container.activity.findAll();
    await container.activityDrafts.findAll();
    await container.food.findAll();
    await container.training.findAll();
    controller.updateStage(
      InitializationStage.verifyingCustomTrainingExercises,
    );
    final customRepository = container.customTrainingExercises;
    if (customRepository is IndexedDbCustomTrainingExerciseRepository) {
      final result = await customRepository.findAllWithIssues();
      if (result.hasIssues) {
        throw _verificationFailure(
          'Custom Training Exercises contain unreadable records.',
        );
      }
    } else {
      await customRepository.findAll();
    }
    controller.updateStage(InitializationStage.verifyingRepositories);
    await container.confirmation.findAll();
  }

  RepositoryException _verificationFailure(String message) {
    return RepositoryException(
      operation: 'startup.verifyRepositories',
      code: RepositoryErrorCode.verificationFailed,
      cause: StateError(message),
    );
  }
}
