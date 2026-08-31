import '../../../core/services/daily_state_restore_service.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../repositories/app_repository_container.dart';
import '../../operation_date/models/operation_state.dart';
import '../models/backup_package.dart';
import 'backup_import_planner.dart';
import 'backup_canonical_codec.dart';
import 'backup_store_registry.dart';
import '../../system/models/profile_model.dart';

typedef BackupRestoreState = Future<void> Function();

class BackupImportService {
  final IndexedDbDatabase _database;
  final AppInitializationController _controller;
  final BackupRestoreState _restore;
  bool _executing = false;

  BackupImportService({
    IndexedDbDatabase? database,
    AppInitializationController? controller,
    BackupRestoreState? restore,
  }) : _database = database ?? AppRepositoryRegistry.container.database,
       _controller = controller ?? AppRepositoryRegistry.controller,
       _restore =
           restore ?? (() => DailyStateRestoreService.restore(force: true));

  Future<BackupImportPlan> dryRun(
    BackupPackage package,
    BackupImportMode mode,
  ) {
    if (_controller.value.mode != PersistenceMode.indexedDbReadWrite) {
      throw const BackupException(
        'import_unavailable',
        'Backup import requires IndexedDB read/write mode.',
      );
    }
    return BackupImportPlanner(_database).createPlan(package, mode);
  }

