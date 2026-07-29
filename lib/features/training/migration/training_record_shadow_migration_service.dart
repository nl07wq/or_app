import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../models/persisted_training_record.dart';
import '../repository/training_record_id_generator.dart';
import 'training_record_lineage.dart';
import 'training_v2_migration_executor.dart';
import 'training_v2_migration_mapper.dart';

class TrainingRecordShadowMigrationService {
  static const migrationId = TrainingRecordLineage.shadowMigrationId;
  static const source = TrainingRecordLineage.shadowSourceSystem;
  static const sourceSection = IndexedDbStoreNames.trainingRecords;

  final IndexedDbDatabase _database;
  final DateTime Function()? _now;
  final String? _ownerId;

  const TrainingRecordShadowMigrationService(
    this._database, {
    this._now,
    this._ownerId,
  });

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
    final raw = await _sourceRecords();
    final candidates = <TrainingV2MigrationCandidate>[];
    final problems = <TrainingV2MigrationProblem>[];
    for (var index = 0; index < raw.length; index++) {
      final value = raw[index];
      final sourceId = value['id'] is String
          ? value['id']! as String
          : 'invalid-source-$index';
      try {
        final sourceRecord = PersistedTrainingRecord.fromRecord(value);
        final sourceLineage = TrainingRecordLineage.shadowSource(
          sourceRecordId: sourceRecord.id,
          sourceIndex: TrainingRecordLineage.sourceIndexFor(sourceRecord.id),
        );
        candidates.add(
          TrainingV2MigrationCandidate(
            sourceId: sourceRecord.id,
            sourceIndex: index,
            rawPayload: value,
            target: TrainingV2MigrationMapper.map(
              targetId: TrainingRecordLineage.shadowIdForV1(sourceRecord.id),
              localDate: sourceRecord.localDate,
              createdAt: sourceRecord.createdAt,
              updatedAt: sourceRecord.updatedAt,
              migrationSource: sourceLineage,
              source: sourceRecord.data,
            ),
          ),
        );
      } on TrainingV2MappingException catch (error) {
        problems.add(
          TrainingV2MigrationProblem(
            sourceId: sourceId,
            sourceIndex: index,
            rawPayload: value,
            category: error.needsReview ? 'needs-review' : 'invalid',
            errorCode: error.code,
            errorMessage: error.message,
          ),
        );
      } catch (error) {
        problems.add(
          TrainingV2MigrationProblem(
            sourceId: sourceId,
            sourceIndex: index,
            rawPayload: value,
            category: 'invalid',
            errorCode: 'invalidV1Record',
            errorMessage: error.toString(),
          ),
        );
      }
    }
    return TrainingV2MigrationPlan(
      sourceCount: raw.length,
      sourceIds: [
        for (var index = 0; index < raw.length; index++)
          raw[index]['id'] is String
              ? raw[index]['id']! as String
              : 'invalid-source-$index',
      ],
      sourcePayloads: raw,
      candidates: candidates,
      problems: problems,
    );
  }

  Future<List<Map<String, Object?>>> _sourceRecords() async {
    final values = await _database.findAll(IndexedDbStoreNames.trainingRecords);
    final sources = values
        .where(
          (record) =>
              record['recordVersion'] ==
              PersistedTrainingRecord.legacyRecordVersion,
        )
        .toList();
    sources.sort(
      (first, second) => (first['id']?.toString() ?? '').compareTo(
        second['id']?.toString() ?? '',
      ),
    );
    return sources;
  }

  Future<bool> _verifySourceUnchanged(TrainingV2MigrationPlan plan) async {
    final current = await _sourceRecords();
    return _canonicalList(current) == _canonicalList(plan.sourcePayloads);
  }

  static String _canonicalList(Iterable<Object?> values) {
    final result = values.map(TrainingLegacyIdGenerator.canonicalJson).toList()
      ..sort();
    return result.join('\u0000');
  }
}
