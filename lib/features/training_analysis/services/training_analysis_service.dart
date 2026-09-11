import 'dart:convert';

import '../../../core/models/training_exercise.dart';
import '../../../core/models/training_exercise_v2.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../repositories/app_repository_container.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/models/report_sync_history.dart';
import '../../report_sync/models/report_sync_issue.dart';
import '../../report_sync/services/report_sync_canonical_service.dart';
import '../../training/models/training_record_read_model.dart';
import '../../training/services/training_exercise_identity.dart';
import '../../training/services/training_volume_formatter.dart';
import '../models/training_analysis_report.dart';
import 'training_analysis_metrics_adapter.dart';
import 'training_frequency_recommendation_service.dart';

class TrainingAnalysisPreparation {
  const TrainingAnalysisPreparation({
    required this.target,
    required this.sourceDigest,
    required this.prompt,
  });

  final TrainingRecordReadModel target;
  final String sourceDigest;
  final String prompt;
}

class TrainingAnalysisPreview {
  const TrainingAnalysisPreview({
    required this.response,
    required this.analysis,
    required this.disposition,
    required this.current,
  });

  final ReportSyncEnvelope response;
  final TrainingAnalysis analysis;
  final ReportSyncHistoryResult disposition;
  final TrainingAnalysisReport? current;
}

class TrainingAnalysisImportResult {
  const TrainingAnalysisImportResult({
    required this.report,
    required this.result,
  });

  final TrainingAnalysisReport report;
  final ReportSyncHistoryResult result;
}

class TrainingAnalysisService {
  TrainingAnalysisService({
    AppRepositoryContainer? container,
    DateTime Function()? clock,
  }) : _containerOverride = container,
       _clock = clock ?? DateTime.now;

  final AppRepositoryContainer? _containerOverride;
  final DateTime Function() _clock;

  AppRepositoryContainer get _container =>
      _containerOverride ?? AppRepositoryRegistry.container;

  Future<TrainingAnalysisPreparation> prepare(String targetRecordId) async {
    final package = await _factPackage(targetRecordId);
    final operationDate = package['operationDate']! as String;
    final sourceDigest = ReportSyncCanonicalService.digest(package);
    final timestamp = _clock().toUtc();
    final suffix =
        '${timestamp.microsecondsSinceEpoch}-${sourceDigest.substring(0, 12)}';
    final requestId = 'training-analysis-request:$suffix';
    final payload = <String, Object?>{
      'operationDate': operationDate,
      'targetRecordId': targetRecordId,
      'sourceDigest': sourceDigest,
      'facts': package,
    };
    final requestDigest = ReportSyncCanonicalService.digest(payload);
    final request = _container.reportSyncCodec.create(
      direction: ReportSyncDirection.request,
      exchangeType: ReportSyncExchangeType.trainingAnalysis,
      exchangeId: requestId,
      requestId: requestId,
      operationDate: operationDate,
      createdAt: timestamp,
      requestDigest: requestDigest,
      payload: payload,
    );
    await _container.reportSyncPersistence.recordRequest(request);
    return TrainingAnalysisPreparation(
      target: (await _requireTarget(targetRecordId)),
      sourceDigest: sourceDigest,
      prompt: _prompt(request, sourceDigest),
    );
  }

  /// The single freshness boundary for import validation, report display, and
  /// downstream consumers such as Training Plan generation.
  Future<String> sourceDigestFor(String targetRecordId) async =>
      ReportSyncCanonicalService.digest(await _factPackage(targetRecordId));

  Future<bool> isCurrent(TrainingAnalysisReport report) async =>
      report.sourceDigest == await sourceDigestFor(report.targetRecordId);

