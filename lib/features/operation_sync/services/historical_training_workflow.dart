import 'dart:convert';

import '../../../core/data/default_training_templates.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/models/report_sync_issue.dart';
import '../../report_sync/services/report_sync_import_schema_v2.dart';
import '../../report_sync/services/report_sync_payload_adapters.dart';
import '../../repositories/app_repository_container.dart';
import '../../training/models/persisted_training_record.dart';
import '../../training/repository/custom_training_exercise_repository.dart';
import '../../training/repository/training_record_id_generator.dart';
import '../../training/services/exercise_name_localization.dart';
import '../../training/services/training_v2_canonical_service.dart';
import '../models/historical_import_difference.dart';
import '../models/operation_sync_history.dart';
import 'operation_transfer_canonical_service.dart';
import 'operation_transfer_id_generator.dart';

class HistoricalTrainingIssue {
  final String code;
  final String message;
  final String? path;

  const HistoricalTrainingIssue(this.code, this.message, {this.path});
}

class HistoricalTrainingPreviewItem {
  final int index;
  final String? recordId;
  final String? sourceRecordId;
  final String? operationDate;
  final String? sourceDigest;
  final String? targetRecordId;
  final String? domainDigest;
  final PersistedTrainingRecord? persistedRecord;
  final OperationSyncRecordDisposition disposition;
  final List<HistoricalImportDifference> differences;
  final List<HistoricalTrainingIssue> issues;

  const HistoricalTrainingPreviewItem({
    required this.index,
    this.recordId,
    required this.sourceRecordId,
    required this.operationDate,
    required this.sourceDigest,
    required this.targetRecordId,
    required this.domainDigest,
    required this.persistedRecord,
    required this.disposition,
    this.differences = const [],
    required this.issues,
  });

  HistoricalTrainingPreviewItem withDisposition(
    OperationSyncRecordDisposition value, {
    HistoricalTrainingIssue? issue,
  }) => HistoricalTrainingPreviewItem(
    index: index,
    recordId: recordId,
    sourceRecordId: sourceRecordId,
    operationDate: operationDate,
    sourceDigest: sourceDigest,
    targetRecordId: targetRecordId,
    domainDigest: domainDigest,
    persistedRecord: persistedRecord,
    disposition: value,
    differences: differences,
    issues: [...issues, ?issue],
  );

  HistoricalTrainingPreviewItem classified({
    required OperationSyncRecordDisposition disposition,
    required String? targetRecordId,
    required PersistedTrainingRecord persistedRecord,
    List<HistoricalImportDifference> differences = const [],
    HistoricalTrainingIssue? issue,
  }) => HistoricalTrainingPreviewItem(
    index: index,
    recordId: recordId,
    sourceRecordId: sourceRecordId,
    operationDate: operationDate,
    sourceDigest: sourceDigest,
    targetRecordId: targetRecordId,
    domainDigest: domainDigest,
    persistedRecord: persistedRecord,
    disposition: disposition,
    differences: differences,
    issues: [...issues, ?issue],
  );

  bool get isSelectable =>
      disposition == OperationSyncRecordDisposition.newRecord ||
      disposition == OperationSyncRecordDisposition.conflict;
}

class HistoricalTrainingPreview {
  final String exchangeId;
  final DateTime createdAt;
  final String responseDigest;
  final String packageDigest;
  final String requestedStartDate;
  final String requestedEndDate;
  final Map<String, Object?> envelope;
  final List<HistoricalTrainingPreviewItem> records;

  const HistoricalTrainingPreview({
    required this.exchangeId,
    required this.createdAt,
    required this.responseDigest,
    required this.packageDigest,
    required this.requestedStartDate,
    required this.requestedEndDate,
    required this.envelope,
    required this.records,
  });

  int count(OperationSyncRecordDisposition value) =>
      records.where((item) => item.disposition == value).length;

  int get receivedCount => records.length;
  int get newCount => count(OperationSyncRecordDisposition.newRecord);
  int get identicalCount => count(OperationSyncRecordDisposition.identical);
  int get conflictCount => count(OperationSyncRecordDisposition.conflict);
  int get differentCount => conflictCount;
  int get invalidCount => count(OperationSyncRecordDisposition.invalid);
  int get excludedCount => count(OperationSyncRecordDisposition.excluded);
  int get blockedCount => count(OperationSyncRecordDisposition.blocked);
  int get selectableCount => records.where((item) => item.isSelectable).length;
  bool get canApply =>
      records.isNotEmpty && selectableCount > 0 && invalidCount == 0;
  List<String> get dates => [
    for (final item in records)
      if (item.operationDate != null) item.operationDate!,
  ]..sort();
  String? get startDate => dates.isEmpty ? null : dates.first;
  String? get endDate => dates.isEmpty ? null : dates.last;
}

class HistoricalTrainingApplyResult {
  final OperationSyncRecord record;
  const HistoricalTrainingApplyResult(this.record);
}

