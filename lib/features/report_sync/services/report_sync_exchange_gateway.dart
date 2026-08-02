import '../../../core/models/morning_data.dart';
import '../../../core/models/training_session_v2.dart';
import '../../food/services/food_summary_service.dart';
import '../../morning/models/morning_fact.dart';
import '../../operation_date/models/operation_state.dart';
import '../../repositories/app_repository_container.dart';
import '../../sync/models/orlo_sync_models.dart';
import '../../sync/services/orlo_sync_canonical_codec.dart';
import '../../training/services/equipment_catalog.dart';
import '../../training/sync/training_sync_adapter.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_history.dart';
import '../models/report_sync_issue.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_payload_adapters.dart';
import 'report_sync_request_builders.dart';

enum ReportSyncDisposition { create, noChanges, conflict, blocked }

class ReportSyncRequestPreparation {
  const ReportSyncRequestPreparation({this.envelope, this.blockingReason});

  final ReportSyncEnvelope? envelope;
  final String? blockingReason;
  bool get isReady => envelope != null;
}

class ReportSyncResponsePreview {
  const ReportSyncResponsePreview({
    required this.envelope,
    required this.disposition,
    required this.createCount,
    required this.noChangeCount,
    required this.conflictCount,
    this.message,
  });

  final ReportSyncEnvelope envelope;
  final ReportSyncDisposition disposition;
  final int createCount;
  final int noChangeCount;
  final int conflictCount;
  final String? message;
  bool get canApply => disposition == ReportSyncDisposition.create;
}

class ReportSyncApplyResult {
  const ReportSyncApplyResult(
    this.disposition, {
    this.readBackVerified = false,
  });

  final ReportSyncDisposition disposition;
  final bool readBackVerified;
}

abstract interface class ReportSyncExchangeGateway {
  Future<ReportSyncRequestPreparation> prepareRequest(
    ReportSyncExchangeType type,
  );

  Future<void> recordRequest(ReportSyncEnvelope request);

  String encode(ReportSyncEnvelope envelope);

  String instruction(ReportSyncExchangeType type);

  Future<ReportSyncResponsePreview> previewResponse(
    ReportSyncExchangeType type,
    String rawResponse,
  );

  Future<ReportSyncApplyResult> apply(ReportSyncResponsePreview preview);

  Future<List<ReportSyncHistory>> history(ReportSyncExchangeType type);

  Future<Object?> importedRecord(ReportSyncExchangeType type, String localDate);
}

class ProductionReportSyncExchangeGateway implements ReportSyncExchangeGateway {
  ProductionReportSyncExchangeGateway({
    AppRepositoryContainer? container,
    DateTime Function()? clock,
  }) : _containerOverride = container,
       _clock = clock ?? DateTime.now;

  final AppRepositoryContainer? _containerOverride;
  final DateTime Function() _clock;

  AppRepositoryContainer get _container =>
      _containerOverride ?? AppRepositoryRegistry.container;

