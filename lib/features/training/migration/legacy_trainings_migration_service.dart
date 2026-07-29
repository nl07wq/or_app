import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../models/persisted_training_record.dart';
import '../repository/training_record_id_generator.dart';
import 'legacy_trainings_store_reader.dart';
import 'training_record_lineage.dart';
import 'training_v2_migration_executor.dart';
import 'training_v2_migration_mapper.dart';

class LegacyTrainingsMigrationService {
  static const migrationId = TrainingRecordLineage.legacyStoreMigrationId;
  static const source = TrainingRecordLineage.legacyStoreSourceSystem;
  static const sourceSection = IndexedDbStoreNames.trainings;

  final IndexedDbDatabase _database;
  final LegacyTrainingsStoreReader _reader;
  final DateTime Function()? _now;
  final String? _ownerId;

  LegacyTrainingsMigrationService(
    this._database, {
    LegacyTrainingsStoreReader? reader,
    this._now,
    this._ownerId,
  }) : _reader = reader ?? LegacyTrainingsStoreReader(_database);

  Future<TrainingV2MigrationResult> migrate() {
    return TrainingV2MigrationExecutor(
      _database,
      migrationId: migrationId,
      source: source,
      sourceSection: sourceSection,
      loadPlan: _loadPlan,
      verifySourceUnchanged: _verifySourceUnchanged,
      now: _now,
      ownerId: _ownerId,
    ).migrate();
  }

  Future<TrainingV2MigrationPlan> _loadPlan() async {
    final read = await _reader.read();
    final candidates = <TrainingV2MigrationCandidate>[];
    final problems = <TrainingV2MigrationProblem>[
      for (final invalid in read.invalidRecords)
        TrainingV2MigrationProblem(
          sourceId: invalid.sourceId,
          sourceIndex: invalid.sourceIndex,
          rawPayload: invalid.rawRecord,
          category: 'invalid',
          errorCode: invalid.errorCode,
          errorMessage: invalid.errorMessage,
        ),
    ];
    for (final entry in read.validRecords) {
      try {
        final localDate = PersistedTrainingRecord.localDateFromSession(
          entry.session,
        );
        final timestamp = _sourceTimestamp(entry.session.date, localDate);
        candidates.add(
          TrainingV2MigrationCandidate(
            sourceId: entry.sourceId,
            sourceIndex: entry.sourceIndex,
            rawPayload: entry.rawRecord,
            target: TrainingV2MigrationMapper.map(
              targetId: TrainingRecordLineage.targetIdForLegacyStore(
                entry.sourceId,
              ),
              localDate: localDate,
              createdAt: timestamp,
              updatedAt: timestamp,
              migrationSource: TrainingRecordLineage.legacyStoreSource(
                sourceRecordId: entry.sourceId,
                sourceIndex: TrainingRecordLineage.sourceIndexFor(
                  entry.sourceId,
                ),
              ),
              source: entry.session,
            ),
          ),
        );
      } on TrainingV2MappingException catch (error) {
        problems.add(
          TrainingV2MigrationProblem(
            sourceId: entry.sourceId,
            sourceIndex: entry.sourceIndex,
            rawPayload: entry.rawRecord,
            category: error.needsReview ? 'needs-review' : 'invalid',
            errorCode: error.code,
            errorMessage: error.message,
          ),
        );
      } catch (error) {
        problems.add(
          TrainingV2MigrationProblem(
            sourceId: entry.sourceId,
            sourceIndex: entry.sourceIndex,
            rawPayload: entry.rawRecord,
            category: 'invalid',
            errorCode: 'invalidLegacyStoreRecord',
            errorMessage: error.toString(),
          ),
        );
      }
    }
    return TrainingV2MigrationPlan(
      sourceCount: read.rawRecords.length,
      sourceIds: [
        for (var index = 0; index < read.rawRecords.length; index++)
          read.rawRecords[index]['id'] is String
              ? read.rawRecords[index]['id']! as String
              : 'invalid-source-$index',
      ],
      sourcePayloads: read.rawRecords,
      candidates: candidates,
      problems: problems,
    );
  }

  Future<bool> _verifySourceUnchanged(TrainingV2MigrationPlan plan) async {
    final current = await _reader.read();
    return _canonicalList(current.rawRecords) ==
        _canonicalList(plan.sourcePayloads);
  }

  static DateTime _sourceTimestamp(String date, String localDate) {
    final hasTimeZone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(date);
    final parsed = DateTime.tryParse(hasTimeZone ? date : '${date}Z');
    return (parsed ?? DateTime.parse('${localDate}T00:00:00Z')).toUtc();
  }

  static String _canonicalList(Iterable<Object?> values) {
    final result = values.map(TrainingLegacyIdGenerator.canonicalJson).toList()
      ..sort();
    return result.join('\u0000');
  }
}
