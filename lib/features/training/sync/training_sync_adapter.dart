import '../../../core/models/training_session_v2.dart';
import '../../repositories/app_repository_container.dart';
import '../../sync/models/orlo_sync_models.dart';
import '../../sync/services/orlo_sync_adapter.dart';
import '../models/training_record_read_model.dart';
import '../repository/custom_training_exercise_repository.dart';
import '../repository/training_session_repository.dart';
import '../services/training_cardio_energy_service.dart';
import '../services/training_energy_service.dart';
import '../services/training_status_weight_resolver.dart';
import '../services/training_v2_canonical_service.dart';
import 'training_sync_instruction_provider.dart';
import 'training_sync_schema.dart';

class TrainingSyncAdapter implements OrloSyncAdapter {
  TrainingSyncAdapter({
    TrainingSessionRepository? repository,
    CustomTrainingExerciseRepository? customExercises,
    TrainingStatusWeightResolver? weightResolver,
  }) : _repositoryOverride = repository,
       _customExercisesOverride = customExercises,
       _weightResolverOverride = weightResolver;

  final TrainingSessionRepository? _repositoryOverride;
  final CustomTrainingExerciseRepository? _customExercisesOverride;
  final TrainingStatusWeightResolver? _weightResolverOverride;

  TrainingSessionRepository get _repository =>
      _repositoryOverride ?? AppRepositoryRegistry.container.training;
  CustomTrainingExerciseRepository get _customExercises =>
      _customExercisesOverride ??
      AppRepositoryRegistry.container.customTrainingExercises;
  TrainingStatusWeightResolver get _weightResolver =>
      _weightResolverOverride ?? TrainingStatusWeightResolver();

  @override
  String get dataType => 'training';
  @override
  String get schemaVersion => '1.0';

  Future<_PreparedTrainingSync> _prepare(OrloSyncEnvelope envelope) async {
    final decoded = await TrainingSyncSchema.decode(
      payload: envelope.payload,
      operationDate: envelope.operationDate,
      idempotencyKey: envelope.idempotencyKey,
      customExercises: _customExercises,
    );
    for (final entry in decoded.session.cardioEntries) {
      final snapshotValues = [
        entry.estimatedCaloriesKcal,
        entry.weightSnapshotKg,
        entry.calculationMethod,
        entry.calculationVersion,
      ];
      final hasAny = snapshotValues.any((value) => value != null);
      if (hasAny && !TrainingCardioEnergyService.isFormalCalculation(entry)) {
        throw const FormatException('Invalid cardio calories snapshot.');
      }
    }
    final weight = TrainingEnergyService.requiresStatusWeight(decoded.session)
        ? await _weightResolver.resolve(decoded.session.date.substring(0, 10))
        : null;
    final session = TrainingEnergyService.applyForSave(
      session: decoded.session,
      statusWeightKg: weight,
    );
    final digest = TrainingV2CanonicalService.digest(
      localDate: decoded.session.date.substring(0, 10),
      session: session,
    );
    return _PreparedTrainingSync(
      payload: decoded,
      session: session,
      digest: digest,
    );
  }

  @override
  Future<List<SyncIssue>> validatePayload(OrloSyncEnvelope envelope) async {
    try {
      await _prepare(envelope);
      return const [];
    } catch (error) {
      return [
        SyncIssue(
          code: 'payloadInvalid',
          path: r'$.payload',
          message: error.toString().replaceFirst('FormatException: ', ''),
          severity: SyncIssueSeverity.blockingError,
        ),
      ];
    }
  }

  Future<_TrainingDisposition> _disposition(
    _PreparedTrainingSync prepared,
  ) async {
    final records = await _repository.findAllRecords();
    for (final record in records) {
      final v2 = record.v2Data;
      if (record.id == prepared.payload.recordId) {
        return v2 != null && _digest(record) == prepared.digest
            ? _TrainingDisposition.noChanges
            : _TrainingDisposition.conflict;
      }
      if (v2 != null && _digest(record) == prepared.digest) {
        return _TrainingDisposition.noChanges;
      }
    }
    return _TrainingDisposition.create;
  }

  String _digest(TrainingRecordReadModel record) =>
      TrainingV2CanonicalService.digest(
        localDate: record.localDate,
        session: record.v2Data!,
      );

  @override
  Future<List<SyncIssue>> detectConflicts(OrloSyncEnvelope envelope) async {
    try {
      final prepared = await _prepare(envelope);
      return await _disposition(prepared) == _TrainingDisposition.conflict
          ? const [
              SyncIssue(
                code: 'trainingRecordConflict',
                path: r'$.payload.session.recordId',
                message: '同じRecord IDに異なるTrainingがあります。',
                severity: SyncIssueSeverity.conflict,
              ),
            ]
          : const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<SyncPreviewCounts> buildPreview(OrloSyncEnvelope envelope) async {
    try {
      final prepared = await _prepare(envelope);
      final disposition = await _disposition(prepared);
      final exercises = prepared.session.exercises;
      return SyncPreviewCounts(
        records: 1,
        create: disposition == _TrainingDisposition.create ? 1 : 0,
        noOp: disposition == _TrainingDisposition.noChanges ? 1 : 0,
        conflict: disposition == _TrainingDisposition.conflict ? 1 : 0,
        details: {
          'sessionName': prepared.session.sessionName,
          'grade': prepared.session.sessionGrade?.displayLabel,
          'exerciseCount': exercises.length,
          'warmUpSets': exercises
              .expand((e) => e.sets)
              .where((s) => s.setType.name == 'warmUp')
              .length,
          'mainSets': exercises
              .expand((e) => e.sets)
              .where((s) => s.setType.name == 'main')
              .length,
          'cardioCount': prepared.session.cardioEntries.length,
          'hasOverallEvaluation': prepared.session.overallEvaluation != null,
          'exerciseEvaluationCount': exercises
              .where((e) => e.evaluation != null)
              .length,
          'nextTargetCount': exercises
              .where((e) => e.nextTarget != null)
              .length,
          'disposition': disposition.name,
        },
      );
    } catch (_) {
      return const SyncPreviewCounts();
    }
  }

  @override
  Future<SyncImportResult> applyAndVerify({
    required OrloSyncEnvelope envelope,
    required String expectedPayloadDigest,
  }) async {
    final prepared = await _prepare(envelope);
    final result = await _repository.createV2FromSync(
      recordId: prepared.payload.recordId,
      session: prepared.session,
      expectedCanonicalDigest: prepared.digest,
    );
    final success =
        result.status != TrainingSyncCreateStatus.conflict &&
        result.readBackVerified;
    return SyncImportResult(
      success: success,
      packageId: envelope.packageId,
      payloadDigest: expectedPayloadDigest,
      issues: success
          ? const []
          : const [
              SyncIssue(
                code: 'trainingRecordConflict',
                path: r'$.payload.session.recordId',
                message: 'Training Recordを保存できませんでした。',
                severity: SyncIssueSeverity.conflict,
              ),
            ],
    );
  }

  @override
  String buildChatGptPayloadInstruction() =>
      const TrainingSyncInstructionProvider().build();
}

enum _TrainingDisposition { create, noChanges, conflict }

class _PreparedTrainingSync {
  const _PreparedTrainingSync({
    required this.payload,
    required this.session,
    required this.digest,
  });
  final TrainingSyncPayload payload;
  final TrainingSessionV2 session;
  final String digest;
}