  Future<BackupImportResult> execute(BackupImportPlan approvedPlan) async {
    if (_executing ||
        _controller.value.mode != PersistenceMode.indexedDbReadWrite) {
      return const BackupImportResult.failure(
        errorCode: 'import_busy',
        message: 'Another persistence operation is active.',
      );
    }
    if (approvedPlan.hasBlockingConflicts) {
      return const BackupImportResult.failure(
        errorCode: 'import_conflict',
        message: 'Conflicts must be resolved before import.',
      );
    }
    _executing = true;
    var committed = false;
    final controllerBefore = _controller.value;
    Map<String, List<Map<String, Object?>>>? preRestoreState;
    _controller.markMaintenance();
    try {
      final replaceAllSections =
          approvedPlan.mode == BackupImportMode.replaceAll
          ? BackupSections.allCurrent
                .where(
                  (section) =>
                      section != BackupSections.operationState ||
                      approvedPlan.package.schemaVersion >= 3,
                )
                .toList()
          : const <String>[];
      final affectedSections = approvedPlan.mode == BackupImportMode.replaceAll
          ? replaceAllSections
          : approvedPlan.package.includedSections.where(
              (section) => section != BackupSections.operationState,
            );
      preRestoreState = await _captureState(affectedSections);
      final currentPlan = await BackupImportPlanner(
        _database,
      ).createPlan(approvedPlan.package, approvedPlan.mode);
      if (currentPlan.hasBlockingConflicts ||
          !_plansEqual(approvedPlan, currentPlan)) {
        throw const BackupException(
          'import_plan_changed',
          'Repository contents changed after dry run.',
        );
      }
      final sections = approvedPlan.package.includedSections
          .where(
            (section) =>
                approvedPlan.mode == BackupImportMode.replaceAll ||
                section != BackupSections.operationState,
          )
          .toList();
      final transactionSections =
          approvedPlan.mode == BackupImportMode.replaceAll
          ? replaceAllSections
          : sections;
      await _database.runTransaction<void>(
        storeNames: [
          for (final section in transactionSections)
            BackupStoreRegistry.stores[section]!,
        ],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          if (approvedPlan.mode == BackupImportMode.replaceAll) {
            for (final section in replaceAllSections) {
              await transaction.clear(BackupStoreRegistry.stores[section]!);
            }
          }
          for (final section in sections) {
            final store = BackupStoreRegistry.stores[section]!;
            final sectionPlan = approvedPlan.sections[section]!;
            for (final record in approvedPlan.package.data[section]!) {
              if (approvedPlan.mode == BackupImportMode.merge) {
                final id = BackupStoreRegistry.recordId(section, record);
                if (sectionPlan.conflictingRecordIds.contains(id)) continue;
                final existing = await transaction.findById(
                  store,
                  section == BackupSections.profile
                      ? ProfileModel.recordId
                      : BackupStoreRegistry.recordId(section, record),
                );
                if (existing != null) {
                  final comparableExisting = section == BackupSections.profile
                      ? ProfileModel.fromRecord(existing).toBackupRecord()
                      : existing;
                  if (!BackupStoreRegistry.recordsEqual(
                    section,
                    comparableExisting,
                    record,
                  )) {
                    throw BackupException(
                      'import_conflict',
                      '$section changed after dry run.',
                    );
                  }
                  continue;
                }
              }
              await transaction.put(
                store,
                section == BackupSections.profile
                    ? ProfileModel.fromBackupRecord(
                        record,
                      ).toRecord(now: DateTime.now().toUtc())
                    : record,
              );
            }
          }
          for (final section in sections) {
            await _verifySection(
              approvedPlan,
              section,
              await transaction.findAll(BackupStoreRegistry.stores[section]!),
            );
          }
          if (approvedPlan.mode == BackupImportMode.replaceAll) {
            for (final section in replaceAllSections.where(
              (section) =>
                  !approvedPlan.package.includedSections.contains(section),
            )) {
              final records = await transaction.findAll(
                BackupStoreRegistry.stores[section]!,
              );
              if (records.isNotEmpty) {
                throw BackupException(
                  'post_import_verification_failed',
                  '$section was not cleared for the restored schema.',
                );
              }
            }
          }
        },
      );
      committed = true;
      await _verifyApplied(approvedPlan);
      _controller.updateStage(InitializationStage.restoringDailyState);
      await _restore();
      if (!await _validateCurrentDatabase(
        requireOperationState:
            approvedPlan.mode == BackupImportMode.replaceAll &&
            approvedPlan.package.schemaVersion >= 3,
      )) {
        throw const BackupException(
          'post_import_validation_failed',
          'Restored database failed startup-equivalent validation.',
        );
      }
      _controller.markReady();
      final restoresOperationState =
          approvedPlan.mode == BackupImportMode.replaceAll &&
          approvedPlan.package.schemaVersion >= 3;
      final recoveryRequired = restoresOperationState
          ? OperationState.fromRecord(
              approvedPlan.package.data[BackupSections.operationState]!.single,
            ).requiresRecovery
          : false;
      return BackupImportResult.success(
        operationStateRestored: restoresOperationState,
        recoveryRequired: recoveryRequired,
      );
    } catch (error) {
      if (committed && preRestoreState != null) {
        try {
          _controller.markMaintenance();
          await _restoreCapturedState(preRestoreState);
          await _verifyCapturedState(preRestoreState);
          _controller.updateStage(InitializationStage.restoringDailyState);
          await _restore();
          if (!await _validateCurrentDatabase()) {
            throw const BackupException(
              'import_failed',
              'CRITICAL RESTORE FAILURE: Original database validation failed.',
            );
          }
          _controller.value = controllerBefore;
        } catch (rollbackError) {
          _controller.markFailed(
            errorCode: 'import_failed',
            errorMessage:
                'CRITICAL RESTORE FAILURE: ${rollbackError.toString()}',
          );
          return BackupImportResult.failure(
            errorCode: 'import_failed',
            message: 'CRITICAL RESTORE FAILURE: ${rollbackError.toString()}',
          );
        }
      }
      final healthy = await _validateCurrentDatabase();
      final backupError = error is BackupException ? error : null;
      if (healthy) {
        _controller.value = controllerBefore;
      } else {
        _controller.markFailed(
          errorCode: backupError?.code ?? 'import_failed',
          errorMessage: backupError?.message ?? error.toString(),
        );
      }
      return BackupImportResult.failure(
        errorCode: backupError?.code ?? 'import_failed',
        message: backupError?.message ?? error.toString(),
      );
    } finally {
      _executing = false;
    }
  }

  Future<Map<String, List<Map<String, Object?>>>> _captureState(
    Iterable<String> sections,
  ) async {
    final captured = <String, List<Map<String, Object?>>>{};
    for (final section in sections) {
      captured[section] = await _database.findAll(
        BackupStoreRegistry.stores[section]!,
      );
    }
    return captured;
  }

  Future<void> _restoreCapturedState(
    Map<String, List<Map<String, Object?>>> captured,
  ) {
    return _database.runTransaction<void>(
      storeNames: [
        for (final section in captured.keys)
          BackupStoreRegistry.stores[section]!,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        for (final section in captured.keys) {
          final store = BackupStoreRegistry.stores[section]!;
          await transaction.clear(store);
          for (final record in captured[section]!) {
            await transaction.put(store, record);
          }
        }
      },
    );
  }

  Future<void> _verifyCapturedState(
    Map<String, List<Map<String, Object?>>> captured,
  ) async {
    for (final entry in captured.entries) {
      final restored = await _database.findAll(
        BackupStoreRegistry.stores[entry.key]!,
      );
      if (!_rawRecordListsEqual(restored, entry.value)) {
        throw BackupException(
          'import_failed',
          'CRITICAL RESTORE FAILURE: ${entry.key} was not restored.',
        );
      }
    }
  }

  Future<void> _verifyApplied(BackupImportPlan plan) async {
    for (final section in plan.package.includedSections) {
      if (plan.mode == BackupImportMode.merge &&
          section == BackupSections.operationState) {
        continue;
      }
      await _verifySection(
        plan,
        section,
        await _database.findAll(BackupStoreRegistry.stores[section]!),
      );
    }
  }

  Future<void> _verifySection(
    BackupImportPlan plan,
    String section,
    List<Map<String, Object?>> stored,
  ) async {
    final comparable = section == BackupSections.profile
        ? [
            for (final record in stored)
              ProfileModel.fromRecord(record).toBackupRecord(),
          ]
        : stored;
    final actual = BackupStoreRegistry.validateAndSort(section, comparable);
    final incoming = plan.package.data[section]!;
    if (plan.mode == BackupImportMode.replaceAll) {
      if (!_recordListsEqual(actual, incoming)) {
        throw BackupException(
          'post_import_verification_failed',
          '$section does not match the replacement package.',
        );
      }
      return;
    }
    final sectionPlan = plan.sections[section]!;
    if (actual.length != sectionPlan.existing + sectionPlan.add) {
      throw BackupException(
        'post_import_count_mismatch',
        '$section count does not match the approved import plan.',
      );
    }
    final actualById = {
      for (final record in actual)
        BackupStoreRegistry.recordId(section, record): record,
    };
    for (final record in incoming) {
      final id = BackupStoreRegistry.recordId(section, record);
      if (sectionPlan.conflictingRecordIds.contains(id)) continue;
      final actualRecord = actualById[id];
      if (actualRecord == null ||
          !BackupStoreRegistry.recordsEqual(section, actualRecord, record)) {
        throw BackupException(
          'post_import_verification_failed',
          '$section failed post-import verification.',
        );
      }
    }
  }

  Future<bool> _validateCurrentDatabase({
    bool requireOperationState = false,
  }) async {
    try {
      for (final section in BackupSections.allCurrent) {
        if (section == BackupSections.operationState) continue;
        final records = await _database.findAll(
          BackupStoreRegistry.stores[section]!,
        );
        if (section == BackupSections.profile) {
          if (records.length > 1) return false;
          if (records.isNotEmpty) ProfileModel.fromRecord(records.single);
        } else {
          BackupStoreRegistry.validateAndSort(section, records);
        }
      }
      final operationRecords = await _database.findAll(
        BackupStoreRegistry.stores[BackupSections.operationState]!,
      );
      if (operationRecords.isEmpty) return !requireOperationState;
      if (operationRecords.length != 1) return false;
      BackupStoreRegistry.validateAndSort(
        BackupSections.operationState,
        operationRecords,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _plansEqual(BackupImportPlan first, BackupImportPlan second) {
    if (first.mode != second.mode ||
        first.sections.length != second.sections.length) {
      return false;
    }
    for (final entry in first.sections.entries) {
      final other = second.sections[entry.key];
      if (other == null ||
          entry.value.existing != other.existing ||
          entry.value.add != other.add ||
          entry.value.skip != other.skip ||
          entry.value.replace != other.replace ||
          entry.value.conflicts.join('\u0000') !=
              other.conflicts.join('\u0000') ||
          entry.value.conflictingRecordIds
              .difference(other.conflictingRecordIds)
              .isNotEmpty ||
          other.conflictingRecordIds
              .difference(entry.value.conflictingRecordIds)
              .isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  static bool _recordListsEqual(
    List<Map<String, Object?>> first,
    List<Map<String, Object?>> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (!BackupStoreRegistry.envelopesEqual(first[index], second[index])) {
        return false;
      }
    }
    return true;
  }

  static bool _rawRecordListsEqual(
    List<Map<String, Object?>> first,
    List<Map<String, Object?>> second,
  ) {
    if (first.length != second.length) return false;
    final firstEncoded = first.map(BackupCanonicalCodec.encode).toList()
      ..sort();
    final secondEncoded = second.map(BackupCanonicalCodec.encode).toList()
      ..sort();
    for (var index = 0; index < firstEncoded.length; index++) {
      if (firstEncoded[index] != secondEncoded[index]) return false;
    }
    return true;
  }
}
