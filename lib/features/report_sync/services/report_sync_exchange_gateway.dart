import '../../../core/models/meal_data.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../operation_date/models/operation_state.dart';
import '../../food/repository/food_meal_id_generator.dart';
import '../../repositories/app_repository_container.dart';
import '../../sync/models/orlo_sync_models.dart';
import '../../sync/services/orlo_sync_canonical_codec.dart';
import '../../training/sync/training_sync_adapter.dart';
import '../../training/repository/training_record_id_generator.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_history.dart';
import '../models/report_sync_issue.dart';
import '../models/status_report_sync_source.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_payload_adapters.dart';
import 'report_sync_plain_text_exporter.dart';
import 'report_sync_persistence_service.dart';
import 'status_report_sync_source_service.dart';

enum ReportSyncDisposition { create, noChanges, conflict, blocked }

enum FoodReportSyncMealDisposition { create, noChanges, conflict, blocked }

class ReportSyncApplyException implements Exception {
  const ReportSyncApplyException({
    required this.code,
    required this.stage,
    required this.userMessage,
  });

  final String code;
  final String stage;
  final String userMessage;
}

class FoodReportSyncMealPreview {
  const FoodReportSyncMealPreview({
    required this.meal,
    required this.disposition,
    this.previewIdOverride,
    this.conflictDigestOverride,
  });

  final MealData meal;
  final FoodReportSyncMealDisposition disposition;
  final String? previewIdOverride;
  final String? conflictDigestOverride;
  String get previewId => previewIdOverride ?? meal.id;
  String get conflictDigest =>
      conflictDigestOverride ??
      FoodReportSyncPayloadMapper.conflictDigest(meal);
  bool get canSelect => disposition == FoodReportSyncMealDisposition.create;
}

class ReportSyncRequestPreparation {
  const ReportSyncRequestPreparation({
    this.envelope,
    this.operationDate,
    this.confirmationDigest,
    this.sourceText,
    this.statusSourceExport,
    this.statusSourceError,
    this.statusLabel = 'REQUEST NOT READY',
    this.blockingReason,
  });

  final ReportSyncEnvelope? envelope;
  final String? operationDate;
  final String? confirmationDigest;
  final String? sourceText;
  final StatusReportSyncSourceExport? statusSourceExport;
  final StatusReportSyncSourceException? statusSourceError;
  final String statusLabel;
  final String? blockingReason;
  bool get isReady => operationDate != null;
  bool get canCopySource => sourceText != null;
}

class ReportSyncResponsePreview {
  const ReportSyncResponsePreview({
    required this.envelope,
    required this.disposition,
    required this.createCount,
    required this.noChangeCount,
    required this.conflictCount,
    this.message,
    this.foodMeals = const [],
    this.trainingImportEnvelope,
    this.morningBriefSourceDigestMatches = false,
  });

  final ReportSyncEnvelope envelope;
  final ReportSyncDisposition disposition;
  final int createCount;
  final int noChangeCount;
  final int conflictCount;
  final String? message;
  final List<FoodReportSyncMealPreview> foodMeals;
  final OrloSyncEnvelope? trainingImportEnvelope;
  final bool morningBriefSourceDigestMatches;
  bool get canApply => disposition == ReportSyncDisposition.create;
}

class ReportSyncApplyResult {
  const ReportSyncApplyResult(
    this.disposition, {
    this.readBackVerified = false,
    this.mealCounts,
  });

  final ReportSyncDisposition disposition;
  final bool readBackVerified;
  final ReportSyncMealCounts? mealCounts;
}

abstract interface class ReportSyncExchangeGateway {
  Future<ReportSyncRequestPreparation> prepareRequest(
    ReportSyncExchangeType type, {
    String? targetDate,
  });

  Future<void> recordRequest(ReportSyncEnvelope request);

  String encode(ReportSyncEnvelope envelope);

  String instruction(
    ReportSyncExchangeType type,
    ReportSyncRequestPreparation preparation,
  );

  Future<ReportSyncResponsePreview> previewResponse(
    ReportSyncExchangeType type,
    String rawResponse, {
    String? targetDate,
  });

