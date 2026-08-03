import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../core/models/meal_data.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../food/models/persisted_food_record.dart';
import '../models/daily_debrief_record.dart';
import '../models/morning_brief_record.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_history.dart';
import '../models/report_sync_issue.dart';
import '../repository/report_sync_history_repository.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_validator.dart';

class ReportSyncImportFailure implements Exception {
  const ReportSyncImportFailure({
    required this.code,
    required this.stage,
    required this.message,
    this.cause,
    this.causeStackTrace,
    this.store,
    this.recordId,
    this.mealIndex,
  });

  final String code;
  final String stage;
  final String message;
  final Object? cause;
  final StackTrace? causeStackTrace;
  final String? store;
  final String? recordId;
  final int? mealIndex;
}

class ReportSyncPersistenceService {
  final IndexedDbDatabase database;
  final ReportSyncHistoryRepository historyRepository;
  final ReportSyncValidator validator;
  final DateTime Function() clock;
  const ReportSyncPersistenceService({
    required this.database,
    required this.historyRepository,
    required this.validator,
    required this.clock,
  });

  Future<ReportSyncHistory> recordRequest(
    ReportSyncEnvelope request, {
    String? confirmationDigest,
  }) {
    if (request.direction != ReportSyncDirection.request) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'Request envelope required.',
      );
    }
    if (request.requestId == null || request.requestDigest == null) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'Legacy request identity is required for request history.',
      );
    }
    final payloadConfirmation =
        request.exchangeType == ReportSyncExchangeType.dailyDebrief
        ? request.payload['confirmationDigest'] as String?
        : null;
    if (confirmationDigest != null &&
        payloadConfirmation != null &&
        confirmationDigest != payloadConfirmation) {
      throw const ReportSyncException(
        ReportSyncIssueCode.confirmationDigestMismatch,
        'Request confirmationDigest does not match its payload.',
      );
    }
    final now = clock().toUtc();
    return historyRepository.create(
      ReportSyncHistory(
        exchangeId: request.exchangeId,
        exchangeType: request.exchangeType,
        direction: request.direction,
        operationDate: request.operationDate,
        requestId: request.requestId!,
        requestDigest: request.requestDigest!,
        confirmationDigest: confirmationDigest ?? payloadConfirmation,
        startedAt: request.createdAt,
        completedAt: now,
        result: ReportSyncHistoryResult.success,
        packageDigest: request.packageDigest,
      ),
    );
  }

  Future<ReportSyncHistory> recordResponse(
    ReportSyncEnvelope response, {
    String? expectedOperationDate,
    ReportSyncMealCounts? mealCounts,
  }) async {
    await validator.validateResponse(
      response,
      expectedOperationDate: expectedOperationDate,
    );
    return _apply(
      response,
      domainStore: null,
      domainRecord: null,
      mealCounts: mealCounts,
    );
  }

  Future<ReportSyncHistory> importFoodMeals(
    ReportSyncEnvelope response, {
    required List<MealData> meals,
    required ReportSyncMealCounts mealCounts,
  }) async {
    try {
      await validator.validateResponse(
        response,
        expectedOperationDate: response.operationDate,
      );
    } on ReportSyncException catch (error) {
      throw ReportSyncImportFailure(
        code: error.code.stableId,
        stage: 'IMPORT PRECONDITION',
        message: '取り込み条件を確認できませんでした。',
        cause: error,
      );
    }

    final timestamp = clock().toUtc();
    final ReportSyncHistory history;
    try {
      history = _history(
        response,
        mealCounts: mealCounts,
        completedAt: timestamp,
      );
    } on FormatException catch (error) {
      throw ReportSyncImportFailure(
        code: 'history_record_invalid',
        stage: 'HISTORY RECORD MAPPING',
        message: 'REPORT SYNC履歴を作成できませんでした。',
        cause: error,
      );
    }
    final recordsByMealId = <String, Map<String, Object?>>{};
    try {
      for (final meal in meals) {
        if (recordsByMealId.containsKey(meal.id)) {
          throw const ReportSyncImportFailure(
            code: 'duplicate_food_record_id',
            stage: 'FOOD ID VALIDATION',
            message: '同じ正式IDのMEALが複数含まれているため取り込めません。',
          );
        }
        recordsByMealId[meal.id] = PersistedFoodRecord(
          id: PersistedFoodRecord.envelopeId(meal.id),
          localDate: PersistedFoodRecord.localDateFromMealDate(meal.date),
          createdAt: timestamp,
          updatedAt: timestamp,
          data: meal,
        ).toRecord();
      }
    } on ReportSyncImportFailure {
      rethrow;
    } on FormatException catch (error) {
      throw ReportSyncImportFailure(
        code: 'food_record_invalid',
        stage: 'FOOD RECORD MAPPING',
        message: 'MEALを正式な保存形式へ変換できませんでした。',
        cause: error,
      );
    }

    var currentStage = 'TRANSACTION OPEN';
    var currentStore =
        '${IndexedDbStoreNames.foodRecords}, '
        '${IndexedDbStoreNames.reportSyncHistory}';
    String? currentRecordId;
    int? currentMealIndex;
    try {
      return await database.runTransaction(
        storeNames: const [
          IndexedDbStoreNames.foodRecords,
          IndexedDbStoreNames.reportSyncHistory,
        ],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existingByMealId = <String, Map<String, Object?>?>{};
          for (var index = 0; index < meals.length; index++) {
            final meal = meals[index];
            final id = PersistedFoodRecord.envelopeId(meal.id);
            currentStage = 'FOOD CONFLICT CHECK';
            currentStore = IndexedDbStoreNames.foodRecords;
            currentRecordId = id;
            currentMealIndex = index;
            final existing = await transaction.findById(
              IndexedDbStoreNames.foodRecords,
              id,
            );
            existingByMealId[meal.id] = existing;
            if (existing != null) {
              final stored = PersistedFoodRecord.fromRecord(existing).data;
              if (!_equal(stored.toJson(), meal.toJson())) {
                throw const ReportSyncImportFailure(
                  code: 'food_record_conflict',
                  stage: 'FOOD RECORD CONFLICT CHECK',
                  message: '同じIDの異なるMEALが存在するため取り込めません。',
                );
              }
            }
          }

          currentStage = 'HISTORY CONFLICT CHECK';
          currentStore = IndexedDbStoreNames.reportSyncHistory;
          currentRecordId = history.exchangeId;
          currentMealIndex = null;
          final existingHistory = await transaction.findById(
            IndexedDbStoreNames.reportSyncHistory,
            history.exchangeId,
          );
          if (existingHistory != null &&
              !_equal(existingHistory, history.toRecord())) {
            throw const ReportSyncImportFailure(
              code: 'report_sync_history_conflict',
              stage: 'HISTORY CONFLICT CHECK',
              message: '同じExchange IDの異なる履歴が存在するため取り込めません。',
            );
          }

          for (var index = 0; index < meals.length; index++) {
            final meal = meals[index];
            if (existingByMealId[meal.id] != null) continue;
            currentStage = 'FOOD RECORD PUT';
            currentStore = IndexedDbStoreNames.foodRecords;
            currentRecordId = PersistedFoodRecord.envelopeId(meal.id);
            currentMealIndex = index;
            await transaction.put(
              IndexedDbStoreNames.foodRecords,
              recordsByMealId[meal.id]!,
            );
          }

          if (existingHistory == null) {
            currentStage = 'HISTORY RECORD PUT';
            currentStore = IndexedDbStoreNames.reportSyncHistory;
            currentRecordId = history.exchangeId;
            currentMealIndex = null;
            await transaction.put(
              IndexedDbStoreNames.reportSyncHistory,
              history.toRecord(),
            );
          }

          for (var index = 0; index < meals.length; index++) {
            final meal = meals[index];
            currentStage = 'FOOD READ-BACK';
            currentStore = IndexedDbStoreNames.foodRecords;
            currentRecordId = PersistedFoodRecord.envelopeId(meal.id);
            currentMealIndex = index;
            final readBack = await transaction.findById(
              IndexedDbStoreNames.foodRecords,
              PersistedFoodRecord.envelopeId(meal.id),
            );
            if (readBack == null) {
              throw const ReportSyncImportFailure(
                code: 'food_read_back_failed',
                stage: 'FOOD READ-BACK VERIFICATION',
                message: '保存したMEALを読み戻せませんでした。',
              );
            }
            currentStage = 'READ-BACK COMPARISON';
            if (!_equal(
              PersistedFoodRecord.fromRecord(readBack).data.toJson(),
              meal.toJson(),
            )) {
              throw const ReportSyncImportFailure(
                code: 'food_read_back_mismatch',
                stage: 'READ-BACK COMPARISON',
                message: '保存したMEALの内容が読み戻し結果と一致しません。',
              );
            }
          }
          currentStage = 'HISTORY READ-BACK';
          currentStore = IndexedDbStoreNames.reportSyncHistory;
          currentRecordId = history.exchangeId;
          currentMealIndex = null;
          final historyReadBack = await transaction.findById(
            IndexedDbStoreNames.reportSyncHistory,
            history.exchangeId,
          );
          if (historyReadBack == null) {
            throw const ReportSyncImportFailure(
              code: 'history_read_back_failed',
              stage: 'HISTORY READ-BACK VERIFICATION',
              message: '保存したREPORT SYNC履歴を読み戻せませんでした。',
            );
          }
          currentStage = 'READ-BACK COMPARISON';
          if (!_equal(historyReadBack, history.toRecord())) {
            throw const ReportSyncImportFailure(
              code: 'history_read_back_mismatch',
              stage: 'READ-BACK COMPARISON',
              message: '保存したREPORT SYNC履歴が読み戻し結果と一致しません。',
            );
          }
          currentStage = 'TRANSACTION COMMIT';
          currentStore =
              '${IndexedDbStoreNames.foodRecords}, '
              '${IndexedDbStoreNames.reportSyncHistory}';
          currentRecordId = null;
          return history;
        },
      );
    } on ReportSyncImportFailure catch (error, stackTrace) {
      final failure = ReportSyncImportFailure(
        code: error.code,
        stage: error.stage,
        message: error.message,
        cause: error.cause ?? error,
        causeStackTrace: error.causeStackTrace ?? stackTrace,
        store: error.store ?? currentStore,
        recordId: error.recordId ?? currentRecordId,
        mealIndex: error.mealIndex ?? currentMealIndex,
      );
      _logFoodImportFailure(failure);
      throw failure;
    } catch (error, stackTrace) {
      final failure = ReportSyncImportFailure(
        code: _transactionErrorCode(currentStage, currentStore),
        stage: currentStage,
        message: _transactionErrorMessage(currentStage, currentStore),
        cause: error,
        causeStackTrace: stackTrace,
        store: currentStore,
        recordId: currentRecordId,
        mealIndex: currentMealIndex,
      );
      _logFoodImportFailure(failure);
      throw failure;
    }
  }

  Future<ReportSyncHistory> importMorningBrief(
    ReportSyncEnvelope response,
  ) async {
    if (response.exchangeType != ReportSyncExchangeType.morningBrief) {
      throw const ReportSyncException(
        ReportSyncIssueCode.exchangeTypeMismatch,
        'Morning Brief response required.',
      );
    }
    await validator.validateResponse(response);
    final payload = response.payload;
    final content = Map<String, Object?>.from(payload['content'] as Map);
    final now = clock().toUtc();
    final generated = DateTime.tryParse(
      payload['generatedAt'] is String ? payload['generatedAt'] as String : '',
    );
    final actions = content['actions'];
    if (generated == null ||
        !generated.isUtc ||
        actions is! List ||
        actions.any((v) => v is! Map)) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'Morning Brief response payload is invalid.',
      );
    }
    final record = MorningBriefRecord(
      localDate: response.operationDate,
      requestId: _legacyRequestId(response),
      requestDigest: _legacyRequestDigest(response),
      responseDigest: ReportSyncCanonicalService.digest(payload),
      generatedAt: generated,
      importedAt: now,
      situationAnalysis: _string(content, 'situationAnalysis'),
      operationStatus: MorningBriefOperationStatus.values.firstWhere(
        (v) => v.stableId == content['operationStatus'],
        orElse: () => throw const ReportSyncException(
          ReportSyncIssueCode.schemaMismatch,
          'Unknown operation status.',
        ),
      ),
      commanderIntent: _string(content, 'commanderIntent'),
      argoComment: _string(content, 'argoComment'),
      strategicResourceDecision: _string(content, 'strategicResourceDecision'),
      actions: [
        for (final value in actions)
          MorningBriefAction.fromJson(Map<String, Object?>.from(value as Map)),
      ],
      createdAt: now,
      updatedAt: now,
    );
    return _apply(
      response,
      domainStore: IndexedDbStoreNames.morningBriefRecords,
      domainRecord: record.toRecord(),
    );
  }

  Future<ReportSyncHistory> importDailyDebrief(
    ReportSyncEnvelope response,
  ) async {
    if (response.exchangeType != ReportSyncExchangeType.dailyDebrief) {
      throw const ReportSyncException(
        ReportSyncIssueCode.exchangeTypeMismatch,
        'Daily Debrief response required.',
      );
    }
    await validator.validateResponse(response);
    final payload = response.payload;
    final content = Map<String, Object?>.from(payload['content'] as Map);
    final now = clock().toUtc();
    final generated = DateTime.tryParse(
      payload['generatedAt'] is String ? payload['generatedAt'] as String : '',
    );
    if (generated == null || !generated.isUtc) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'generatedAt is invalid.',
      );
    }
    List<String> list(String key) {
      final value = content[key];
      if (value is! List || value.any((v) => v is! String || v.isEmpty)) {
        throw ReportSyncException(
          ReportSyncIssueCode.schemaMismatch,
          '$key is invalid.',
        );
      }
      return value.cast<String>();
    }

    final record = DailyDebriefRecord(
      localDate: response.operationDate,
      requestId: _legacyRequestId(response),
      requestDigest: _legacyRequestDigest(response),
      responseDigest: ReportSyncCanonicalService.digest(payload),
      confirmationDigest: response.confirmationDigest!,
      generatedAt: generated,
      importedAt: now,
      dailySummary: _string(content, 'dailySummary'),
      commanderIntentEvaluation: _string(content, 'commanderIntentEvaluation'),
      successes: list('successes'),
      issues: list('issues'),
      nutritionEvaluation: _string(content, 'nutritionEvaluation'),
      activityEvaluation: _string(content, 'activityEvaluation'),
      trainingEvaluation: _string(content, 'trainingEvaluation'),
      recoveryEvaluation: _string(content, 'recoveryEvaluation'),
      carryover: list('carryover'),
      tomorrowConsiderations: list('tomorrowConsiderations'),
      createdAt: now,
      updatedAt: now,
    );
    return _apply(
      response,
      domainStore: IndexedDbStoreNames.dailyDebriefRecords,
      domainRecord: record.toRecord(),
    );
  }

  Future<ReportSyncHistory> _apply(
    ReportSyncEnvelope response, {
    required String? domainStore,
    required Map<String, Object?>? domainRecord,
    ReportSyncMealCounts? mealCounts,
  }) async {
    final history = _history(
      response,
      mealCounts: mealCounts,
      completedAt: clock().toUtc(),
    );
    final stores = [?domainStore, IndexedDbStoreNames.reportSyncHistory];
    return database.runTransaction(
      storeNames: stores,
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        if (domainStore != null && domainRecord != null) {
          final id = domainRecord['localDate'] as String;
          final existing = await transaction.findById(domainStore, id);
          if (existing != null && !_equal(existing, domainRecord)) {
            throw const ReportSyncException(
              ReportSyncIssueCode.recordConflict,
              'Domain record conflict.',
            );
          }
          if (existing == null) {
            await transaction.put(domainStore, domainRecord);
          }
        }
        final existingHistory = await transaction.findById(
          IndexedDbStoreNames.reportSyncHistory,
          history.exchangeId,
        );
        if (existingHistory != null &&
            !_equal(existingHistory, history.toRecord())) {
          throw const ReportSyncException(
            ReportSyncIssueCode.recordConflict,
            'History record conflict.',
          );
        }
        if (existingHistory == null) {
          await transaction.put(
            IndexedDbStoreNames.reportSyncHistory,
            history.toRecord(),
          );
        }
        if (domainStore != null &&
            !_equal(
              await transaction.findById(domainStore, response.operationDate),
              domainRecord,
            )) {
          throw const ReportSyncException(
            ReportSyncIssueCode.integrityFailure,
            'Domain read-back failed.',
          );
        }
        if (!_equal(
          await transaction.findById(
            IndexedDbStoreNames.reportSyncHistory,
            history.exchangeId,
          ),
          history.toRecord(),
        )) {
          throw const ReportSyncException(
            ReportSyncIssueCode.integrityFailure,
            'History read-back failed.',
          );
        }
        return history;
      },
    );
  }

  ReportSyncHistory _history(
    ReportSyncEnvelope response, {
    ReportSyncMealCounts? mealCounts,
    required DateTime completedAt,
  }) => ReportSyncHistory(
    exchangeId: response.exchangeId,
    exchangeType: response.exchangeType,
    direction: response.direction,
    operationDate: response.operationDate,
    requestId: _legacyRequestId(response),
    requestDigest: _legacyRequestDigest(response),
    responseDigest: ReportSyncCanonicalService.digest(response.payload),
    confirmationDigest: response.confirmationDigest,
    startedAt: response.createdAt,
    completedAt: completedAt,
    result: ReportSyncHistoryResult.success,
    packageDigest: response.packageDigest,
    receivedMealCount: mealCounts?.received,
    selectedMealCount: mealCounts?.selected,
    importedMealCount: mealCounts?.imported,
    conflictMealCount: mealCounts?.conflict,
    excludedMealCount: mealCounts?.excluded,
  );

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        '$key is invalid.',
      );
    }
    return value;
  }

  static bool _equal(Object? a, Object? b) =>
      ReportSyncCanonicalService.encode(a) ==
      ReportSyncCanonicalService.encode(b);

  static String _transactionErrorCode(String stage, String store) =>
      switch (stage) {
    'FOOD RECORD PUT' => 'food_record_put_failed',
    'HISTORY RECORD PUT' => 'history_record_put_failed',
    'FOOD READ-BACK' => 'food_read_back_failed',
    'HISTORY READ-BACK' => 'history_read_back_failed',
    'READ-BACK COMPARISON' =>
      store == IndexedDbStoreNames.reportSyncHistory
          ? 'history_read_back_mismatch'
          : 'food_read_back_mismatch',
    'TRANSACTION COMMIT' => 'food_transaction_aborted',
    _ => 'food_transaction_failed',
  };

  static String _transactionErrorMessage(String stage, String store) =>
      switch (stage) {
    'FOOD RECORD PUT' => 'MEALを保存できませんでした。変更はすべて取り消されました。',
    'HISTORY RECORD PUT' => '取り込み履歴を保存できませんでした。変更はすべて取り消されました。',
    'FOOD READ-BACK' =>
      '保存したMEALを確認できませんでした。変更はすべて取り消されました。',
    'READ-BACK COMPARISON' =>
      store == IndexedDbStoreNames.reportSyncHistory
          ? '保存した取り込み履歴を確認できませんでした。変更はすべて取り消されました。'
          : '保存したMEALを確認できませんでした。変更はすべて取り消されました。',
    'HISTORY READ-BACK' =>
      '保存した取り込み履歴を確認できませんでした。変更はすべて取り消されました。',
    'TRANSACTION COMMIT' => '保存Transactionが中断されました。変更はすべて取り消されました。',
    _ => 'MEALの保存に失敗しました。変更はすべて取り消されました。',
  };

  static void _logFoodImportFailure(ReportSyncImportFailure failure) {
    final diagnostic =
        'FOOD IMPORT TRANSACTION FAILED\n'
      'Stage: ${failure.stage}\n'
      'Store: ${failure.store ?? '-'}\n'
      'Record ID: ${failure.recordId ?? '-'}\n'
      'Meal Index: ${failure.mealIndex == null ? '-' : failure.mealIndex! + 1}\n'
      'Cause Type: ${failure.cause?.runtimeType ?? '-'}\n'
        'Cause: ${failure.cause ?? '-'}';
    debugPrint(diagnostic);
    developer.log(
      diagnostic,
      name: 'operation_reboot.report_sync.food_import',
      error: failure.cause,
      stackTrace: failure.causeStackTrace,
    );
  }

  static String _legacyRequestId(ReportSyncEnvelope response) =>
      response.requestId ?? response.exchangeId;

  static String _legacyRequestDigest(ReportSyncEnvelope response) =>
      response.requestDigest ?? response.packageDigest;
}
