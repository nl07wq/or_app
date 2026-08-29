import 'dart:convert';

import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/app_repository_container.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/models/report_sync_history.dart';
import '../../report_sync/models/report_sync_issue.dart';
import '../../report_sync/services/report_sync_canonical_service.dart';
import '../../training/services/exercise_name_localization.dart';
import '../models/periodic_report.dart';
import 'periodic_report_fact_service.dart';

class PeriodicReportPreparation {
  const PeriodicReportPreparation({required this.facts, required this.prompt});

  final PeriodicReportFacts facts;
  final String prompt;
}

class PeriodicReportPreview {
  const PeriodicReportPreview({
    required this.response,
    required this.facts,
    required this.analysis,
    required this.current,
    required this.disposition,
  });

  final ReportSyncEnvelope response;
  final PeriodicReportFacts facts;
  final PeriodicReportAnalysis analysis;
  final PeriodicReportRecord? current;
  final ReportSyncHistoryResult disposition;
}

class PeriodicReportService {
  PeriodicReportService({
    AppRepositoryContainer? container,
    DateTime Function()? clock,
  }) : _containerOverride = container,
       _clock = clock ?? DateTime.now;

  final AppRepositoryContainer? _containerOverride;
  final DateTime Function() _clock;

  AppRepositoryContainer get _container =>
      _containerOverride ?? AppRepositoryRegistry.container;

  PeriodicReportFactService get _facts => PeriodicReportFactService(
    dailyAggregates: _container.dailyAggregates,
    training: _container.training,
    reports: _container.periodicReports,
  );

  Future<PeriodicReportPreparation> prepare({
    required PeriodicReportType type,
    required DateTime anchor,
  }) async {
    final state = await _container.operationState.requireCurrent();
    final facts = await _facts.generate(
      reportType: type,
      anchor: anchor,
      currentOperationDate: DateTime.parse(state.operationDate.value),
    );
    final sourceDigest = ReportSyncCanonicalService.digest(facts.toJson());
    final timestamp = _clock().toUtc();
    final requestId =
        'periodic-report-request:${timestamp.microsecondsSinceEpoch}-'
        '${sourceDigest.substring(0, 12)}';
    final payload = <String, Object?>{
      'operationDate': facts.endDate,
      'periodId': facts.periodId,
      'reportType': facts.reportType.stableId,
      'sourceDigest': sourceDigest,
      'facts': facts.toJson(),
    };
    final request = _container.reportSyncCodec.create(
      direction: ReportSyncDirection.request,
      exchangeType: ReportSyncExchangeType.periodicReport,
      exchangeId: requestId,
      requestId: requestId,
      operationDate: facts.endDate,
      createdAt: timestamp,
      requestDigest: ReportSyncCanonicalService.digest(payload),
      payload: payload,
    );
    await _container.reportSyncPersistence.recordRequest(request);
    return PeriodicReportPreparation(facts: facts, prompt: _prompt(request));
  }