  Future<TrainingAnalysisPreview> preview(
    String targetRecordId,
    String rawResponse,
  ) async {
    final response = _container.reportSyncCodec.decode(rawResponse.trim());
    if (response.direction != ReportSyncDirection.response ||
        response.exchangeType != ReportSyncExchangeType.trainingAnalysis ||
        response.schemaVersion != ReportSyncEnvelope.importSchemaVersion2) {
      throw const ReportSyncException(
        ReportSyncIssueCode.exchangeTypeMismatch,
        'TRAINING ANALYSIS response required.',
      );
    }
    await _container.reportSyncValidator.validateResponse(
      response,
      expectedOperationDate: response.operationDate,
    );
    final payload = response.payload;
    if (payload['targetRecordId'] != targetRecordId) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Target Training Record ID does not match.',
      );
    }
    final target = await _requireTarget(targetRecordId);
    if (target.localDate != response.operationDate) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Target Training operationDate does not match.',
      );
    }
    final currentDigest = await sourceDigestFor(targetRecordId);
    if (payload['sourceDigest'] != currentDigest) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Training facts changed after Prompt generation.',
      );
    }
    final analysis = TrainingAnalysis.fromJson(
      Map<String, Object?>.from(payload['analysis'] as Map),
    );
    _validateExerciseAnalyses(target, analysis);
    final current = await _container.trainingAnalysisReports.read(
      targetRecordId,
    );
    final responseDigest = ReportSyncCanonicalService.digest(response.payload);
    return TrainingAnalysisPreview(
      response: response,
      analysis: analysis,
      disposition: current != null && current.responseDigest == responseDigest
          ? ReportSyncHistoryResult.noChange
          : ReportSyncHistoryResult.success,
      current: current,
    );
  }

  Future<TrainingAnalysisImportResult> apply(
    TrainingAnalysisPreview preview,
  ) async {
    final response = preview.response;
    final targetId = response.payload['targetRecordId']! as String;
    final sourceDigest = response.payload['sourceDigest']! as String;
    final responseDigest = ReportSyncCanonicalService.digest(response.payload);
    final now = _clock().toUtc();
    return _container.database.runTransaction(
      storeNames: const [
        IndexedDbStoreNames.trainingAnalysisReportRecords,
        IndexedDbStoreNames.reportSyncHistory,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final existingValue = await transaction.findById(
          IndexedDbStoreNames.trainingAnalysisReportRecords,
          targetId,
        );
        final existing = existingValue == null
            ? null
            : TrainingAnalysisReport.fromRecord(existingValue);
        final noChanges = existing?.responseDigest == responseDigest;
        final report = existing == null
            ? TrainingAnalysisReport.initial(
                targetRecordId: targetId,
                operationDate: response.operationDate,
                sourceDigest: sourceDigest,
                responseDigest: responseDigest,
                exchangeId: response.exchangeId,
                timestamp: now,
                analysis: preview.analysis,
              )
            : noChanges
            ? existing
            : existing.revise(
                sourceDigest: sourceDigest,
                responseDigest: responseDigest,
                exchangeId: response.exchangeId,
                timestamp: now,
                analysis: preview.analysis,
              );
        final history = ReportSyncHistory(
          exchangeId: response.exchangeId,
          exchangeType: ReportSyncExchangeType.trainingAnalysis,
          direction: ReportSyncDirection.response,
          operationDate: response.operationDate,
          requestId: response.requestId ?? response.exchangeId,
          requestDigest:
              response.requestDigest ??
              ReportSyncCanonicalService.digest(response.payload),
          responseDigest: responseDigest,
          confirmationDigest: null,
          startedAt: response.createdAt,
          completedAt: now,
          result: noChanges
              ? ReportSyncHistoryResult.noChange
              : ReportSyncHistoryResult.success,
          packageDigest: response.packageDigest,
        );
        final existingHistory = await transaction.findById(
          IndexedDbStoreNames.reportSyncHistory,
          history.exchangeId,
        );
        if (existingHistory != null) {
          throw const ReportSyncException(
            ReportSyncIssueCode.recordConflict,
            'Training Analysis exchangeId already exists.',
          );
        }
        if (!noChanges) {
          await _container.trainingAnalysisReports.putInTransaction(
            transaction,
            report,
          );
        }
        await transaction.put(
          IndexedDbStoreNames.reportSyncHistory,
          history.toRecord(),
        );
        final savedHistory = await transaction.findById(
          IndexedDbStoreNames.reportSyncHistory,
          history.exchangeId,
        );
        if (savedHistory == null ||
            ReportSyncCanonicalService.encode(savedHistory) !=
                ReportSyncCanonicalService.encode(history.toRecord())) {
          throw const ReportSyncException(
            ReportSyncIssueCode.integrityFailure,
            'Training Analysis history read-back failed.',
          );
        }
        return TrainingAnalysisImportResult(
          report: report,
          result: history.result,
        );
      },
    );
  }

  Future<Map<String, Object?>> _factPackage(String targetRecordId) async {
    final target = await _requireTarget(targetRecordId);
    final records = await _container.training.findAllRecords();
    final currentExercises = _exerciseFacts(target);
    final metrics = const TrainingAnalysisMetricsAdapter().build(
      target: target,
      records: records,
    );
    final frequencyRecommendations =
        const TrainingFrequencyRecommendationService().build(
          target: target,
          records: records,
          now: _clock(),
        );
    return {
      'operationDate': target.localDate,
      'targetRecordId': target.id,
      'recordVersion': target.recordVersion,
      'training': _recordFact(target),
      'comparisons': [
        for (final current in currentExercises)
          {
            'exerciseIdentity': current.identity,
            'exerciseName': current.name,
            'current': current.fact,
            'metrics': _metricsFor(metrics, current.identity),
            'previous': _comparableFacts(records, target, current),
          },
      ],
      'frequencyRecommendations': [
        for (final recommendation in frequencyRecommendations)
          _frequencyRecommendationFact(recommendation),
      ],
    };
  }

  Map<String, Object?> _frequencyRecommendationFact(
    TrainingFrequencyRecommendation recommendation,
  ) => {
    'exerciseIdentity':
        '${recommendation.targetIdentity.exerciseKey}|${recommendation.targetIdentity.equipmentKey}',
    'targetMuscles': [
      for (final muscle in recommendation.targetMuscles) muscle.name,
    ],
    'recoveryReferenceHours': recommendation.recoveryReferenceHours,
    'recommendedMinHours': recommendation.recommendedMinHours,
    'recommendedMaxHours': recommendation.recommendedMaxHours,
    'observedMinHours': recommendation.observedMinHours,
    'observedMaxHours': recommendation.observedMaxHours,
    'validObservationCount': recommendation.validObservationCount,
    'supportedObservationCount': recommendation.supportedObservationCount,
    'longGapObservationCount': recommendation.longGapObservationCount,
    'confidence': recommendation.confidence.name,
    'status': recommendation.status.name,
    'latestObservedIntervalHours': recommendation.latestObservedIntervalHours,
  };

  Map<String, Object?> _metricsFor(
    TrainingAnalysisMetrics metrics,
    String identity,
  ) {
    final exercise = metrics.exercises.firstWhere(
      (value) =>
          '${value.identity.exerciseKey}|${value.identity.equipmentKey}' ==
          identity,
    );
    return {
      'current': _metricValues(exercise.current),
      'previous': exercise.previous == null
          ? null
          : _metricValues(exercise.previous!),
      'recentHistoryOperationDates': [
        for (final value in exercise.recentHistory) value.operationDate,
      ],
    };
  }

  Map<String, Object?> _metricValues(
    TrainingAnalysisExerciseMetricValues values,
  ) => {
    'maxWeightKg': values.maxWeight,
    'totalReps': values.totalReps,
    'recordedSetCount': values.recordedSetCount,
    'recordedVolumeKg': values.recordedVolume,
    'recordedVolumeDisplay': values.recordedVolume == null
        ? null
        : TrainingVolumeFormatter.format(values.recordedVolume!),
    'workingVolumeKg': values.workingVolume,
    'workingVolumeDisplay': values.workingVolume == null
        ? null
        : TrainingVolumeFormatter.format(values.workingVolume!),
    'averageRpe': values.averageRpe,
  };

  Future<TrainingRecordReadModel> _requireTarget(String id) async {
    final target = await _container.training.findRecordById(id);
    if (target == null) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Target Training Record does not exist.',
      );
    }
    return target;
  }

  Map<String, Object?> _recordFact(TrainingRecordReadModel record) => {
    'recordId': record.id,
    'recordVersion': record.recordVersion,
    'operationDate': record.localDate,
    'createdAt': record.createdAt.toUtc().toIso8601String(),
    'updatedAt': record.updatedAt.toUtc().toIso8601String(),
    'session': record.v2Data?.toJson() ?? record.v1Data!.toJson(),
  };

  List<Map<String, Object?>> _comparableFacts(
    List<TrainingRecordReadModel> records,
    TrainingRecordReadModel target,
    _ExerciseFact current,
  ) {
    final results = <Map<String, Object?>>[];
    for (final record in records) {
      if (record.id == target.id ||
          !record.sortDateTime.isBefore(target.sortDateTime)) {
        continue;
      }
      for (final exercise in _exerciseFacts(record)) {
        if (exercise.identity != current.identity) continue;
        results.add({
          'recordId': record.id,
          'operationDate': record.localDate,
          'fact': exercise.fact,
        });
        break;
      }
      if (results.length == 5) break;
    }
    return results;
  }

  List<_ExerciseFact> _exerciseFacts(TrainingRecordReadModel record) {
    if (record.v2Data != null) {
      return [
        for (final exercise in record.v2Data!.exercises)
          _ExerciseFact.v2(exercise),
      ];
    }
    return [
      for (final exercise in record.v1Data!.exercises)
        _ExerciseFact.v1(exercise),
    ];
  }

  void _validateExerciseAnalyses(
    TrainingRecordReadModel target,
    TrainingAnalysis analysis,
  ) {
    final expected = {
      for (final exercise in _exerciseFacts(target))
        exercise.identity: exercise.name,
    };
    final actual = <String, String>{};
    for (final value in analysis.exerciseAnalyses) {
      if (actual.putIfAbsent(
            value.exerciseIdentity,
            () => value.exerciseName,
          ) !=
          value.exerciseName) {
        throw const ReportSyncException(
          ReportSyncIssueCode.schemaMismatch,
          'Exercise Analysis identity is duplicated.',
        );
      }
    }
    if (actual.length != expected.length ||
        actual.entries.any((entry) => expected[entry.key] != entry.value)) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Exercise Analysis does not match the Formal Training Record.',
      );
    }
  }

  String _prompt(ReportSyncEnvelope request, String sourceDigest) {
    final operationDate = request.operationDate;
    final targetRecordId = request.payload['targetRecordId'];
    final example = {
      'format': ReportSyncEnvelope.formatId,
      'envelopeVersion': 1,
      'schemaVersion': ReportSyncEnvelope.importSchemaVersion2,
      'direction': ReportSyncDirection.response.stableId,
      'exchangeType': ReportSyncExchangeType.trainingAnalysis.stableId,
      'exchangeId': '<UNIQUE_RESPONSE_ID>',
      'operationDate': operationDate,
      'createdAt': '<UTC_TIMESTAMP>',
      'confirmationDigest': null,
      'payload': {
        'operationDate': operationDate,
        'targetRecordId': targetRecordId,
        'sourceDigest': sourceDigest,
        'analysis': const {
          'sessionSummary': '<Japanese analysis>',
          'performanceAnalysis': '<Japanese analysis>',
          'previousComparison': '<Japanese analysis>',
          'progressAnalysis': '<Japanese analysis>',
          'recoveryFrequencyComment': '<Japanese analysis>',
          'nextSessionProposal': '<Japanese proposal>',
          'riskAttentionNotes': '<Japanese notes>',
          'exerciseAnalyses': [
            {
              'exerciseIdentity': '<exact source identity>',
              'exerciseName': '<exact source name>',
              'assessment': '<Japanese analysis>',
              'previousComparison': '<Japanese analysis>',
              'progress': '<Japanese analysis>',
              'nextProposal': '<Japanese proposal>',
            },
          ],
        },
      },
      'packageDigest': null,
    };
    return '''
Create the Operation Reboot TRAINING ANALYSIS REPORT for the exact Formal Training Fact package below.

FACT / ANALYSIS RESPONSIBILITY
Operation Reboot owns every Training fact and numeric comparison. Preserve all facts exactly. Do not invent, complete, modify, recalculate, or replace Training records, exercises, sets, weight, reps, cardio, dates, duration, grade, evaluation, memo, calories, or comparison values. Return analysis and proposals only. Use the supplied previous records only; do not infer missing history.

RESPONSE CONTRACT
Return exactly one fenced Plain Text code block using ```text. Put one JSON object inside and nothing outside it. Use schemaVersion "2.0", direction "response", exchangeType "trainingAnalysis", operationDate "$operationDate", targetRecordId "$targetRecordId", and sourceDigest "$sourceDigest" exactly. Set packageDigest to null. Create a unique exchangeId and UTC createdAt. Do not add, remove, or rename fields. Use concise natural Japanese. Return exactly one exerciseAnalyses entry for every current exercise, preserving each exerciseIdentity and exerciseName exactly.

JAPANESE LOAD TERMINOLOGY
Use "負荷量" for Volume, "総負荷量" for Recorded Volume, and "メインセット負荷量" for Working Volume or Main Set Volume. Never use "ボリューム", "記録ボリューム", or "ワーキングボリューム" in analysis prose. When a supplied metric has a *Display value, reproduce that formatter value verbatim in prose; do not restate its raw *Kg value. Missing metrics remain unavailable and must not be written as zero.

FREQUENCY RECOMMENDATION RESPONSIBILITY
frequencyRecommendations is a current, app-derived structured result. Do not choose, widen, narrow, or override its recommended range. Explain its supplied baseline, observation count, confidence, and status only. It is a recommendation supported by current Formal History, never a scientifically proven "optimal" frequency. When status is unavailable or baselineOnly, state the supplied limitation concisely rather than inventing a personalized range.

COMPLETE RESPONSE SHAPE
${const JsonEncoder.withIndent('  ').convert(example)}

FORMAL FACT PACKAGE
${const JsonEncoder.withIndent('  ').convert(request.payload['facts'])}
'''
        .trim();
  }
}

class _ExerciseFact {
  const _ExerciseFact({
    required this.identity,
    required this.name,
    required this.fact,
  });

  factory _ExerciseFact.v2(TrainingExerciseV2 exercise) {
    return _ExerciseFact(
      identity: _identity(TrainingExerciseIdentity.v2(exercise)),
      name: exercise.exerciseName,
      fact: exercise.toJson(),
    );
  }

  factory _ExerciseFact.v1(TrainingExercise exercise) {
    return _ExerciseFact(
      identity: _identity(TrainingExerciseIdentity.v1(exercise)),
      name: exercise.exerciseName,
      fact: exercise.toJson(),
    );
  }

  final String identity;
  final String name;
  final Map<String, Object?> fact;

  static String _identity(TrainingExerciseIdentity value) =>
      '${value.exerciseKey}|${value.equipmentKey}';
}
