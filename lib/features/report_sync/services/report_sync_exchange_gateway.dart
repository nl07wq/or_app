import '../../../core/models/meal_data.dart';
import '../../daily_aggregate/models/recent_context.dart';
import '../../daily_aggregate/services/recent_context_builder.dart';
import '../../operation_sync/services/historical_training_workflow.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../operation_date/models/operation_state.dart';
import '../../food/repository/food_meal_id_generator.dart';
import '../../repositories/app_repository_container.dart';
import '../../training/repository/training_record_id_generator.dart';
import '../models/report_sync_envelope.dart';
import '../models/daily_debrief_record.dart';
import '../models/report_sync_history.dart';
import '../models/report_sync_issue.dart';
import '../models/status_report_sync_source.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_payload_adapters.dart';
import 'report_sync_persistence_service.dart';
import 'status_report_sync_source_service.dart';
import 'daily_debrief_source_service.dart';

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
    this.sourceText,
    this.statusSourceExport,
    this.statusSourceError,
    this.statusLabel = 'REQUEST NOT READY',
    this.blockingReason,
    this.dailyDebriefSource,
    this.recentContext,
    this.eligibleDates = const [],
  });

  final ReportSyncEnvelope? envelope;
  final String? operationDate;
  final String? sourceText;
  final StatusReportSyncSourceExport? statusSourceExport;
  final StatusReportSyncSourceException? statusSourceError;
  final String statusLabel;
  final String? blockingReason;
  final DailyDebriefSourcePackage? dailyDebriefSource;
  final RecentContext? recentContext;
  final List<String> eligibleDates;
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
    this.trainingPreview,
    this.morningBriefSourceDigestMatches = false,
    this.dailyDebriefRecord,
    this.dailyDebriefLifecycle,
  });

  final ReportSyncEnvelope? envelope;
  final ReportSyncDisposition disposition;
  final int createCount;
  final int noChangeCount;
  final int conflictCount;
  final String? message;
  final List<FoodReportSyncMealPreview> foodMeals;
  final HistoricalTrainingPreview? trainingPreview;
  final bool morningBriefSourceDigestMatches;
  final DailyDebriefRecord? dailyDebriefRecord;
  final DailyDebriefLifecycleStatus? dailyDebriefLifecycle;
  bool get canApply => disposition == ReportSyncDisposition.create;
  String get operationDate =>
      trainingPreview?.requestedStartDate ?? envelope!.operationDate;
  ReportSyncExchangeType get exchangeType => trainingPreview == null
      ? envelope!.exchangeType
      : ReportSyncExchangeType.training;
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

  HistoricalTrainingWorkflowService _historicalTrainingWorkflow() =>
      HistoricalTrainingWorkflowService(
        database: _container.database,
        customExercises: _container.customTrainingExercises,
        clock: _clock,
        idGenerator: trainingIdGenerator,
      );

  @override
  Future<ReportSyncRequestPreparation> prepareRequest(
    ReportSyncExchangeType type, {
    String? targetDate,
  }) async {
    final state = await _container.operationState.requireCurrent();
    if (targetDate != null) OperationLocalDate.parse(targetDate);
    final operationDate = targetDate ?? state.operationDate.value;

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
          final recentContext = await _container.recentContextBuilder.build(
            targetDate: operationDate,
            window: RecentContextWindow.dailyBrief,
          );
          return ReportSyncRequestPreparation(
            operationDate: operationDate,
            sourceText: source.plainText,
            statusSourceExport: source,
            recentContext: recentContext,
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
        final eligible = await _container.dailyDebriefSources.eligibleDates();
        final selected =
            targetDate ??
            await _container.dailyDebriefSources.defaultEligibleDate();
        if (selected == null || !eligible.contains(selected)) {
          return ReportSyncRequestPreparation(
            eligibleDates: eligible,
            blockingReason: 'DAILY DEBRIEFを生成できる確定済み日付がありません。',
          );
        }
        final source = await _container.dailyDebriefSources.requireEligible(
          selected,
        );
        return ReportSyncRequestPreparation(
          operationDate: selected,
          dailyDebriefSource: source,
          eligibleDates: eligible,
          statusLabel: 'READY',
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
    if (type == ReportSyncExchangeType.training) {
      return _historicalTrainingWorkflow().buildPrompt(
        startDate: operationDate,
        endDate: operationDate,
      );
    }
    final instruction = _container.reportSyncInstructions
        .forType(type)
        .buildInstruction(
          operationDate: operationDate,
          sourceRecordId: preparation.statusSourceExport?.source.sourceRecordId,
          sourceDigest: preparation.statusSourceExport?.sourceDigest,
          recentContext: preparation.recentContext?.toJson(),
          dailyDebriefSources: preparation.dailyDebriefSource?.references,
          dailyDebriefSource: preparation.dailyDebriefSource?.promptSource,
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
    if (type == ReportSyncExchangeType.training) {
      if (targetDate == null) {
        throw StateError('Training target date is required.');
      }
      OperationLocalDate.parse(targetDate);
      return _previewTraining(rawResponse, targetDate);
    }
    final normalizedResponse = type == ReportSyncExchangeType.dailyDebrief
        ? _normalizeDailyDebriefResponseInput(rawResponse)
        : rawResponse;
    final response = _container.reportSyncCodec.decode(normalizedResponse);
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
      ReportSyncExchangeType.training => throw StateError(
        'Training uses Historical Training preview.',
      ),
      ReportSyncExchangeType.food => _previewFood(response),
      ReportSyncExchangeType.morningBrief => _previewMorningBrief(response),
      ReportSyncExchangeType.dailyDebrief => _previewDailyDebrief(response),
    };
    return preview;
  }

  String _normalizeDailyDebriefResponseInput(String input) {
    var normalized = input.trim();
    if (normalized.startsWith('\uFEFF')) {
      normalized = normalized.substring(1).trim();
    }
    final fenced = RegExp(
      r'^```(?:text|json)?[ \t]*\r?\n([\s\S]*)\r?\n```$',
    ).firstMatch(normalized);
    if (fenced != null) normalized = fenced.group(1)!.trim();
    return normalized;
  }

  Future<ReportSyncResponsePreview> _previewDailyDebrief(
    ReportSyncEnvelope response,
  ) async {
    if (response.schemaVersion != ReportSyncEnvelope.importSchemaVersion2) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'Daily Debrief requires Schema 2.0.',
      );
    }
    final source = await _container.dailyDebriefSources.requireEligible(
      response.operationDate,
    );
    final payloadSources = DailyDebriefSources.fromJson(
      Map<String, Object?>.from(response.payload['sources'] as Map),
    );
    if (ReportSyncCanonicalService.encode(payloadSources.toJson()) !=
        ReportSyncCanonicalService.encode(source.references.toJson())) {
      return ReportSyncResponsePreview(
        envelope: response,
        disposition: ReportSyncDisposition.blocked,
        createCount: 0,
        noChangeCount: 0,
        conflictCount: 1,
        message: 'SOURCE REFERENCESが現在の正式Sourceと一致しません。',
      );
    }
    final existing = await _container.dailyDebriefs.readByLocalDate(
      response.operationDate,
    );
    return ReportSyncResponsePreview(
      envelope: response,
      disposition: ReportSyncDisposition.create,
      createCount: 1,
      noChangeCount: 0,
      conflictCount: 0,
      dailyDebriefRecord: existing,
      dailyDebriefLifecycle: existing == null
          ? null
          : await _container.dailyDebriefSources.projectLifecycle(existing),
    );
  }

  Future<ReportSyncResponsePreview> _previewTraining(
    String rawResponse,
    String targetDate,
  ) async {
    final preview = await _historicalTrainingWorkflow().preview(
      rawResponse,
      startDate: targetDate,
      endDate: targetDate,
    );
    final disposition = preview.invalidCount > 0 || preview.blockedCount > 0
        ? ReportSyncDisposition.blocked
        : preview.conflictCount > 0
        ? ReportSyncDisposition.conflict
        : preview.newCount > 0
        ? ReportSyncDisposition.create
        : ReportSyncDisposition.noChanges;
    final issues = [
      for (final item in preview.records)
        for (final issue in item.issues)
          '${issue.path ?? r'$'}: ${issue.message}',
    ];
    return ReportSyncResponsePreview(
      envelope: null,
      disposition: disposition,
      createCount: preview.newCount,
      noChangeCount: preview.identicalCount + preview.excludedCount,
      conflictCount: preview.conflictCount + preview.blockedCount,
      message: issues.isEmpty ? null : issues.join('\n'),
      trainingPreview: preview,
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
    final trainingPreview = preview.trainingPreview;
    if (trainingPreview != null) {
      await _historicalTrainingWorkflow().apply(trainingPreview);
      return const ReportSyncApplyResult(
        ReportSyncDisposition.create,
        readBackVerified: true,
      );
    }
    final response = preview.envelope!;
    switch (response.exchangeType) {
      case ReportSyncExchangeType.training:
        throw StateError('Training uses Historical Training import.');
      case ReportSyncExchangeType.food:
        return _applyFood(preview, selectedMealIds);
      case ReportSyncExchangeType.morningBrief:
        await _container.reportSyncPersistence.importMorningBrief(response);
        return const ReportSyncApplyResult(
          ReportSyncDisposition.create,
          readBackVerified: true,
        );
      case ReportSyncExchangeType.dailyDebrief:
        await _container.reportSyncPersistence.importDailyDebrief(
          response,
          sourceService: _container.dailyDebriefSources,
          repository: _container.dailyDebriefs,
        );
        return const ReportSyncApplyResult(
          ReportSyncDisposition.create,
          readBackVerified: true,
        );
    }
  }

  Future<ReportSyncApplyResult> _applyFood(
    ReportSyncResponsePreview preview,
    Set<String>? selectedMealIds,
  ) async {
    try {
      final response = preview.envelope!;
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