  Future<PeriodicReportPreview> preview({
    required PeriodicReportType type,
    required DateTime anchor,
    required String rawResponse,
  }) async {
    final response = _container.reportSyncCodec.decode(rawResponse.trim());
    if (response.direction != ReportSyncDirection.response ||
        response.exchangeType != ReportSyncExchangeType.periodicReport ||
        response.schemaVersion != ReportSyncEnvelope.importSchemaVersion2) {
      throw const ReportSyncException(
        ReportSyncIssueCode.exchangeTypeMismatch,
        'PERIODIC REPORT response required.',
      );
    }
    await _container.reportSyncValidator.validateResponse(
      response,
      expectedOperationDate: response.operationDate,
    );
    final state = await _container.operationState.requireCurrent();
    final facts = await _facts.generate(
      reportType: type,
      anchor: anchor,
      currentOperationDate: DateTime.parse(state.operationDate.value),
    );
    final sourceDigest = ReportSyncCanonicalService.digest(facts.toJson());
    if (response.payload['periodId'] != facts.periodId ||
        response.payload['operationDate'] != facts.endDate ||
        response.payload['reportType'] != type.stableId ||
        response.payload['sourceDigest'] != sourceDigest ||
        response.operationDate != facts.endDate) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Periodic Report facts changed after Prompt generation.',
      );
    }
    final analysis = PeriodicReportAnalysis.fromJson(
      Map<String, Object?>.from(response.payload['analysis'] as Map),
    );
    final current = await _container.periodicReports.read(facts.periodId);
    final responseDigest = ReportSyncCanonicalService.digest(response.payload);
    return PeriodicReportPreview(
      response: response,
      facts: facts,
      analysis: analysis,
      current: current,
      disposition: current?.responseDigest == responseDigest
          ? ReportSyncHistoryResult.noChange
          : ReportSyncHistoryResult.success,
    );
  }

  Future<PeriodicReportRecord> apply(PeriodicReportPreview preview) async {
    final syncStartedAt = _clock().toUtc();
    final responseDigest = ReportSyncCanonicalService.digest(
      preview.response.payload,
    );
    final sourceDigest = preview.response.payload['sourceDigest']! as String;
    return _container.database.runTransaction(
      storeNames: const [
        IndexedDbStoreNames.periodicReportRecords,
        IndexedDbStoreNames.reportSyncHistory,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final stored = await transaction.findById(
          IndexedDbStoreNames.periodicReportRecords,
          preview.facts.periodId,
        );
        final existing = stored == null
            ? null
            : PeriodicReportRecord.fromRecord(stored);
        final noChanges = existing?.responseDigest == responseDigest;
        final report = existing == null
            ? PeriodicReportRecord.initial(
                facts: preview.facts,
                analysis: preview.analysis,
                sourceDigest: sourceDigest,
                responseDigest: responseDigest,
                exchangeId: preview.response.exchangeId,
                timestamp: syncStartedAt,
              )
            : noChanges
            ? existing
            : existing.revise(
                facts: preview.facts,
                analysis: preview.analysis,
                sourceDigest: sourceDigest,
                responseDigest: responseDigest,
                exchangeId: preview.response.exchangeId,
                timestamp: syncStartedAt,
              );
        if (!noChanges) {
          await _container.periodicReports.putInTransaction(
            transaction,
            report,
          );
        }
        final syncCompletedAt = _clock().toUtc();
        final history = ReportSyncHistory(
          exchangeId: preview.response.exchangeId,
          exchangeType: ReportSyncExchangeType.periodicReport,
          direction: ReportSyncDirection.response,
          operationDate: preview.facts.endDate,
          requestId: preview.response.requestId ?? preview.response.exchangeId,
          requestDigest:
              preview.response.requestDigest ??
              ReportSyncCanonicalService.digest(preview.response.payload),
          responseDigest: responseDigest,
          confirmationDigest: null,
          startedAt: syncStartedAt,
          completedAt: syncCompletedAt,
          result: noChanges
              ? ReportSyncHistoryResult.noChange
              : ReportSyncHistoryResult.success,
          packageDigest: preview.response.packageDigest,
        );
        if (await transaction.findById(
              IndexedDbStoreNames.reportSyncHistory,
              history.exchangeId,
            ) !=
            null) {
          throw const ReportSyncException(
            ReportSyncIssueCode.recordConflict,
            'Periodic Report exchangeId already exists.',
          );
        }
        await transaction.put(
          IndexedDbStoreNames.reportSyncHistory,
          history.toRecord(),
        );
        return report;
      },
    );
  }

  String _prompt(ReportSyncEnvelope request) {
    final payload = request.payload;
    final facts = Map<String, Object?>.from(payload['facts'] as Map);
    final exerciseLabels = periodicReportExerciseDisplayLabels(
      (facts['exercisesPerformed'] as List).whereType<String>(),
    );
    final example = {
      'format': ReportSyncEnvelope.formatId,
      'envelopeVersion': 1,
      'schemaVersion': ReportSyncEnvelope.importSchemaVersion2,
      'direction': 'response',
      'exchangeType': 'periodicReport',
      'exchangeId': '<UNIQUE_RESPONSE_ID>',
      'operationDate': request.operationDate,
      'createdAt': '<UTC_TIMESTAMP>',
      'confirmationDigest': null,
      'payload': {
        'operationDate': request.operationDate,
        'periodId': payload['periodId'],
        'reportType': payload['reportType'],
        'sourceDigest': payload['sourceDigest'],
        'analysis': PeriodicReportPayloadExample.analysis,
      },
      'packageDigest': null,
    };
    return '''
Create the Operation Reboot ${payload['reportType'].toString().toUpperCase()} PERIODIC REPORT analysis from the exact Formal Fact package below.

FACT / ANALYSIS RESPONSIBILITY
Operation Reboot owns every formal value, comparison, missing marker, calorie balance, theoretical weight change, and actual weight change. Preserve all facts exactly. Do not invent, complete, recalculate, or replace any fact. 7700 kcal/kg is already applied by Operation Reboot; do not recalculate it. Return analysis and comments only in concise natural Japanese.

HUMAN-FACING ANALYSIS PRESENTATION
These rules apply only to natural-language strings inside payload.analysis. They do not change the FORMAL FACT PACKAGE, JSON numbers, field names, digests, or stored values.
- Render decimal facts to one decimal place by rounding the second decimal place: 98.33 kg becomes 98.3 kg, 33.43% becomes 33.4%, 1,827.19 kcal becomes 1,827.2 kcal, 122.04 g becomes 122.0 g, and -983.39 kcal becomes -983.4 kcal.
- Render inherently integer facts such as steps, session counts, days, training days, and status counts as integers without an unnecessary .0 suffix.
- Add thousands separators to human-facing numbers of 1,000 or more, including negative values: 12500 becomes 12,500; 30485.0 becomes 30,485.0; -30485.0 becomes -30,485.0.
- Render duration-minute facts as H:MM with two minute digits in analysis prose: 369.9 minutes rounds to 370 minutes and becomes 6:10; 360 becomes 6:00. Keep every source and derived duration value in minutes in the FORMAL FACT PACKAGE.
- Use the supplied display-only exercise labels in Japanese analysis. Do not translate or alter a custom or unknown exercise name; use its stored human-facing name exactly.

DISPLAY-ONLY EXERCISE LABELS
${const JsonEncoder.withIndent('  ').convert(exerciseLabels)}

RESPONSE CONTRACT
Return exactly one fenced Plain Text code block using ```text. Put one JSON object inside and nothing outside it. Preserve periodId, reportType, sourceDigest, and operationDate exactly. Use schemaVersion "2.0", direction "response", exchangeType "periodicReport", packageDigest null, a unique exchangeId, and UTC createdAt. Do not add, remove, or rename fields.

COMPLETE RESPONSE SHAPE
${const JsonEncoder.withIndent('  ').convert(example)}

FORMAL FACT PACKAGE
${const JsonEncoder.withIndent('  ').convert(payload['facts'])}
'''
        .trim();
  }
}

Map<String, String> periodicReportExerciseDisplayLabels(
  Iterable<String> names,
) => {for (final name in names) name: exerciseDisplayName(name)};

abstract final class PeriodicReportPayloadExample {
  static const analysis = <String, Object?>{
    'body': '<Japanese analysis>',
    'nutrition': '<Japanese analysis>',
    'calorieBalance': '<Japanese analysis>',
    'activity': '<Japanese analysis>',
    'recovery': '<Japanese analysis>',
    'training': '<Japanese analysis>',
    'condition': '<Japanese analysis>',
    'operation': '<Japanese analysis>',
    'overallSummary': '<Japanese summary>',
    'nextPeriodFocus': '<Japanese focus>',
  };
}