abstract interface class HistoricalTrainingWorkflow {
  String buildPrompt({required String startDate, required String endDate});
  Future<HistoricalTrainingPreview> preview(
    String responseJson, {
    required String startDate,
    required String endDate,
  });
  Future<HistoricalTrainingApplyResult> apply(
    HistoricalTrainingPreview preview, {
    Set<int>? selectedIndexes,
  });
  Future<List<OperationSyncRecord>> listRecords();
}

class HistoricalTrainingWorkflowService implements HistoricalTrainingWorkflow {
  static const _format = 'operation-reboot-operation-sync';
  static const _schemaVersion = '1.0';
  static const _maxResponseBytes = 5 * 1024 * 1024;

  final IndexedDbDatabase database;
  final CustomTrainingExerciseRepository customExercises;
  final DateTime Function() clock;
  final TrainingRecordIdGenerator idGenerator;
  final OperationTransferIdGenerator operationIdGenerator;
  final Map<String, String> _stableTargetIds = {};

  HistoricalTrainingWorkflowService({
    required this.database,
    required this.customExercises,
    DateTime Function()? clock,
    TrainingRecordIdGenerator? idGenerator,
    OperationTransferIdGenerator? operationIdGenerator,
  }) : clock = clock ?? DateTime.now,
       idGenerator = idGenerator ?? TrainingRecordIdGenerator(),
       operationIdGenerator =
           operationIdGenerator ?? OperationTransferIdGenerator();

  factory HistoricalTrainingWorkflowService.production() {
    final container = AppRepositoryRegistry.container;
    return HistoricalTrainingWorkflowService(
      database: container.database,
      customExercises: container.customTrainingExercises,
    );
  }

  @override
  String buildPrompt({required String startDate, required String endDate}) {
    _validateRequestedRange(startDate, endDate);
    final exampleRecord = Map<String, Object?>.from(
      const TrainingReportSyncPayloadSchemaV2().minimalResponseExample,
    );
    exampleRecord['recordId'] = null;
    exampleRecord['operationDate'] = '<RECORDED_OPERATION_DATE>';
    final session = Map<String, Object?>.from(exampleRecord['session'] as Map);
    final header = Map<String, Object?>.from(session['session'] as Map);
    header['localDate'] = '<RECORDED_OPERATION_DATE>';
    session['session'] = header;
    session['cardio'] = <Object?>[
      <String, Object?>{
        'purpose': 'warmup',
        'type': 'bike',
        'durationSeconds': 300,
        'distanceKm': null,
        'mets': null,
        'averageHeartRateBpm': null,
        'maximumHeartRateBpm': null,
        'averageSpeedKmh': null,
        'estimatedCaloriesKcal': null,
        'weightSnapshotKg': null,
        'calculationMethod': null,
        'calculationVersion': null,
        'notes': null,
      },
    ];
    exampleRecord['session'] = session;
    final example = <String, Object?>{
      'format': _format,
      'envelopeVersion': 1,
      'schemaVersion': _schemaVersion,
      'direction': 'response',
      'exchangeType': 'historicalTraining',
      'exchangeId': '<UNIQUE_RESPONSE_ID>',
      'createdAt': '<UTC_TIMESTAMP>',
      'payload': {
        'recordType': 'trainingV2',
        'sourceMode': 'dateRange',
        'importMode': 'missingRecordsOnly',
        'requestedStartDate': startDate,
        'requestedEndDate': endDate,
        'records': [exampleRecord],
      },
      'packageDigest': null,
    };
    return '''
Create one Operation Reboot Historical Training response from every formal Training Record you retain in this conversation or its available context whose operationDate is from $startDate through $endDate, inclusive.

SOURCE CONTRACT
This prompt is not source data. Use only formal Training Records already retained from $startDate through $endDate, inclusive. Do not output a record before $startDate or after $endDate. Do not include STATUS, ACTIVITY, FOOD, Daily Summary, Morning Brief, Daily Debrief, or inferred records. Output every retained Training Record in the requested range exactly once. Preserve each record's date, formal recordId when known, sourceRecordId when known, and the recorded Exercise, Set, and Cardio order. Do not invent missing values, equipment, evaluation, next target, calories, weight, or snapshots. Keep null, numeric zero, and empty text distinct.

RESPONSE CONTRACT
Return exactly one fenced Plain Text code block. Its opening fence must be ```text and its closing fence must be ```.
Inside the code block return only one JSON object. Return no heading, explanation, greeting, note, marker, comment, or text outside the code block. Do not use a json fence. The copied code-block content must start with { and end with }.
Use format "$_format", envelopeVersion 1, schemaVersion "$_schemaVersion", direction "response", exchangeType "historicalTraining", recordType "trainingV2", sourceMode "dateRange", importMode "missingRecordsOnly", requestedStartDate "$startDate", and requestedEndDate "$endDate" exactly. Create a unique exchangeId and UTC createdAt. Set packageDigest to null. Do not calculate a digest or replace null with a placeholder.
Do not add unknown fields, stringify numbers, or alter dates. recordId is the formal persisted Training Record ID. When the source contains recordId, return exactly the same value without changing it. When the source does not contain recordId, return null. Never generate, infer, or reconstruct recordId. sourceRecordId is the original external reference when known, otherwise null. It is not an app storage ID. Every record must contain exactly operationDate, recordId, sourceRecordId, and session. session.localDate must equal operationDate. The nested session name is optional metadata: preserve a recorded non-empty name, otherwise return null. Never infer or generate a session name.
For each exercise, equipment must be either null when no equipment is recorded, or an object containing exactly id and a non-empty name. Never return an equipment object whose name is an empty string.
For sets preserve exactly type, weightKg, reps, rpe, and restAfterSeconds. Set type is case-sensitive and must be only "warmUp" or "main". Map a retained "warmup" label to "warmUp"; never output "warmup". reps must be a JSON integer of 1 or greater, never a decimal number or String. rpe must be null or a JSON integer from 1 through 10. restAfterSeconds must be null or a non-negative JSON integer. weightKg must be a finite non-negative JSON number. legacyUnknown is forbidden.
For cardio use only these exact field names: purpose, type, durationSeconds, distanceKm, mets, averageHeartRateBpm, maximumHeartRateBpm, averageSpeedKmh, estimatedCaloriesKcal, weightSnapshotKg, calculationMethod, calculationVersion, and notes. Cardio purpose is case-sensitive and must be only "warmUp", "main", or "cooldown"; map a retained "warmup" label to "warmUp". Cardio type is case-sensitive and must be only "walking", "running", "exerciseBike", "elliptical", "treadmillWalking", or "treadmillRunning"; map a retained "bike" label to "exerciseBike". Map a retained maxHeartRateBpm value to maximumHeartRateBpm; never output maxHeartRateBpm. Never output calories or equipment in a cardio object. durationSeconds and heart-rate values must be JSON integers, never decimal numbers or Strings. A calories snapshot is all-or-null: estimatedCaloriesKcal, weightSnapshotKg, calculationMethod "metsAcsmV1", and calculationVersion 1. If the retained record has calories alone or any incomplete snapshot, set all four formal snapshot fields to null. Do not reconstruct a partial snapshot or infer weight.

The complete response structure is below. Placeholder values describe types only and are not facts. Repeat payload.records for every retained formal Training Record.
${const JsonEncoder.withIndent('  ').convert(example)}
'''
        .trim();
  }

