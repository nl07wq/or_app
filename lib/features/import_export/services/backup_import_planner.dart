import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../models/backup_package.dart';
import 'backup_store_registry.dart';
import 'backup_operation_state_integrity.dart';
import '../../system/models/profile_model.dart';

class BackupImportPlanner {
  final IndexedDbDatabase _database;

  const BackupImportPlanner(this._database);

  Future<BackupImportPlan> createPlan(
    BackupPackage package,
    BackupImportMode mode,
  ) async {
    if (package.schemaVersion >= 3) {
      BackupOperationStateIntegrity.validate(package.data);
    }
    if (package.isLegacyConverted && mode != BackupImportMode.merge) {
      throw const BackupException(
        'legacy_replace_forbidden',
        'Schema 1.0 backups support MERGE only.',
      );
    }
    final plans = <String, BackupSectionPlan>{};
    for (final section in package.includedSections) {
      final stored = await _database.findAll(
        BackupStoreRegistry.stores[section]!,
      );
      final existing = section == BackupSections.profile
          ? stored.isEmpty
                ? <Map<String, Object?>>[]
                : BackupStoreRegistry.validateAndSort(section, [
                    ProfileModel.fromRecord(stored.single).toBackupRecord(),
                  ])
          : BackupStoreRegistry.validateAndSort(section, stored);
      final incoming = package.data[section] ?? const [];
      if (mode == BackupImportMode.replaceAll) {
        plans[section] = BackupSectionPlan(
          existing: existing.length,
          replace: incoming.length,
        );
        continue;
      }
      if (section == BackupSections.operationState) {
        plans[section] = BackupSectionPlan(existing: existing.length);
        continue;
      }
      final existingById = {
        for (final record in existing)
          BackupStoreRegistry.recordId(section, record): record,
      };
      var skip = 0;
      final conflicts = <String>[];
      final conflictingRecordIds = <String>{};
      final missingRecordIds = <String>{};
      for (final record in incoming) {
        final id = BackupStoreRegistry.recordId(section, record);
        final match = existingById[id];
        if (match == null) {
          missingRecordIds.add(id);
        } else if (BackupStoreRegistry.recordsEqual(section, match, record)) {
          skip++;
        } else {
          conflicts.add('$section:$id');
          conflictingRecordIds.add(id);
        }
      }
      _findUniqueConflicts(
        section,
        existing,
        incoming,
        conflicts,
        conflictingRecordIds,
      );
      plans[section] = BackupSectionPlan(
        existing: existing.length,
        add: missingRecordIds.difference(conflictingRecordIds).length,
        skip: skip,
        conflicts: conflicts,
        conflictingRecordIds: conflictingRecordIds,
      );
    }
    return BackupImportPlan(package: package, mode: mode, sections: plans);
  }

  static void _findUniqueConflicts(
    String section,
    List<Map<String, Object?>> existing,
    List<Map<String, Object?>> incoming,
    List<String> conflicts,
    Set<String> conflictingRecordIds,
  ) {
    String? uniqueField;
    if (section == BackupSections.status ||
        section == BackupSections.activity) {
      uniqueField = 'canonicalDate';
    } else if (section == BackupSections.customExercises) {
      uniqueField = 'normalizedName';
    }
    if (uniqueField == null) return;
    final byValue = <Object, String>{};
    for (final record in existing) {
      final value = record[uniqueField];
      if (value != null) {
        byValue[value] = BackupStoreRegistry.recordId(section, record);
      }
    }
    for (final record in incoming) {
      final value = record[uniqueField];
      if (value == null) continue;
      final existingId = byValue[value];
      final incomingId = BackupStoreRegistry.recordId(section, record);
      if (existingId != null && existingId != incomingId) {
        conflicts.add('$section:$uniqueField:$value');
        conflictingRecordIds.add(incomingId);
      }
    }
  }
}
