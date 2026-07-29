import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_migration_metadata.dart';
import '../../../data/indexed_db/indexed_db_quarantined_record.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_training_record.dart';
import '../repository/training_record_id_generator.dart';
import 'training_record_lineage.dart';

part 'training_v2_migration_integrity.dart';
part 'training_v2_migration_metadata_service.dart';
part 'training_v2_migration_transaction.dart';

class TrainingV2MigrationCandidate {
  final String sourceId;
  final int sourceIndex;
  final Object? rawPayload;
  final PersistedTrainingRecord target;

  const TrainingV2MigrationCandidate({
    required this.sourceId,
    required this.sourceIndex,
    required this.rawPayload,
    required this.target,
  });
}

class TrainingV2MigrationProblem {
  final String sourceId;
  final int sourceIndex;
  final Object? rawPayload;
  final String category;
  final String errorCode;
  final String errorMessage;

  const TrainingV2MigrationProblem({
    required this.sourceId,
    required this.sourceIndex,
    required this.rawPayload,
    required this.category,
    required this.errorCode,
    required this.errorMessage,
  });
}

class TrainingV2MigrationPlan {
  final int sourceCount;
  final List<String> sourceIds;
  final List<Object?> sourcePayloads;
  final List<TrainingV2MigrationCandidate> candidates;
  final List<TrainingV2MigrationProblem> problems;

  TrainingV2MigrationPlan({
    required this.sourceCount,
    required Iterable<String> sourceIds,
    required Iterable<Object?> sourcePayloads,
    required Iterable<TrainingV2MigrationCandidate> candidates,
    required Iterable<TrainingV2MigrationProblem> problems,
  }) : sourceIds = List.unmodifiable(sourceIds),
       sourcePayloads = List.unmodifiable(sourcePayloads),
       candidates = List.unmodifiable(candidates),
       problems = List.unmodifiable(problems) {
    if (candidates.length + problems.length != sourceCount) {
      throw const FormatException(
        'TRAINING v2 migration source counts differ.',
      );
    }
  }
}

class TrainingV2MigrationResult {
  final bool alreadyCompleted;
  final int sourceCount;
  final int validCount;
  final int invalidCount;
  final int needsReviewCount;
  final int conflictCount;
  final int writtenCount;
  final int skippedCount;
  final Set<String> targetIds;
  final Set<String> quarantineIds;

  TrainingV2MigrationResult({
    required this.alreadyCompleted,
    required this.sourceCount,
    required this.validCount,
    required this.invalidCount,
    required this.needsReviewCount,
    required this.conflictCount,
    required this.writtenCount,
    required this.skippedCount,
    required Iterable<String> targetIds,
    required Iterable<String> quarantineIds,
  }) : targetIds = Set.unmodifiable(targetIds),
       quarantineIds = Set.unmodifiable(quarantineIds);
}

typedef TrainingV2MigrationPlanLoader =
    Future<TrainingV2MigrationPlan> Function();
typedef TrainingV2SourceVerifier =
    Future<bool> Function(TrainingV2MigrationPlan plan);

class TrainingV2MigrationExecutor {
  final String migrationId;
  final String sourceSection;
  final TrainingV2MigrationPlanLoader loadPlan;
  final TrainingV2SourceVerifier verifySourceUnchanged;
  final TrainingV2MigrationMetadataService _metadata;
  final TrainingV2MigrationTransaction _transaction;
  final TrainingV2MigrationIntegrity _integrity;

  TrainingV2MigrationExecutor(
    IndexedDbDatabase database, {
    required this.migrationId,
    required String source,
    required this.sourceSection,
    required this.loadPlan,
    required this.verifySourceUnchanged,
    DateTime Function()? now,
    String? ownerId,
  }) : _integrity = TrainingV2MigrationIntegrity(
         database,
         migrationId: migrationId,
       ),
       _metadata = TrainingV2MigrationMetadataService(
         database,
         migrationId: migrationId,
         source: source,
         sourceSection: sourceSection,
         now: now,
         ownerId: ownerId,
       ),
       _transaction = TrainingV2MigrationTransaction(
         database,
         migrationId: migrationId,
         source: source,
         sourceSection: sourceSection,
       );

  Future<TrainingV2MigrationResult> migrate() async {
    IndexedDbMigrationMetadata? active;
    try {
      active = await _metadata.acquireLease();
      if (active.status == IndexedDbMigrationStatus.completed) {
        _metadata.validateCompleted(active, _integrity);
        Set<String> quarantineIds;
        try {
          quarantineIds = await _integrity.verifyCompletedQuarantine(active);
        } catch (error) {
          throw _metadata.completedFailure(error.toString());
        }
        return _completedResult(active, quarantineIds);
      }

      final plan = await loadPlan();
      final writing = _metadata.buildWriting(active, plan);
      await _metadata.write(writing);
      active = writing;

      final outcome = await _transaction.write(
        plan,
        writing,
        _metadata.nowUtc(),
      );
      active = outcome.metadata;
      if (outcome.conflictCount > 0) {
        throw RepositoryException(
          operation: '$migrationId.conflict',
          code: RepositoryErrorCode.migrationFailed,
          cause: StateError(
            '${outcome.conflictCount} TRAINING migration conflict(s).',
          ),
        );
      }

      final verifying = _metadata.buildVerifying(outcome.metadata);
      await _metadata.write(verifying);
      active = verifying;
      await _integrity.verifyInitial(plan, outcome, verifySourceUnchanged);

      final completed = _metadata.buildCompleted(
        verifying,
        verifiedRecordCount: outcome.targets.length,
      );
      await _metadata.write(completed);
      return outcome.toResult(alreadyCompleted: false);
    } catch (error) {
      if (active != null &&
          active.status != IndexedDbMigrationStatus.completed) {
        await _metadata.markFailed(active, error);
      }
      if (error is RepositoryException) rethrow;
      throw RepositoryException(
        operation: migrationId,
        code: RepositoryErrorCode.migrationFailed,
        cause: error,
      );
    }
  }

  TrainingV2MigrationResult _completedResult(
    IndexedDbMigrationMetadata metadata,
    Set<String> quarantineIds,
  ) {
    return TrainingV2MigrationResult(
      alreadyCompleted: true,
      sourceCount: metadata.sourceCounts[sourceSection]!,
      validCount: metadata.validCounts['validRecordCount']!,
      invalidCount: metadata.validCounts['invalidRecordCount']!,
      needsReviewCount: metadata.validCounts['needsReviewRecordCount']!,
      conflictCount: metadata.validCounts['conflictRecordCount']!,
      writtenCount: metadata.validCounts['writtenRecordCount']!,
      skippedCount: metadata.validCounts['skippedRecordCount']!,
      targetIds:
          metadata.expectedRecordIds[IndexedDbStoreNames.trainingRecords]!,
      quarantineIds: quarantineIds,
    );
  }
}