  @override
  Future<HistoricalTrainingPreview> preview(
    String responseJson, {
    required String startDate,
    required String endDate,
  }) async {
    _validateRequestedRange(startDate, endDate);
    final decoded = _decodeEnvelope(responseJson);
    final payload = Map<String, Object?>.from(decoded['payload'] as Map);
    if (payload['requestedStartDate'] != startDate ||
        payload['requestedEndDate'] != endDate) {
      throw const FormatException(
        'Response date range does not match the selected request.',
      );
    }
    final rawRecords = List<Object?>.from(payload['records'] as List);
    final responseDigest = OperationTransferCanonicalService.digest(decoded);
    final digestPayload = Map<String, Object?>.from(decoded)
      ..remove('packageDigest');
    final packageDigest = OperationTransferCanonicalService.digest(
      digestPayload,
    );
    final mapped = <HistoricalTrainingPreviewItem>[];
    for (var index = 0; index < rawRecords.length; index++) {
      mapped.add(
        await _mapRecord(
          rawRecords[index],
          index,
          packageDigest: packageDigest,
          requestedStartDate: startDate,
          requestedEndDate: endDate,
        ),
      );
    }
    final existingTraining = await database.findAll(
      IndexedDbStoreNames.trainingRecords,
    );
    final syncRecords = await database.findAll(
      IndexedDbStoreNames.operationSyncHistory,
    );
    return _classify(
      decoded: decoded,
      responseDigest: responseDigest,
      packageDigest: packageDigest,
      mapped: mapped,
      existingTraining: existingTraining,
      syncRecords: syncRecords,
    );
  }

