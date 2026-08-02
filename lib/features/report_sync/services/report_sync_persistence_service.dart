import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../models/daily_debrief_record.dart';
import '../models/morning_brief_record.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_history.dart';
import '../models/report_sync_issue.dart';
import '../repository/report_sync_history_repository.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_validator.dart';

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

  Future<ReportSyncHistory> recordResponse(ReportSyncEnvelope response) async {
    await validator.validateResponse(response);
    return _apply(response, domainStore: null, domainRecord: null);
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
  }) async {
    final now = clock().toUtc();
    final history = ReportSyncHistory(
      exchangeId: response.exchangeId,
      exchangeType: response.exchangeType,
      direction: response.direction,
      operationDate: response.operationDate,
      requestId: _legacyRequestId(response),
      requestDigest: _legacyRequestDigest(response),
      responseDigest: ReportSyncCanonicalService.digest(response.payload),
      confirmationDigest: response.confirmationDigest,
      startedAt: response.createdAt,
      completedAt: now,
      result: ReportSyncHistoryResult.success,
      packageDigest: response.packageDigest,
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

  static String _legacyRequestId(ReportSyncEnvelope response) =>
      response.requestId ?? response.exchangeId;

  static String _legacyRequestDigest(ReportSyncEnvelope response) =>
      response.requestDigest ?? response.packageDigest;
}
