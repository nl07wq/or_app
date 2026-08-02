import '../../../core/services/daily_state_restore_service.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../repositories/app_repository_container.dart';
import '../../operation_date/models/operation_state.dart';
import '../models/backup_package.dart';
import 'backup_import_planner.dart';
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
    if (approvedPlan.hasConflicts) {
      return const BackupImportResult.failure(
        errorCode: 'import_conflict',
        message: 'Conflicts must be resolved before import.',
      );
    }
    _executing = true;
    var committed = false;
    _controller.markMaintenance();
    try {
      final currentPlan = await BackupImportPlanner(
        _database,
      ).createPlan(approvedPlan.package, approvedPlan.mode);
      if (currentPlan.hasConflicts || !_plansEqual(approvedPlan, currentPlan)) {
        throw const BackupException(
          'import_plan_changed',
          'Repository contents changed after dry run.',
        );
      }
      final sections = approvedPlan.package.includedSections.toList();
      await _database.runTransaction<void>(
        storeNames: [
          for (final section in sections) BackupStoreRegistry.stores[section]!,
        ],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          if (approvedPlan.mode == BackupImportMode.replaceAll) {
            for (final section in approvedPlan.package.includedSections) {
              await transaction.clear(BackupStoreRegistry.stores[section]!);
            }
          }
          for (final section in sections) {
            final store = BackupStoreRegistry.stores[section]!;
            for (final record in approvedPlan.package.data[section]!) {
              if (approvedPlan.mode == BackupImportMode.merge) {
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
        },
      );
      committed = true;
      await _verifyApplied(approvedPlan);
      await _restore();
      if (!await _validateCurrentDatabase(
        requireOperationState: approvedPlan.package.schemaVersion >= 3,
      )) {
        throw const BackupException(
          'post_import_validation_failed',
          'Restored database failed startup-equivalent validation.',
        );
      }
      _controller.markReady();
      final restoresOperationState = approvedPlan.package.schemaVersion >= 3;
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
      final healthy = await _validateCurrentDatabase();
      final backupError = error is BackupException ? error : null;
      if (!committed && healthy) {
        _controller.markReady();
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

  Future<void> _verifyApplied(BackupImportPlan plan) async {
    for (final section in plan.package.includedSections) {
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
      final actualRecord =
          actualById[BackupStoreRegistry.recordId(section, record)];
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
      for (final section in BackupSections.schema8) {
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
              other.conflicts.join('\u0000')) {
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
}