  Map<String, Object?> _decodeEnvelope(String source) {
    if (utf8.encode(source).length > _maxResponseBytes) {
      throw const FormatException('Response exceeds the 5 MiB limit.');
    }
    final Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      throw const FormatException(
        'Paste the JSON object only. Markdown fences are not accepted.',
      );
    }
    if (raw is! Map) throw const FormatException('Response must be an object.');
    final value = Map<String, Object?>.from(raw);
    _exact(value, const {
      'format',
      'envelopeVersion',
      'schemaVersion',
      'direction',
      'exchangeType',
      'exchangeId',
      'createdAt',
      'payload',
      'packageDigest',
    }, r'$');
    if (value['format'] != _format ||
        value['envelopeVersion'] != 1 ||
        value['schemaVersion'] != _schemaVersion ||
        value['direction'] != 'response' ||
        value['exchangeType'] != 'historicalTraining' ||
        value['packageDigest'] != null) {
      throw const FormatException('Unsupported Historical Training envelope.');
    }
    final exchangeId = value['exchangeId'];
    final createdAt = value['createdAt'];
    if (exchangeId is! String || exchangeId.isEmpty || createdAt is! String) {
      throw const FormatException('Invalid response identity.');
    }
    final timestamp = DateTime.tryParse(createdAt);
    if (timestamp == null || !timestamp.isUtc) {
      throw const FormatException('createdAt must be a UTC timestamp.');
    }
    final rawPayload = value['payload'];
    if (rawPayload is! Map) throw const FormatException('payload is invalid.');
    final payload = Map<String, Object?>.from(rawPayload);
    _exact(payload, const {
      'recordType',
      'sourceMode',
      'importMode',
      'requestedStartDate',
      'requestedEndDate',
      'records',
    }, r'$.payload');
    if (payload['recordType'] != 'trainingV2' ||
        payload['sourceMode'] != 'dateRange' ||
        payload['importMode'] != 'missingRecordsOnly' ||
        payload['requestedStartDate'] is! String ||
        payload['requestedEndDate'] is! String ||
        payload['records'] is! List) {
      throw const FormatException('Unsupported Historical Training payload.');
    }
    return value;
  }

  Future<HistoricalTrainingPreviewItem> _mapRecord(
    Object? raw,
    int index, {
    required String packageDigest,
    required String requestedStartDate,
    required String requestedEndDate,
  }) async {
    String? recordId;
    String? sourceRecordId;
    String? operationDate;
    String? sourceDigest;
    try {
      if (raw is! Map) throw const FormatException('Record must be an object.');
      final sourceValue = Map<String, Object?>.from(raw);
      final value = _deepCopyMap(sourceValue);
      final rawRecordId = value.remove('recordId');
      if (rawRecordId != null) {
        if (rawRecordId is! String) {
          throw const FormatException(
            'Historical Training recordId must be a string or null.',
          );
        }
        PersistedTrainingRecord.validateId(rawRecordId);
        recordId = rawRecordId;
      }
      sourceRecordId = value['sourceRecordId'] as String?;
      operationDate = value['operationDate'] as String?;
      sourceDigest = OperationTransferCanonicalService.digest(sourceValue);
      _normalizeHistoricalAliases(value);
      const TrainingReportSyncPayloadSchemaV2().validateResponse(
        value,
        allowNullSessionGrade: true,
      );
      await _validateExerciseIdentities(value);
      if (operationDate!.compareTo(requestedStartDate) < 0 ||
          operationDate.compareTo(requestedEndDate) > 0) {
        throw const FormatException(
          'Training Record is outside the requested date range.',
        );
      }
      final stableKey = '$packageDigest:$index:$sourceDigest';
      final targetId =
          recordId ??
          _stableTargetIds.putIfAbsent(stableKey, idGenerator.generate);
      final envelope = ReportSyncEnvelope(
        schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.training,
        exchangeId: 'historical-$index',
        operationDate: operationDate,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        confirmationDigest: null,
        payload: value,
        packageDigest:
            '0000000000000000000000000000000000000000000000000000000000000000',
      );
      final mapped = await TrainingReportSyncPayloadAdapter(
        customExercises,
        idGenerator: _FixedTrainingRecordIdGenerator(targetId),
        allowNullSessionGrade: true,
        equipmentNamesRequiringIdentityResolution: const {'Dumbbells'},
      ).decodeForImport(envelope);
      final domainDigest = TrainingV2CanonicalService.digest(
        localDate: operationDate,
        session: mapped.decoded.session,
      );
      final now = clock().toUtc();
      final persisted = PersistedTrainingRecord.v2(
        id: targetId,
        localDate: operationDate,
        createdAt: now,
        updatedAt: now,
        data: mapped.decoded.session,
      );
      return HistoricalTrainingPreviewItem(
        index: index,
        recordId: recordId,
        sourceRecordId: sourceRecordId,
        operationDate: operationDate,
        sourceDigest: sourceDigest,
        targetRecordId: targetId,
        domainDigest: domainDigest,
        persistedRecord: persisted,
        disposition: OperationSyncRecordDisposition.newRecord,
        issues: const [],
      );
    } catch (error) {
      final validation = error is ReportSyncException
          ? error.validationError
          : null;
      return HistoricalTrainingPreviewItem(
        index: index,
        recordId: recordId,
        sourceRecordId: sourceRecordId,
        operationDate: operationDate,
        sourceDigest: sourceDigest,
        targetRecordId: null,
        domainDigest: null,
        persistedRecord: null,
        disposition: OperationSyncRecordDisposition.invalid,
        issues: [
          HistoricalTrainingIssue(
            'invalidRecord',
            error.toString(),
            path: validation?.jsonPath,
          ),
        ],
      );
    }
  }

  static void _normalizeHistoricalAliases(Map<String, Object?> record) {
    final session = Map<String, Object?>.from(record['session'] as Map);
    final header = Map<String, Object?>.from(session['session'] as Map);
    final sessionName = header['name'];
    if (sessionName is String && sessionName.trim().isEmpty) {
      header['name'] = null;
    }
    session['session'] = header;
    final exercises = <Object?>[];
    for (final raw in session['exercises'] as List) {
      final exercise = Map<String, Object?>.from(raw as Map);
      if (exercise['exerciseName'] == 'Dumbbell Shoulder Press' &&
          exercise['equipment'] == null) {
        exercise['exerciseName'] = 'Shoulder Press';
        exercise['equipment'] = <String, Object?>{
          'id': 'dumbbells',
          'name': 'Dumbbells',
        };
      } else if (exercise['exerciseName'] == 'Dumbbell Shoulder Press' &&
          exercise['equipment'] is Map) {
        final equipment = Map<String, Object?>.from(
          exercise['equipment']! as Map,
        );
        if (equipment['id'] == null && equipment['name'] == 'Dumbbells') {
          exercise['exerciseName'] = 'Shoulder Press';
        }
      } else if (exercise['exerciseName'] == 'CYBEX Linear Leg Press' &&
          exercise['equipment'] == null) {
        exercise['exerciseName'] = 'Leg Press';
        exercise['equipment'] = <String, Object?>{
          'id': 'squat_press',
          'name': 'Squat Press',
        };
      } else if ((exercise['exerciseName'] == 'CYBEX Leg Press' ||
              exercise['exerciseName'] == 'CYBEX Squat Press') &&
          exercise['equipment'] == null) {
        exercise['exerciseName'] = 'Leg Press';
        exercise['equipment'] = <String, Object?>{
          'id': 'squat_press',
          'name': 'Squat Press',
        };
      } else if (exercise['exerciseName'] ==
              'Hammer Strength Linear Leg Press' &&
          exercise['equipment'] == null) {
        exercise['exerciseName'] = 'Leg Press';
        exercise['equipment'] = <String, Object?>{
          'id': 'linear_leg_press',
          'name': 'Linear Leg Press',
        };
      }
      exercises.add(exercise);
    }
    session['exercises'] = exercises;
    record['session'] = session;
  }

  static Map<String, Object?> _deepCopyMap(Map source) => {
    for (final entry in source.entries)
      entry.key.toString(): _deepCopyValue(entry.value),
  };

  static Object? _deepCopyValue(Object? value) {
    if (value is Map) return _deepCopyMap(value);
    if (value is Iterable) {
      return [for (final item in value) _deepCopyValue(item)];
    }
    return value;
  }

  Future<void> _validateExerciseIdentities(Map<String, Object?> record) async {
    final customKeys = (await customExercises.findAll())
        .map((item) => exerciseIdentityKey(item.name))
        .toSet();
    final builtInKeys = {
      for (final template in defaultTrainingTemplates)
        for (final name in template.exercises) exerciseIdentityKey(name),
    };
    final session = Map<String, Object?>.from(record['session'] as Map);
    final unknown = <String>{};
    for (final raw in session['exercises'] as List) {
      final exercise = Map<String, Object?>.from(raw as Map);
      final name = exercise['exerciseName'] as String;
      final key = exerciseIdentityKey(name);
      if (!builtInKeys.contains(key) && !customKeys.contains(key)) {
        unknown.add(name);
      }
    }
    if (unknown.isNotEmpty) {
      throw FormatException(
        'Custom exercise is not registered: ${unknown.join(', ')}.',
      );
    }
  }

  HistoricalTrainingPreview _classify({
    required Map<String, Object?> decoded,
    required String responseDigest,
    required String packageDigest,
    required List<HistoricalTrainingPreviewItem> mapped,
    required List<Map<String, Object?>> existingTraining,
    required List<Map<String, Object?>> syncRecords,
  }) {
    final existingById = <String, PersistedTrainingRecord>{};
    final invalidExistingIds = <String>{};
    for (final raw in existingTraining) {
      try {
        final record = PersistedTrainingRecord.fromRecord(raw);
        existingById[record.id] = record;
      } catch (_) {
        final id = raw['id'];
        if (id is String) invalidExistingIds.add(id);
      }
    }
    final priorItems = <OperationSyncRecordItem>[];
    for (final raw in syncRecords) {
      if (raw['recordVersion'] == OperationSyncRecord.currentRecordVersion) {
        final record = OperationSyncRecord.fromRecord(raw);
        if (record.workflowKind == 'historicalTraining' &&
            record.recordType == 'trainingV2') {
          priorItems.addAll(record.records);
        }
      }
    }
    final sourceSeen = <String, HistoricalTrainingPreviewItem>{};
    final recordIdSeen = <String, HistoricalTrainingPreviewItem>{};
    final result = <HistoricalTrainingPreviewItem>[];
    for (final item in mapped) {
      if (item.disposition == OperationSyncRecordDisposition.invalid) {
        result.add(item);
        continue;
      }
      final incomingRecordId = item.recordId;
      if (incomingRecordId != null &&
          invalidExistingIds.contains(incomingRecordId)) {
        result.add(
          item.withDisposition(
            OperationSyncRecordDisposition.blocked,
            issue: const HistoricalTrainingIssue(
              'targetRecordInvalid',
              'The formal Training Record cannot be read safely.',
            ),
          ),
        );
        continue;
      }

      if (incomingRecordId != null &&
          recordIdSeen.containsKey(incomingRecordId)) {
        final previous = recordIdSeen[incomingRecordId]!;
        final same = _sameCanonical(
          previous.persistedRecord!,
          item.persistedRecord!,
        );
        result.add(
          item.withDisposition(
            same
                ? OperationSyncRecordDisposition.identical
                : OperationSyncRecordDisposition.blocked,
            issue: same
                ? null
                : const HistoricalTrainingIssue(
                    'duplicateRecordId',
                    'The package repeats recordId with different content.',
                  ),
          ),
        );
        continue;
      }
      if (incomingRecordId != null) {
        recordIdSeen[incomingRecordId] = item;
        final existing = existingById[incomingRecordId];
        result.add(existing == null ? item : _classifyAgainst(item, existing));
        continue;
      }

      final sourceId = item.sourceRecordId;
      if (sourceId != null && sourceSeen.containsKey(sourceId)) {
        final previous = sourceSeen[sourceId]!;
        final same = _sameCanonical(
          previous.persistedRecord!,
          item.persistedRecord!,
        );
        result.add(
          same
              ? item.classified(
                  disposition: OperationSyncRecordDisposition.identical,
                  targetRecordId: previous.targetRecordId,
                  persistedRecord: _candidateForId(
                    item,
                    previous.targetRecordId!,
                  ),
                )
              : item.withDisposition(
                  OperationSyncRecordDisposition.blocked,
                  issue: const HistoricalTrainingIssue(
                    'duplicateSourceRecordId',
                    'The package repeats sourceRecordId with different content.',
                  ),
                ),
        );
        continue;
      }
      if (sourceId != null) sourceSeen[sourceId] = item;

      final priorTargetIds = sourceId == null
          ? const <String>{}
          : priorItems
                .where((entry) => entry.sourceRecordId == sourceId)
                .map((entry) => entry.targetRecordId)
                .whereType<String>()
                .toSet();
      if (priorTargetIds.length == 1) {
        final targetId = priorTargetIds.single;
        final existing = existingById[targetId];
        if (existing == null) {
          result.add(
            item.withDisposition(
              OperationSyncRecordDisposition.blocked,
              issue: const HistoricalTrainingIssue(
                'historyBridgeTargetMissing',
                'The unique Historical identity bridge no longer has a Training Record.',
              ),
            ),
          );
        } else {
          result.add(_classifyAgainst(item, existing));
        }
        continue;
      }
      if (priorTargetIds.length > 1) {
        result.add(
          item.withDisposition(
            OperationSyncRecordDisposition.blocked,
            issue: const HistoricalTrainingIssue(
              'historyBridgeAmbiguous',
              'The sourceRecordId maps to more than one Training Record.',
            ),
          ),
        );
        continue;
      }

      final canonicalMatches = existingById.values
          .where(
            (existing) =>
                _canCompare(existing) &&
                _sameCanonical(existing, item.persistedRecord!),
          )
          .toList();
      if (canonicalMatches.isNotEmpty) {
        final existing = canonicalMatches.length == 1
            ? canonicalMatches.single
            : null;
        result.add(
          existing == null
              ? item.withDisposition(OperationSyncRecordDisposition.identical)
              : _classifyAgainst(item, existing),
        );
        continue;
      }

      final sameDateExists = existingById.values.any(
        (existing) => existing.localDate == item.operationDate,
      );
      if (sameDateExists) {
        result.add(
          item.withDisposition(
            OperationSyncRecordDisposition.blocked,
            issue: const HistoricalTrainingIssue(
              'formalIdentityUnavailable',
              'A Training Record exists on this date, but Formal Identity cannot be established.',
            ),
          ),
        );
        continue;
      }
      result.add(item);
    }
    return HistoricalTrainingPreview(
      exchangeId: decoded['exchangeId']! as String,
      createdAt: DateTime.parse(decoded['createdAt']! as String),
      responseDigest: responseDigest,
      packageDigest: packageDigest,
      requestedStartDate:
          (decoded['payload']! as Map)['requestedStartDate']! as String,
      requestedEndDate:
          (decoded['payload']! as Map)['requestedEndDate']! as String,
      envelope: Map.unmodifiable(decoded),
      records: List.unmodifiable(result),
    );
  }

  static HistoricalTrainingPreviewItem _classifyAgainst(
    HistoricalTrainingPreviewItem item,
    PersistedTrainingRecord existing,
  ) {
    if (!_canCompare(existing)) {
      return item.withDisposition(
        OperationSyncRecordDisposition.blocked,
        issue: const HistoricalTrainingIssue(
          'targetRecordVersionUnsupported',
          'The matched Training Record is not a replaceable v2 record.',
        ),
      );
    }
    if (existing.localDate != item.operationDate) {
      return item.withDisposition(
        OperationSyncRecordDisposition.blocked,
        issue: const HistoricalTrainingIssue(
          'localDateConflict',
          'Formal Identity matched, but the Training localDate is different.',
        ),
      );
    }
    final incoming = PersistedTrainingRecord.v2(
      id: existing.id,
      localDate: item.operationDate!,
      createdAt: existing.createdAt,
      updatedAt: item.persistedRecord!.updatedAt,
      data: item.persistedRecord!.dataV2,
    );
    final differences = historicalImportDifferences(
      _canonicalValue(existing),
      _canonicalValue(incoming),
    );
    if (differences.isNotEmpty && existing.migrationSource != null) {
      return item.withDisposition(
        OperationSyncRecordDisposition.blocked,
        issue: const HistoricalTrainingIssue(
          'targetRecordReadOnly',
          'The matched Training Record is read-only and cannot be replaced.',
        ),
      );
    }
    return item.classified(
      disposition: differences.isEmpty
          ? OperationSyncRecordDisposition.identical
          : OperationSyncRecordDisposition.conflict,
      targetRecordId: existing.id,
      persistedRecord: incoming,
      differences: differences,
    );
  }

  static PersistedTrainingRecord _candidateForId(
    HistoricalTrainingPreviewItem item,
    String targetId,
  ) => PersistedTrainingRecord.v2(
    id: targetId,
    localDate: item.operationDate!,
    createdAt: item.persistedRecord!.createdAt,
    updatedAt: item.persistedRecord!.updatedAt,
    data: item.persistedRecord!.dataV2,
  );

  static bool _canCompare(PersistedTrainingRecord record) =>
      record.recordVersion == PersistedTrainingRecord.version2RecordVersion;

  static Map<String, Object?> _canonicalValue(PersistedTrainingRecord record) =>
      TrainingV2CanonicalService.value(
        localDate: record.localDate,
        session: record.dataV2,
      );

  static bool _sameCanonical(
    PersistedTrainingRecord current,
    PersistedTrainingRecord incoming,
  ) =>
      _canCompare(current) &&
      _canCompare(incoming) &&
      OperationTransferCanonicalService.encode(_canonicalValue(current)) ==
          OperationTransferCanonicalService.encode(_canonicalValue(incoming));

  @override
  Future<HistoricalTrainingApplyResult> apply(
    HistoricalTrainingPreview preview, {
    Set<int>? selectedIndexes,
  }) async {
    if (!preview.canApply) {
      throw StateError('Historical Training package is blocked.');
    }
    final selected =
        selectedIndexes ??
        {
          for (final item in preview.records)
            if (item.isSelectable) item.index,
        };
    if (selected.isEmpty ||
        selected.any(
          (index) => !preview.records.any(
            (item) => item.index == index && item.isSelectable,
          ),
        )) {
      throw StateError('Historical Training selection is invalid.');
    }
    final now = clock().toUtc();
    return database.runTransaction(
      storeNames: const [
        IndexedDbStoreNames.trainingRecords,
        IndexedDbStoreNames.operationSyncHistory,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final revalidated = await _revalidate(preview, transaction);
        final appliedItems = revalidated.records
            .where((item) => selected.contains(item.index) && item.isSelectable)
            .toList();
        await _writeAndVerifyTraining(transaction, appliedItems, now);
        final auditItems = [
          for (final item in revalidated.records)
            OperationSyncRecordItem(
              sourceRecordId: item.sourceRecordId,
              operationDate: item.operationDate!,
              sourceDigest: item.sourceDigest!,
              targetRecordId:
                  (selected.contains(item.index) && item.isSelectable) ||
                      item.disposition ==
                          OperationSyncRecordDisposition.identical
                  ? item.targetRecordId
                  : null,
              disposition: !selected.contains(item.index) && item.isSelectable
                  ? OperationSyncRecordDisposition.excluded
                  : item.disposition == OperationSyncRecordDisposition.conflict
                  ? OperationSyncRecordDisposition.replaced
                  : item.disposition,
              result: OperationSyncRecordResult.success,
              errorCode: null,
            ),
        ];
        int auditCount(OperationSyncRecordDisposition disposition) =>
            auditItems.where((item) => item.disposition == disposition).length;
        final record = OperationSyncRecord(
          operationId: operationIdGenerator.generate(),
          sourceMode: 'dateRange',
          startDate: revalidated.startDate,
          endDate: revalidated.endDate,
          receivedCount: revalidated.receivedCount,
          newCount: auditCount(OperationSyncRecordDisposition.newRecord),
          identicalCount: auditCount(OperationSyncRecordDisposition.identical),
          replacedCount: auditCount(OperationSyncRecordDisposition.replaced),
          conflictCount: auditCount(OperationSyncRecordDisposition.conflict),
          invalidCount: auditCount(OperationSyncRecordDisposition.invalid),
          excludedCount: auditCount(OperationSyncRecordDisposition.excluded),
          blockedCount: auditCount(OperationSyncRecordDisposition.blocked),
          appliedCount: appliedItems.length,
          skippedCount: auditItems.length - appliedItems.length,
          exchangeId: revalidated.exchangeId,
          responseDigest: revalidated.responseDigest,
          packageDigest: revalidated.packageDigest,
          result: OperationSyncRecordResult.success,
          failureCode: null,
          createdAt: now,
          completedAt: now,
          records: auditItems,
        );
        await transaction.put(
          IndexedDbStoreNames.operationSyncHistory,
          record.toRecord(),
        );
        final storedAudit = await transaction.findById(
          IndexedDbStoreNames.operationSyncHistory,
          record.operationId,
        );
        if (storedAudit == null ||
            OperationTransferCanonicalService.encode(storedAudit) !=
                OperationTransferCanonicalService.encode(record.toRecord())) {
          throw StateError(
            'Operation Sync record read-back verification failed.',
          );
        }
        return HistoricalTrainingApplyResult(record);
      },
    );
  }

  Future<HistoricalTrainingPreview> _revalidate(
    HistoricalTrainingPreview preview,
    IndexedDbTransaction transaction,
  ) async {
    final revalidated = _classify(
      decoded: preview.envelope,
      responseDigest: preview.responseDigest,
      packageDigest: preview.packageDigest,
      mapped: preview.records,
      existingTraining: await transaction.findAll(
        IndexedDbStoreNames.trainingRecords,
      ),
      syncRecords: await transaction.findAll(
        IndexedDbStoreNames.operationSyncHistory,
      ),
    );
    if (!_samePlan(preview, revalidated) || !revalidated.canApply) {
      throw StateError('Training import preview is stale.');
    }
    return revalidated;
  }

  Future<void> _writeAndVerifyTraining(
    IndexedDbTransaction transaction,
    List<HistoricalTrainingPreviewItem> appliedItems,
    DateTime now,
  ) async {
    final expectedById = <String, PersistedTrainingRecord>{};
    for (final item in appliedItems) {
      final targetId = item.targetRecordId!;
      final PersistedTrainingRecord expected;
      if (item.disposition == OperationSyncRecordDisposition.conflict) {
        final currentValue = await transaction.findById(
          IndexedDbStoreNames.trainingRecords,
          targetId,
        );
        if (currentValue == null) {
          throw StateError('Training replace target is missing.');
        }
        final current = PersistedTrainingRecord.fromRecord(currentValue);
        if (!_canCompare(current) ||
            current.migrationSource != null ||
            current.id != targetId ||
            current.localDate != item.operationDate) {
          throw StateError('Training replace target is not safe.');
        }
        expected = PersistedTrainingRecord.v2(
          id: current.id,
          localDate: current.localDate,
          createdAt: current.createdAt,
          updatedAt: now,
          data: item.persistedRecord!.dataV2,
        );
      } else {
        expected = item.persistedRecord!;
      }
      await transaction.put(
        IndexedDbStoreNames.trainingRecords,
        expected.toRecord(),
      );
      expectedById[targetId] = expected;
    }
    for (final item in appliedItems) {
      final stored = await transaction.findById(
        IndexedDbStoreNames.trainingRecords,
        item.targetRecordId!,
      );
      final expected = expectedById[item.targetRecordId!]!;
      if (stored == null) {
        throw StateError('Training read-back verification failed.');
      }
      final readBack = PersistedTrainingRecord.fromRecord(stored);
      if (readBack.id != expected.id ||
          readBack.createdAt != expected.createdAt ||
          readBack.updatedAt != expected.updatedAt ||
          !_sameCanonical(readBack, expected)) {
        throw StateError('Training read-back verification failed.');
      }
    }
  }

  @override
  Future<List<OperationSyncRecord>> listRecords() async {
    final records = <OperationSyncRecord>[];
    for (final raw in await database.findAll(
      IndexedDbStoreNames.operationSyncHistory,
    )) {
      if (raw['recordVersion'] != OperationSyncRecord.currentRecordVersion) {
        continue;
      }
      final record = OperationSyncRecord.fromRecord(raw);
      if (record.workflowKind == 'historicalTraining') records.add(record);
    }
    records.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return List.unmodifiable(records);
  }

  static bool _samePlan(
    HistoricalTrainingPreview first,
    HistoricalTrainingPreview second,
  ) =>
      first.packageDigest == second.packageDigest &&
      first.requestedStartDate == second.requestedStartDate &&
      first.requestedEndDate == second.requestedEndDate &&
      first.records.length == second.records.length &&
      List.generate(first.records.length, (index) {
        final a = first.records[index];
        final b = second.records[index];
        return a.sourceDigest == b.sourceDigest &&
            a.targetRecordId == b.targetRecordId &&
            a.disposition == b.disposition;
      }).every((value) => value);

  static void _exact(
    Map<String, Object?> value,
    Set<String> fields,
    String path,
  ) {
    final actual = value.keys.toSet();
    if (actual.difference(fields).isNotEmpty ||
        fields.difference(actual).isNotEmpty) {
      throw FormatException('$path contains unknown or missing fields.');
    }
  }

  static void _validateRequestedRange(String startDate, String endDate) {
    final pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    final start = DateTime.tryParse('${startDate}T00:00:00Z');
    final end = DateTime.tryParse('${endDate}T00:00:00Z');
    if (!pattern.hasMatch(startDate) ||
        !pattern.hasMatch(endDate) ||
        start == null ||
        end == null ||
        end.isBefore(start)) {
      throw const FormatException('Invalid requested date range.');
    }
  }
}

class _FixedTrainingRecordIdGenerator extends TrainingRecordIdGenerator {
  final String value;
  _FixedTrainingRecordIdGenerator(this.value);

  @override
  String generate() => value;
}