  @override
  Future<ReportSyncRequestPreparation> prepareRequest(
    ReportSyncExchangeType type,
  ) async {
    final state = await _container.operationState.requireCurrent();
    final operationDate = type == ReportSyncExchangeType.dailyDebrief
        ? state.lastFinalizedDate?.value
        : state.operationDate.value;
    if (operationDate == null) {
      return const ReportSyncRequestPreparation(
        blockingReason: 'FINALIZE REQUIRED',
      );
    }

    final Map<String, Object?> payload;
    String? confirmationDigest;
    switch (type) {
      case ReportSyncExchangeType.training:
        final records = await _container.training.findRecordsByLocalDate(
          operationDate,
        );
        final candidates =
            records
                .where((record) => record.v2Data != null && !record.isLegacy)
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (candidates.isEmpty) {
          return const ReportSyncRequestPreparation(
            blockingReason: 'REQUEST NOT READY',
          );
        }
        final record = candidates.first;
        final session = record.v2Data!;
        final customExercises = await _container.customTrainingExercises
            .findAll();
        final status = await _container.status.findByLocalDate(operationDate);
        payload = const TrainingRequestPayloadBuilder().build(
          operationDate: operationDate,
          requestPurpose: 'trainingRecordImport',
          currentSession: _trainingSession(record.id, operationDate, session),
          registeredExercises: [
            for (final exercise in customExercises)
              {'id': exercise.id, 'name': exercise.name},
          ],
          registeredEquipment: [
            for (final equipment in builtInEquipment)
              {'id': equipment.id, 'name': equipment.displayName},
          ],
          sameDateStatusWeight: status?.weight,
        );
        break;
      case ReportSyncExchangeType.food:
        final meals = await _container.food.findByLocalDate(operationDate);
        payload = const FoodReportSyncPayloadMapper().buildRequest(
          operationDate: operationDate,
          meals: meals,
          requestPurpose: 'dailyMealImport',
          dailySummary: FoodSummaryService.forLocalDate(
            meals,
            operationDate,
          ).toJson(),
        );
        _container.reportSyncPayloads.forType(type).validateRequest(payload);
        break;
      case ReportSyncExchangeType.morningBrief:
        if (state.phase != OperationPhase.open) {
          return const ReportSyncRequestPreparation(
            blockingReason: 'REQUEST NOT READY',
          );
        }
        final status = await _container.status.findByLocalDate(operationDate);
        if (status == null) {
          return const ReportSyncRequestPreparation(
            blockingReason: 'NOT GENERATED',
          );
        }
        payload = const MorningBriefRequestPayloadBuilder().build(
          operationDate: operationDate,
          fact: _morningFact(status),
        );
        break;
      case ReportSyncExchangeType.dailyDebrief:
        final confirmation = await _container.confirmation.findByLocalDate(
          operationDate,
        );
        if (confirmation == null) {
          return const ReportSyncRequestPreparation(
            blockingReason: 'FINALIZE REQUIRED',
          );
        }
        final morningBrief = await _container.morningBriefs.readByLocalDate(
          operationDate,
        );
        payload = const DailyDebriefRequestPayloadBuilder().build(
          operationDate: operationDate,
          confirmation: confirmation,
          finalizedSnapshot: Map<String, Object?>.from(confirmation.toJson()),
          morningBrief: morningBrief?.toRecord(),
          commanderIntent: morningBrief?.commanderIntent,
        );
        confirmationDigest = payload['confirmationDigest'] as String;
        break;
    }

    final now = _clock().toUtc();
    final identity =
        '${type.stableId}-$operationDate-${now.microsecondsSinceEpoch}';
    final requestDigest = ReportSyncCanonicalService.digest(payload);
    final envelope = _container.reportSyncCodec.create(
      direction: ReportSyncDirection.request,
      exchangeType: type,
      exchangeId: 'request-$identity',
      requestId: 'request-$identity',
      operationDate: operationDate,
      createdAt: now,
      requestDigest: requestDigest,
      payload: payload,
    );
    if (confirmationDigest != null &&
        confirmationDigest != payload['confirmationDigest']) {
      throw StateError('Confirmation digest changed during request creation.');
    }
    return ReportSyncRequestPreparation(envelope: envelope);
  }

  @override
  Future<void> recordRequest(ReportSyncEnvelope request) async {
    await _container.reportSyncPersistence.recordRequest(request);
  }

  @override
  String encode(ReportSyncEnvelope envelope) =>
      _container.reportSyncCodec.encode(envelope);

  @override
  String instruction(ReportSyncExchangeType type) =>
      _container.reportSyncInstructions.forType(type).buildInstruction();

  @override
  Future<ReportSyncResponsePreview> previewResponse(
    ReportSyncExchangeType type,
    String rawResponse,
  ) async {
    final response = _container.reportSyncCodec.decode(rawResponse);
    if (response.exchangeType != type ||
        response.direction != ReportSyncDirection.response) {
      throw const ReportSyncException(
        ReportSyncIssueCode.exchangeTypeMismatch,
        'The selected exchange type does not match the response.',
      );
    }
    await _container.reportSyncValidator.validateResponse(response);
    final preview = await switch (type) {
      ReportSyncExchangeType.training => _previewTraining(response),
      ReportSyncExchangeType.food => _previewFood(response),
      ReportSyncExchangeType.morningBrief => _previewMorningBrief(response),
      ReportSyncExchangeType.dailyDebrief => _previewDailyDebrief(response),
    };
    if (preview.disposition != ReportSyncDisposition.create) {
      await _recordPreviewOutcome(preview);
    }
    return preview;
  }

  Future<void> _recordPreviewOutcome(ReportSyncResponsePreview preview) async {
    final response = preview.envelope;
    if (await _container.reportSyncHistory.readById(response.exchangeId) !=
        null) {
      return;
    }
    final completed = _clock().toUtc();
    final isConflict = preview.disposition == ReportSyncDisposition.conflict;
    final isBlocked = preview.disposition == ReportSyncDisposition.blocked;
    await _container.reportSyncHistory.create(
      ReportSyncHistory(
        exchangeId: response.exchangeId,
        exchangeType: response.exchangeType,
        direction: response.direction,
        operationDate: response.operationDate,
        requestId: response.requestId,
        requestDigest: response.requestDigest,
        responseDigest: ReportSyncCanonicalService.digest(response.payload),
        confirmationDigest: response.confirmationDigest,
        startedAt: response.createdAt,
        completedAt: completed.isBefore(response.createdAt)
            ? response.createdAt
            : completed,
        result: isConflict
            ? ReportSyncHistoryResult.conflict
            : isBlocked
            ? ReportSyncHistoryResult.failed
            : ReportSyncHistoryResult.noChange,
        failureCode: isConflict
            ? ReportSyncIssueCode.recordConflict
            : isBlocked
            ? ReportSyncIssueCode.integrityFailure
            : null,
        packageDigest: response.packageDigest,
      ),
    );
  }

