import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../models/backup_package.dart';
import 'backup_store_registry.dart';
import 'backup_operation_state_integrity.dart';

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
      final existing = BackupStoreRegistry.validateAndSort(
        section,
        await _database.findAll(BackupStoreRegistry.stores[section]!),
      );
      final incoming = package.data[section] ?? const [];
      if (mode == BackupImportMode.replaceAll) {
        plans[section] = BackupSectionPlan(
          existing: existing.length,
          replace: incoming.length,
        );
        continue;
      }
      final existingById = {
        for (final record in existing)
          BackupStoreRegistry.recordId(section, record): record,
      };
      var add = 0;
      var skip = 0;
      final conflicts = <String>[];
      for (final record in incoming) {
        final id = BackupStoreRegistry.recordId(section, record);
        final match = existingById[id];
        if (match == null) {
          add++;
        } else if (BackupStoreRegistry.recordsEqual(section, match, record)) {
          skip++;
        } else {
          conflicts.add('$section:$id');
        }
      }
      _findUniqueConflicts(section, existing, incoming, conflicts);
      plans[section] = BackupSectionPlan(
        existing: existing.length,
        add: add,
        skip: skip,
        conflicts: conflicts,
      );
    }
    if (package.schemaVersion >= 3 && mode == BackupImportMode.merge) {
      final current = plans[BackupSections.operationState]!;
      final conflicts = [...current.conflicts];
      if (current.skip != 1) conflicts.add('operationState:must-match-current');
      if (BackupOperationStateIntegrity.isProcessing(package.data)) {
        conflicts.add('operationState:processing');
      }
      if (conflicts.length != current.conflicts.length) {
        plans[BackupSections.operationState] = BackupSectionPlan(
          existing: current.existing,
          add: current.add,
          skip: current.skip,
          replace: current.replace,
          conflicts: conflicts,
        );
      }
    }
    return BackupImportPlan(package: package, mode: mode, sections: plans);
  }

  static void _findUniqueConflicts(
    String section,
    List<Map<String, Object?>> existing,
    List<Map<String, Object?>> incoming,
    List<String> conflicts,
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
      }
    }
  }
}
