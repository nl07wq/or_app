import '../../operation_date/models/operation_state.dart';
import '../../repositories/app_repository_container.dart';
import '../../sync/models/orlo_sync_models.dart';
import '../../sync/services/orlo_sync_canonical_codec.dart';
import '../../training/sync/training_sync_adapter.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_history.dart';
import '../models/report_sync_issue.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_payload_adapters.dart';

enum ReportSyncDisposition { create, noChanges, conflict, blocked }

class ReportSyncRequestPreparation {
  const ReportSyncRequestPreparation({
    this.envelope,
    this.operationDate,
    this.confirmationDigest,
    this.statusLabel = 'REQUEST NOT READY',
    this.blockingReason,
  });

  final ReportSyncEnvelope? envelope;
  final String? operationDate;
  final String? confirmationDigest;
  final String statusLabel;
  final String? blockingReason;
  bool get isReady => operationDate != null;
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

  String instruction(
    ReportSyncExchangeType type,
    ReportSyncRequestPreparation preparation,
  );

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
        statusLabel: 'FINALIZE REQUIRED',
        blockingReason:
            'Finalize the operation date before creating a request.',
      );
    }

    switch (type) {
      case ReportSyncExchangeType.training:
        return ReportSyncRequestPreparation(operationDate: operationDate);
      case ReportSyncExchangeType.food:
        return ReportSyncRequestPreparation(operationDate: operationDate);
      case ReportSyncExchangeType.morningBrief:
        if (state.phase != OperationPhase.open) {
          return const ReportSyncRequestPreparation(
            blockingReason: 'Morning Brief requires the open operation date.',
          );
        }
        final status = await _container.status.findByLocalDate(operationDate);
        return ReportSyncRequestPreparation(
          operationDate: operationDate,
          blockingReason: status == null
              ? 'Morning Fact is not recorded. Paste the formal Morning Fact '
                    'after the prompt before generating a response.'
              : null,
        );
      case ReportSyncExchangeType.dailyDebrief:
        final confirmation = await _container.confirmation.findByLocalDate(
          operationDate,
        );
        if (confirmation == null) {
          return const ReportSyncRequestPreparation(
            statusLabel: 'BLOCKED',
            blockingReason:
                'Daily confirmation is required for the finalized operation date.',
          );
        }
        return ReportSyncRequestPreparation(
          operationDate: operationDate,
          confirmationDigest: ReportSyncCanonicalService.digest(
            confirmation.toJson(),
          ),
        );
    }
  }

  @override
  Future<void> recordRequest(ReportSyncEnvelope request) async {
    await _container.reportSyncPersistence.recordRequest(request);
  }

  @override
  String encode(ReportSyncEnvelope envelope) =>
      _container.reportSyncCodec.encode(envelope);

  @override
  String instruction(
    ReportSyncExchangeType type,
    ReportSyncRequestPreparation preparation,
  ) {
    final operationDate = preparation.operationDate;
    if (operationDate == null) {
      throw StateError('The exchange target is not ready.');
    }
    return _container.reportSyncInstructions
        .forType(type)
        .buildInstruction(
          operationDate: operationDate,
          confirmationDigest: preparation.confirmationDigest,
        );
  }

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
        requestId: response.requestId ?? response.exchangeId,
        requestDigest: response.requestDigest ?? response.packageDigest,
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
}
