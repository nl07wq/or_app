import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../import_export/models/backup_package.dart';
import '../../training/models/persisted_training_record.dart';
import '../../training/services/exercise_name_localization.dart';
import '../models/operation_sync_issue.dart';
import '../models/operation_transfer_package.dart';
import '../services/operation_sync_module_adapter.dart';
import '../services/operation_sync_validator.dart';

class TrainingOperationSyncAdapter
    extends IndexedDbOperationTransferModuleAdapter {
  static const _customType = 'customTrainingExercise';
  static const _trainingType = 'trainingRecord';

  TrainingOperationSyncAdapter(IndexedDbDatabase database)
    : super(
        database: database,
        policies: [
          OperationSyncRecordPolicy(
            recordType: _customType,
            storeName: IndexedDbStoreNames.customTrainingExercises,
            backupSection: BackupSections.customExercises,
            recordVersions: const {1},
            dateBound: false,
            matches: (record) => record['recordVersion'] == 1,
            uniqueFields: const ['normalizedName'],
          ),
          OperationSyncRecordPolicy(
            recordType: _trainingType,
            storeName: IndexedDbStoreNames.trainingRecords,
            backupSection: BackupSections.training,
            recordVersions: const {1, 2},
            dateBound: true,
            matches: (record) =>
                record['recordVersion'] == 1 || record['recordVersion'] == 2,
          ),
        ],
      );

  @override
  String get module => 'training';

  @override
  String get schemaVersion => '1.0';

  @override
  Future<List<OperationSyncIssue>> inspectReferences(
    OperationSyncParsedRecord record,
    OperationSyncInspectionContext context,
  ) async {
    final missing = await _missingCustomExerciseKeys(
      record,
      incomingRecords: context.recordsFor(module),
      storedRecords: await database.findAll(
        IndexedDbStoreNames.customTrainingExercises,
      ),
    );
    return [
      for (final key in missing)
        OperationSyncIssue(
          level: OperationSyncIssueLevel.blocking,
          code: OperationSyncIssueCode.referenceConflict,
          message: 'Custom Training Exercise is unavailable: $key.',
          module: module,
          recordId: record.source.recordId,
        ),
    ];
  }

  @override
  Future<void> validateReferencesInTransaction(
    OperationSyncParsedRecord record,
    IndexedDbTransaction transaction,
    OperationSyncInspectionContext context,
  ) async {
    final missing = await _missingCustomExerciseKeys(
      record,
      incomingRecords: const [],
      storedRecords: await transaction.findAll(
        IndexedDbStoreNames.customTrainingExercises,
      ),
    );
    if (missing.isNotEmpty) {
      throw const OperationSyncException(
        OperationSyncIssueCode.referenceConflict,
        'Custom Training Exercise reference is unavailable.',
      );
    }
  }

  Future<Set<String>> _missingCustomExerciseKeys(
    OperationSyncParsedRecord record, {
    required Iterable<dynamic> incomingRecords,
    required Iterable<Map<String, Object?>> storedRecords,
  }) async {
    if (record.envelope.recordType != _trainingType ||
        record.source.recordVersion != 2) {
      return const {};
    }
    final persisted = PersistedTrainingRecord.fromRecord(
      record.envelope.record,
    );
    final available = <String>{
      for (final stored in storedRecords)
        if (stored['normalizedName'] is String)
          stored['normalizedName']! as String,
    };
    for (final source in incomingRecords) {
      if (source is! OperationTransferRecord) continue;
      final candidate = parseRecord(source);
      if (candidate.envelope.recordType == _customType) {
        final key = candidate.envelope.record['normalizedName'];
        if (key is String) available.add(key);
      }
    }
    final missing = <String>{};
    for (final exercise in persisted.dataV2.exercises) {
      if (_isBuiltIn(exercise.exerciseName)) continue;
      final key = exerciseIdentityKey(exercise.exerciseName);
      if (!available.contains(key)) missing.add(key);
    }
    return missing;
  }

  static bool _isBuiltIn(String name) {
    final trimmed = name.trim();
    final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return exerciseDisplayName(trimmed) != trimmed ||
        exerciseIdentityKey(trimmed) != normalized;
  }
}