  Future<ReportSyncResponsePreview> _previewTraining(
    ReportSyncEnvelope response,
  ) async {
    await TrainingReportSyncPayloadAdapter(
      _container.customTrainingExercises,
    ).decodeResponse(response);
    final envelope = _trainingEnvelope(response);
    final adapter = TrainingSyncAdapter(
      repository: _container.training,
      customExercises: _container.customTrainingExercises,
    );
    final issues = [
      ...await adapter.validatePayload(envelope),
      ...await adapter.detectConflicts(envelope),
    ];
    final counts = await adapter.buildPreview(envelope);
    final blocked = issues.any(
      (issue) => issue.severity == SyncIssueSeverity.blockingError,
    );
    final conflict = issues.any(
      (issue) => issue.severity == SyncIssueSeverity.conflict,
    );
    final disposition = blocked
        ? ReportSyncDisposition.blocked
        : conflict || counts.conflict > 0
        ? ReportSyncDisposition.conflict
        : counts.noOp > 0
        ? ReportSyncDisposition.noChanges
        : ReportSyncDisposition.create;
    return ReportSyncResponsePreview(
      envelope: response,
      disposition: disposition,
      createCount: counts.create,
      noChangeCount: counts.noOp,
      conflictCount: counts.conflict,
      message: issues.isEmpty
          ? null
          : issues.map((issue) => issue.message).join('\n'),
    );
  }

  Future<ReportSyncResponsePreview> _previewFood(
    ReportSyncEnvelope response,
  ) async {
    if (await _container.confirmation.isConfirmed(response.operationDate)) {
      return _preview(
        response,
        ReportSyncDisposition.blocked,
        message: 'Finalized DateへのImportはできません。',
      );
    }
    final meals = const FoodReportSyncPayloadMapper().decodeResponse(response);
    var creates = 0;
    var noChanges = 0;
    var conflicts = 0;
    for (final meal in meals) {
      final existing = await _container.food.findById(meal.id);
      if (existing == null) {
        creates++;
      } else if (ReportSyncCanonicalService.encode(existing.toJson()) ==
          ReportSyncCanonicalService.encode(meal.toJson())) {
        noChanges++;
      } else {
        conflicts++;
      }
    }
    return ReportSyncResponsePreview(
      envelope: response,
      disposition: conflicts > 0
          ? ReportSyncDisposition.conflict
          : creates > 0
          ? ReportSyncDisposition.create
          : ReportSyncDisposition.noChanges,
      createCount: creates,
      noChangeCount: noChanges,
      conflictCount: conflicts,
    );
  }

  Future<ReportSyncResponsePreview> _previewMorningBrief(
    ReportSyncEnvelope response,
  ) async {
    final existing = await _container.morningBriefs.readByLocalDate(
      response.operationDate,
    );
    if (existing == null) {
      return _preview(response, ReportSyncDisposition.create);
    }
    final digest = ReportSyncCanonicalService.digest(response.payload);
    return _preview(
      response,
      existing.responseDigest == digest
          ? ReportSyncDisposition.noChanges
          : ReportSyncDisposition.conflict,
    );
  }

  Future<ReportSyncResponsePreview> _previewDailyDebrief(
    ReportSyncEnvelope response,
  ) async {
    final existing = await _container.dailyDebriefs.readByLocalDate(
      response.operationDate,
    );
    if (existing == null) {
      return _preview(response, ReportSyncDisposition.create);
    }
    final digest = ReportSyncCanonicalService.digest(response.payload);
    return _preview(
      response,
      existing.responseDigest == digest
          ? ReportSyncDisposition.noChanges
          : ReportSyncDisposition.conflict,
    );
  }

  ReportSyncResponsePreview _preview(
    ReportSyncEnvelope response,
    ReportSyncDisposition disposition, {
    String? message,
  }) => ReportSyncResponsePreview(
    envelope: response,
    disposition: disposition,
    createCount: disposition == ReportSyncDisposition.create ? 1 : 0,
    noChangeCount: disposition == ReportSyncDisposition.noChanges ? 1 : 0,
    conflictCount: disposition == ReportSyncDisposition.conflict ? 1 : 0,
    message: message,
  );