  Future<ReportSyncApplyResult> apply(
    ReportSyncResponsePreview preview, {
    Set<String>? selectedMealIds,
  });

  Future<List<ReportSyncHistory>> history(ReportSyncExchangeType type);

  Future<Object?> importedRecord(ReportSyncExchangeType type, String localDate);
}

class ProductionReportSyncExchangeGateway implements ReportSyncExchangeGateway {
  ProductionReportSyncExchangeGateway({
    AppRepositoryContainer? container,
    DateTime Function()? clock,
    this.trainingIdGenerator,
    this.foodIdGenerator,
  }) : _containerOverride = container,
       _clock = clock ?? DateTime.now;

  final AppRepositoryContainer? _containerOverride;
  final DateTime Function() _clock;
  final TrainingRecordIdGenerator? trainingIdGenerator;
  final FoodMealIdGenerator? foodIdGenerator;

  AppRepositoryContainer get _container =>
      _containerOverride ?? AppRepositoryRegistry.container;

  @override
  Future<ReportSyncRequestPreparation> prepareRequest(
    ReportSyncExchangeType type, {
    String? targetDate,
  }) async {
    final state = await _container.operationState.requireCurrent();
    if (targetDate != null) OperationLocalDate.parse(targetDate);
    final operationDate = type == ReportSyncExchangeType.dailyDebrief
        ? state.lastFinalizedDate?.value
        : targetDate ?? state.operationDate.value;
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
        try {
          final source = await StatusReportSyncSourceService(
            _container.database,
          ).generate(operationDate: operationDate, exportedAt: _clock());
          return ReportSyncRequestPreparation(
            operationDate: operationDate,
            sourceText: source.plainText,
            statusSourceExport: source,
            statusLabel: 'READY',
          );
        } on StatusReportSyncSourceException catch (error) {
          return ReportSyncRequestPreparation(
            operationDate: operationDate,
            statusSourceError: error,
            statusLabel: switch (error.code) {
              'statusSourceMissing' => 'MISSING',
              'statusSourceInvalid' ||
              'statusSourceIncomplete' ||
              'statusSourceNotCanonical' ||
              'statusSourceDateMismatch' => 'INVALID',
              _ => 'NOT READY',
            },
            blockingReason: error.message,
          );
        }
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
        final morningBrief = await _container.morningBriefs.readByLocalDate(
          operationDate,
        );
        return ReportSyncRequestPreparation(
          operationDate: operationDate,
          confirmationDigest: ReportSyncCanonicalService.digest(
            confirmation.toJson(),
          ),
          sourceText: const ReportSyncPlainTextExporter().finalizedDailyData(
            operationDate: operationDate,
            confirmation: confirmation,
            morningBrief: morningBrief,
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
    final instruction = _container.reportSyncInstructions
        .forType(type)
        .buildInstruction(
          operationDate: operationDate,
          confirmationDigest: preparation.confirmationDigest,
          sourceRecordId: preparation.statusSourceExport?.source.sourceRecordId,
          sourceDigest: preparation.statusSourceExport?.sourceDigest,
        );
    if (type != ReportSyncExchangeType.morningBrief) return instruction;

    final export = preparation.statusSourceExport;
    final sourceText = preparation.sourceText;
    if (preparation.statusLabel != 'READY' ||
        export == null ||
        sourceText == null ||
        sourceText != export.plainText) {
      throw StateError('STATUS SOURCE READYが必要です。');
    }
    return '$instruction\n\n'
        'SOURCE DATA START\n'
        '━━━━━━━━━━━━━━━━━━━━\n'
        '$sourceText'
        '━━━━━━━━━━━━━━━━━━━━\n'
        'SOURCE DATA END';
  }

  @override
  Future<ReportSyncResponsePreview> previewResponse(
    ReportSyncExchangeType type,
    String rawResponse, {
    String? targetDate,
  }) async {
    final response = _container.reportSyncCodec.decode(rawResponse);
    if (response.exchangeType != type ||
        response.direction != ReportSyncDirection.response) {
      throw const ReportSyncException(
        ReportSyncIssueCode.exchangeTypeMismatch,
        'The selected exchange type does not match the response.',
      );
    }
    if (targetDate != null) OperationLocalDate.parse(targetDate);
    await _container.reportSyncValidator.validateResponse(
      response,
      expectedOperationDate: targetDate,
    );
    final preview = await switch (type) {
      ReportSyncExchangeType.training => _previewTraining(response),
      ReportSyncExchangeType.food => _previewFood(response),
      ReportSyncExchangeType.morningBrief => _previewMorningBrief(response),
      ReportSyncExchangeType.dailyDebrief => _previewDailyDebrief(response),
    };
    return preview;
  }

  Future<ReportSyncResponsePreview> _previewTraining(
    ReportSyncEnvelope response,
  ) async {
    final mapped = await TrainingReportSyncPayloadAdapter(
      _container.customTrainingExercises,
      idGenerator: trainingIdGenerator,
    ).decodeForImport(response);
    final envelope = _trainingEnvelope(response, mapped.payload);
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
      trainingImportEnvelope: envelope,
    );
  }

  Future<ReportSyncResponsePreview> _previewFood(
    ReportSyncEnvelope response,
  ) async {
    final decodedMeals = FoodReportSyncPayloadMapper(
      idGenerator: foodIdGenerator,
    ).decodeResponseMeals(response);
    final finalized = await _container.confirmation.isConfirmed(
      response.operationDate,
    );
    var creates = 0;
    var noChanges = 0;
    var conflicts = 0;
    final mealPreviews = <FoodReportSyncMealPreview>[];
    final existingForDate = await _container.food.findByLocalDate(
      response.operationDate,
    );
    final existingDigests = {
      for (final existing in existingForDate)
        FoodReportSyncPayloadMapper.conflictDigest(existing),
    };
    final usesExternalIdentity =
        response.schemaVersion == ReportSyncEnvelope.importSchemaVersion2;
    final receivedDigests = <String>{};
    final reservedMealIds = <String>{};
    for (final decoded in decodedMeals) {
      var meal = decoded.meal;
      if (finalized) {
        mealPreviews.add(
          FoodReportSyncMealPreview(
            meal: meal,
            disposition: FoodReportSyncMealDisposition.blocked,
            previewIdOverride: usesExternalIdentity ? decoded.previewId : null,
            conflictDigestOverride: decoded.conflictDigest,
          ),
        );
        continue;
      }
      if (usesExternalIdentity) {
        if (existingDigests.contains(decoded.conflictDigest) ||
            !receivedDigests.add(decoded.conflictDigest)) {
          conflicts++;
          mealPreviews.add(
            FoodReportSyncMealPreview(
              meal: meal,
              disposition: FoodReportSyncMealDisposition.conflict,
              previewIdOverride: decoded.previewId,
              conflictDigestOverride: decoded.conflictDigest,
            ),
          );
          continue;
        }
        meal = await _withUniqueFoodId(meal, reservedMealIds);
      }
      final existing = await _container.food.findById(meal.id);
      if (existing == null) {
        creates++;
        mealPreviews.add(
          FoodReportSyncMealPreview(
            meal: meal,
            disposition: FoodReportSyncMealDisposition.create,
            previewIdOverride: usesExternalIdentity ? decoded.previewId : null,
            conflictDigestOverride: decoded.conflictDigest,
          ),
        );
      } else if (ReportSyncCanonicalService.encode(existing.toJson()) ==
          ReportSyncCanonicalService.encode(meal.toJson())) {
        noChanges++;
        mealPreviews.add(
          FoodReportSyncMealPreview(
            meal: meal,
            disposition: FoodReportSyncMealDisposition.noChanges,
            previewIdOverride: usesExternalIdentity ? decoded.previewId : null,
            conflictDigestOverride: decoded.conflictDigest,
          ),
        );
      } else {
        conflicts++;
        mealPreviews.add(
          FoodReportSyncMealPreview(
            meal: meal,
            disposition: FoodReportSyncMealDisposition.conflict,
            previewIdOverride: usesExternalIdentity ? decoded.previewId : null,
            conflictDigestOverride: decoded.conflictDigest,
          ),
        );
      }
    }
    return ReportSyncResponsePreview(
      envelope: response,
      disposition: finalized
          ? ReportSyncDisposition.blocked
          : creates > 0
          ? ReportSyncDisposition.create
          : conflicts > 0
          ? ReportSyncDisposition.conflict
          : ReportSyncDisposition.noChanges,
      createCount: creates,
      noChangeCount: noChanges,
      conflictCount: conflicts,
      message: finalized ? '確定済みの日付には取り込めません。' : null,
      foodMeals: mealPreviews,
    );
  }

  Future<ReportSyncResponsePreview> _previewMorningBrief(
    ReportSyncEnvelope response,
  ) async {
    if (response.schemaVersion != ReportSyncEnvelope.importSchemaVersion2) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'Morning Brief requires Schema 2.0.',
      );
    }
    final payload = response.payload;
    final source = Map<String, Object?>.from(payload['source'] as Map);
    final current = await StatusReportSyncSourceService(
      _container.database,
    ).generate(operationDate: response.operationDate, exportedAt: _clock());
    _requireMorningBriefSource(
      source,
      operationDate: response.operationDate,
      current: current,
    );
    final existing = await _container.morningBriefs.readByLocalDate(
      response.operationDate,
    );
    if (existing == null) {
      return ReportSyncResponsePreview(
        envelope: response,
        disposition: ReportSyncDisposition.create,
        createCount: 1,
        noChangeCount: 0,
        conflictCount: 0,
        morningBriefSourceDigestMatches: true,
      );
    }
    return _preview(
      response,
      ReportSyncDisposition.conflict,
      message: 'A Morning Brief already exists for this operation date.',
    );
  }

  void _requireMorningBriefSource(
    Map<String, Object?> source, {
    required String operationDate,
    required StatusReportSyncSourceExport current,
  }) {
    final expected = <String, Object?>{
      'sourceType': 'status',
      'sourceOperationDate': operationDate,
      'sourceRecordId': current.source.sourceRecordId,
      'sourceDigest': current.sourceDigest,
    };
    for (final entry in expected.entries) {
      if (source[entry.key] != entry.value) {
        throw ReportSyncException(
          ReportSyncIssueCode.integrityFailure,
          'Morning Brief STATUS source identity does not match.',
          validationError: ReportSyncValidationError(
            code: 'sourceIdentityMismatch',
            jsonPath: r'$.payload.source.' + entry.key,
            message: 'The current STATUS source does not match the response.',
            expected: entry.value.toString(),
            actualType: source[entry.key]?.runtimeType.toString() ?? 'null',
            actualValuePreview: source[entry.key]?.toString() ?? 'null',
          ),
        );
      }
    }
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
  Future<ReportSyncApplyResult> apply(
    ReportSyncResponsePreview preview, {
    Set<String>? selectedMealIds,
  }) async {
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
        final envelope = preview.trainingImportEnvelope;
        if (envelope == null) {
          throw StateError('Training preview payload is unavailable.');
        }
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
        return _applyFood(preview, selectedMealIds);
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
    await _container.reportSyncPersistence.recordResponse(
      response,
      expectedOperationDate: response.operationDate,
    );
    return const ReportSyncApplyResult(
      ReportSyncDisposition.create,
      readBackVerified: true,
    );
  }

  Future<ReportSyncApplyResult> _applyFood(
    ReportSyncResponsePreview preview,
    Set<String>? selectedMealIds,
  ) async {
    try {
      final response = preview.envelope;
      final selectableIds = {
        for (final item in preview.foodMeals)
          if (item.canSelect) item.previewId,
      };
      final selected = selectedMealIds ?? selectableIds;
      if (selected.isEmpty || !selectableIds.containsAll(selected)) {
        throw const ReportSyncApplyException(
          code: 'invalid_food_selection',
          stage: 'MEAL SELECTION',
          userMessage: '取り込み可能なMEALを1件以上選択してください。',
        );
      }
      final selectedPreviews = [
        for (final item in preview.foodMeals)
          if (selected.contains(item.previewId)) item,
      ];
      final selectedPayload = <String, Object?>{
        ...response.payload,
        'meals': [
          for (
            var index = 0;
            index < (response.payload['meals'] as List).length;
            index++
          )
            if (selected.contains(preview.foodMeals[index].previewId))
              (response.payload['meals'] as List)[index],
        ],
      };
      final selectedResponse = _container.reportSyncCodec.create(
        direction: response.direction,
        exchangeType: response.exchangeType,
        exchangeId: response.exchangeId,
        requestId: response.requestId,
        operationDate: response.operationDate,
        createdAt: response.createdAt,
        requestDigest: response.requestDigest,
        confirmationDigest: response.confirmationDigest,
        payload: selectedPayload,
        schemaVersion: response.schemaVersion,
      );
      final mealCounts = ReportSyncMealCounts(
        received: preview.foodMeals.length,
        selected: selected.length,
        imported: selected.length,
        conflict: preview.conflictCount,
      );
      if (await _container.confirmation.isConfirmed(response.operationDate)) {
        throw const ReportSyncApplyException(
          code: 'food_finalized_blocked',
          stage: 'IMPORT PRECONDITION',
          userMessage: '確定済みの日付にはMEALを取り込めません。',
        );
      }
      try {
        await _container.reportSyncPersistence.importFoodMeals(
          selectedResponse,
          meals: [for (final item in selectedPreviews) item.meal],
          mealCounts: mealCounts,
        );
      } on ReportSyncImportFailure catch (error) {
        throw ReportSyncApplyException(
          code: error.code,
          stage: error.stage,
          userMessage: error.message,
        );
      }
      return ReportSyncApplyResult(
        ReportSyncDisposition.create,
        readBackVerified: true,
        mealCounts: mealCounts,
      );
    } on ReportSyncApplyException {
      rethrow;
    } on ReportSyncException catch (error) {
      throw ReportSyncApplyException(
        code: error.code.stableId,
        stage: 'IMPORT PREPARATION',
        userMessage: 'MEALの取り込み準備に失敗しました。',
      );
    } on FormatException {
      throw const ReportSyncApplyException(
        code: 'food_record_invalid',
        stage: 'FOOD RECORD MAPPING',
        userMessage: 'MEALを正式な保存形式へ変換できませんでした。',
      );
    } catch (_) {
      throw const ReportSyncApplyException(
        code: 'food_import_unexpected_failure',
        stage: 'FOOD IMPORT PREPARATION',
        userMessage: 'MEALの保存準備に失敗しました。保存処理は開始されていません。',
      );
    }
  }

  OrloSyncEnvelope _trainingEnvelope(
    ReportSyncEnvelope response,
    Map<String, Object?> mappedPayload,
  ) => OrloSyncEnvelope(
    envelopeVersion: OrloSyncEnvelope.currentEnvelopeVersion,
    schemaVersion: OrloSyncEnvelope.currentSchemaVersion,
    dataType: 'training',
    packageId: response.exchangeId,
    idempotencyKey: (mappedPayload['session'] as Map)['recordId'] as String,
    source: OrloSyncSource(
      type: 'chatGptExchange',
      generatedAt: response.createdAt,
      producer: 'report-sync',
      producerVersion: '1.0',
    ),
    operationDate: response.operationDate,
    payload: mappedPayload,
  );

  Future<MealData> _withUniqueFoodId(
    MealData meal,
    Set<String> reservedMealIds,
  ) async {
    var candidate = meal;
    while (reservedMealIds.contains(candidate.id) ||
        await _container.food.findById(candidate.id) != null) {
      candidate = MealData(
        date: meal.date,
        mealType: meal.mealType,
        items: meal.items,
        memo: meal.memo,
        id: (foodIdGenerator ?? FoodMealIdGenerator()).generate(),
        waterMl: meal.waterMl,
      );
    }
    reservedMealIds.add(candidate.id);
    return candidate;
  }

  @override
  Future<List<ReportSyncHistory>> history(ReportSyncExchangeType type) async =>
      (await _container.reportSyncHistory.list())
          .where((value) => value.exchangeType == type)
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
