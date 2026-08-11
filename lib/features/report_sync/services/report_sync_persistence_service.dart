import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../core/models/meal_data.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../food/models/persisted_food_record.dart';
import '../models/morning_brief_record.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_history.dart';
import '../models/report_sync_issue.dart';
import '../repository/report_sync_history_repository.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_validator.dart';
import 'status_report_sync_source_service.dart';

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

  Future<ReportSyncHistory> recordRequest(ReportSyncEnvelope request) {
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
    final now = clock().toUtc();
    return historyRepository.create(
      ReportSyncHistory(
        exchangeId: request.exchangeId,
        exchangeType: request.exchangeType,
        direction: request.direction,
        operationDate: request.operationDate,
        requestId: request.requestId!,
        requestDigest: request.requestDigest!,
        confirmationDigest: null,
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
    if (response.schemaVersion != ReportSyncEnvelope.importSchemaVersion2) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'Morning Brief requires Schema 2.0.',
      );
    }
    await validator.validateResponse(
      response,
      expectedOperationDate: response.operationDate,
    );
    final payload = response.payload;
    final source = Map<String, Object?>.from(payload['source'] as Map);
    final content = Map<String, Object?>.from(payload['content'] as Map);
    final currentSource = await StatusReportSyncSourceService(
      database,
    ).generate(operationDate: response.operationDate, exportedAt: clock());
    final expectedSource = <String, Object?>{
      'sourceType': 'status',
      'sourceOperationDate': response.operationDate,
      'sourceRecordId': currentSource.source.sourceRecordId,
      'sourceDigest': currentSource.sourceDigest,
    };
    if (!_equal(source, expectedSource)) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Morning Brief STATUS source identity changed before import.',
      );
    }

    final analysis = Map<String, Object?>.from(
      content['situationAnalysis'] as Map,
    );
    final decision = Map<String, Object?>.from(
      content['strategicResourceDecision'] as Map,
    );
    final actionValues = (content['actions'] as List).cast<Map>();
    final now = clock().toUtc();
    final record = MorningBriefRecord.v2(
      localDate: response.operationDate,
      sourceType: 'status',
      sourceOperationDate: response.operationDate,
      sourceRecordId: currentSource.source.sourceRecordId,
      sourceDigest: currentSource.sourceDigest,
      responseDigest: ReportSyncCanonicalService.digest(payload),
      exchangeId: response.exchangeId,
      generatedAt: response.createdAt,
      importedAt: now,
      situationAnalysisV2: MorningBriefSituationAnalysis.fromJson(analysis),
      operatingPolicy: _string(content, 'operatingPolicy'),
      strategicResourceDecisionV2:
          MorningBriefStrategicResourceDecision.fromJson(decision),
      operationStatus: MorningBriefOperationStatus.values.firstWhere(
        (value) => value.stableId == content['operationStatus'],
      ),
      commanderIntent: _string(content, 'commanderIntent'),
      actions: [
        for (var index = 0; index < actionValues.length; index++)
          MorningBriefAction(
            actionId: '${response.operationDate}:action:${index + 1}',
            text: _string(
              Map<String, Object?>.from(actionValues[index]),
              'text',
            ),
            priority: _string(
              Map<String, Object?>.from(actionValues[index]),
              'priority',
            ),
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    final history = _history(response, completedAt: clock().toUtc());
    var stage = 'TRANSACTION START';
    var store = IndexedDbStoreNames.morningBriefRecords;
    try {
      return await database.runTransaction(
        storeNames: const [
          IndexedDbStoreNames.morningBriefRecords,
          IndexedDbStoreNames.reportSyncHistory,
        ],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          stage = 'MORNING BRIEF CONFLICT CHECK';
          if (await transaction.findById(store, record.localDate) != null) {
            throw const ReportSyncException(
              ReportSyncIssueCode.recordConflict,
              'A Morning Brief already exists for this operation date.',
            );
          }
          store = IndexedDbStoreNames.reportSyncHistory;
          final existingHistory = await transaction.findById(
            store,
            history.exchangeId,
          );
          if (existingHistory != null) {
            throw const ReportSyncException(
              ReportSyncIssueCode.recordConflict,
              'Report Sync record conflict.',
            );
          }
          stage = 'MORNING BRIEF PUT';
          store = IndexedDbStoreNames.morningBriefRecords;
          await transaction.put(store, record.toRecord());
          stage = 'REPORT SYNC RECORD PUT';
          store = IndexedDbStoreNames.reportSyncHistory;
          await transaction.put(store, history.toRecord());
          stage = 'MORNING BRIEF READ-BACK';
          store = IndexedDbStoreNames.morningBriefRecords;
          final savedRecord = await transaction.findById(
            store,
            record.localDate,
          );
          if (savedRecord == null ||
              !_equal(
                MorningBriefRecord.fromRecord(
                  Map<String, Object?>.from(savedRecord),
                ).toRecord(),
                record.toRecord(),
              )) {
            throw const ReportSyncException(
              ReportSyncIssueCode.integrityFailure,
              'Morning Brief read-back failed.',
            );
          }
          stage = 'REPORT SYNC RECORD READ-BACK';
          store = IndexedDbStoreNames.reportSyncHistory;
          final savedHistory = await transaction.findById(
            store,
            history.exchangeId,
          );
          if (savedHistory == null ||
              !_equal(
                ReportSyncHistory.fromRecord(
                  Map<String, Object?>.from(savedHistory),
                ).toRecord(),
                history.toRecord(),
              )) {
            throw const ReportSyncException(
              ReportSyncIssueCode.integrityFailure,
              'Report Sync record read-back failed.',
            );
          }
          stage = 'TRANSACTION COMMIT';
          return history;
        },
      );
    } on ReportSyncException catch (error, stackTrace) {
      if (error.code == ReportSyncIssueCode.recordConflict) rethrow;
      throw ReportSyncImportFailure(
        code: 'morning_brief_import_failed',
        stage: stage,
        message: 'Morning Brief import failed and was rolled back.',
        cause: error,
        causeStackTrace: stackTrace,
        store: store,
        recordId: record.localDate,
      );
    } catch (error, stackTrace) {
      throw ReportSyncImportFailure(
        code: 'morning_brief_import_failed',
        stage: stage,
        message: 'Morning Brief import failed and was rolled back.',
        cause: error,
        causeStackTrace: stackTrace,
        store: store,
        recordId: record.localDate,
      );
    }
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
        'FOOD READ-BACK' => '保存したMEALを確認できませんでした。変更はすべて取り消されました。',
        'READ-BACK COMPARISON' =>
          store == IndexedDbStoreNames.reportSyncHistory
              ? '保存した取り込み履歴を確認できませんでした。変更はすべて取り消されました。'
              : '保存したMEALを確認できませんでした。変更はすべて取り消されました。',
        'HISTORY READ-BACK' => '保存した取り込み履歴を確認できませんでした。変更はすべて取り消されました。',
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