  @override
  Future<ReportSyncApplyResult> apply(ReportSyncResponsePreview preview) async {
    if (preview.disposition == ReportSyncDisposition.noChanges) {
      return const ReportSyncApplyResult(
        ReportSyncDisposition.noChanges,
        readBackVerified: true,
      );
    }
    if (!preview.canApply) {
      throw StateError('Blocked or conflicting response cannot be imported.');
    }
    final response = preview.envelope;
    switch (response.exchangeType) {
      case ReportSyncExchangeType.training:
        final envelope = _trainingEnvelope(response);
        final digest = OrloSyncCanonicalCodec.digest(envelope.payload);
        final result = await TrainingSyncAdapter(
          repository: _container.training,
          customExercises: _container.customTrainingExercises,
        ).applyAndVerify(envelope: envelope, expectedPayloadDigest: digest);
        if (!result.success) {
          throw StateError('Training read-back verification failed.');
        }
        break;
      case ReportSyncExchangeType.food:
        final result = await _container.foodReportSyncApply.apply(response);
        if (result.status == FoodReportSyncApplyStatus.conflict ||
            result.status == FoodReportSyncApplyStatus.finalizedBlocked) {
          throw StateError('Food response cannot be imported.');
        }
        break;
      case ReportSyncExchangeType.morningBrief:
        await _container.reportSyncPersistence.importMorningBrief(response);
        return const ReportSyncApplyResult(
          ReportSyncDisposition.create,
          readBackVerified: true,
        );
      case ReportSyncExchangeType.dailyDebrief:
        await _container.reportSyncPersistence.importDailyDebrief(response);
        return const ReportSyncApplyResult(
          ReportSyncDisposition.create,
          readBackVerified: true,
        );
    }
    await _container.reportSyncPersistence.recordResponse(response);
    return const ReportSyncApplyResult(
      ReportSyncDisposition.create,
      readBackVerified: true,
    );
  }

  OrloSyncEnvelope _trainingEnvelope(ReportSyncEnvelope response) =>
      OrloSyncEnvelope(
        envelopeVersion: OrloSyncEnvelope.currentEnvelopeVersion,
        schemaVersion: OrloSyncEnvelope.currentSchemaVersion,
        dataType: 'training',
        packageId: response.exchangeId,
        idempotencyKey: response.payload['idempotencyKey'] as String,
        source: OrloSyncSource(
          type: 'chatGptExchange',
          generatedAt: response.createdAt,
          producer: 'report-sync',
          producerVersion: '1.0',
        ),
        operationDate: response.operationDate,
        payload: Map<String, Object?>.from(response.payload['session'] as Map),
      );

  @override
  Future<List<ReportSyncHistory>> history(ReportSyncExchangeType type) async =>
      (await _container.reportSyncHistory.list())
          .where((value) => value.exchangeType == type)
          .take(10)
          .toList(growable: false);

  @override
  Future<Object?> importedRecord(
    ReportSyncExchangeType type,
    String localDate,
  ) => switch (type) {
    ReportSyncExchangeType.morningBrief =>
      _container.morningBriefs.readByLocalDate(localDate),
    ReportSyncExchangeType.dailyDebrief =>
      _container.dailyDebriefs.readByLocalDate(localDate),
    _ => Future<Object?>.value(),
  };

  static Map<String, Object?> _trainingSession(
    String recordId,
    String localDate,
    TrainingSessionV2 session,
  ) => {
    'recordId': recordId,
    'localDate': localDate,
    'sessionType': session.sessionName,
    'operationStatus': null,
    'warmup': null,
    'dynamicStretchCompleted': session.dynamicStretchCompleted,
    'exercises': [for (final value in session.exercises) value.toJson()],
    'cardio': [for (final value in session.cardioEntries) value.toJson()],
    'cooldownStretchCompleted': session.cooldownStretchCompleted,
    'overallEvaluation': session.overallEvaluation,
    'nextTarget': null,
  };

  static MorningFact _morningFact(MorningData value) => MorningFact(
    date: DateTime.parse(value.date),
    weight: value.weight,
    bodyFat: value.bodyFat,
    sleepDuration: Duration(
      minutes: (value.sleepHours * Duration.minutesPerHour).round(),
    ),
    sleepScore: value.sleepScore,
    workHours: value.workHours,
    footPain: value.footPain,
    condition: value.condition,
    previousCarryoverConfirmed: value.previousCarryoverConfirmed,
    medications: const [],
    freeNotes: value.memo.isEmpty ? null : value.memo,
  );
}
