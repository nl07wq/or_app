import 'dart:convert';

import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../../core/models/morning_data.dart';
import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../../daily_aggregate/repository/daily_aggregate_repository.dart';
import '../../repositories/app_repository_container.dart';
import '../models/historical_import_difference.dart';
import '../models/operation_sync_history.dart';
import 'operation_transfer_canonical_service.dart';
import 'operation_transfer_id_generator.dart';

class HistoricalDnsIssue {
  final String code;
  final String message;
  final String? path;

  const HistoricalDnsIssue(this.code, this.message, {this.path});
}

class HistoricalDnsPreviewItem {
  final int index;
  final String? operationDate;
  final String? sourceDigest;
  final DailyAggregateV1? aggregate;
  final DailyAggregateV1? existingAggregate;
  final OperationSyncRecordDisposition disposition;
  final List<HistoricalImportDifference> differences;
  final List<HistoricalDnsIssue> issues;

  const HistoricalDnsPreviewItem({
    required this.index,
    required this.operationDate,
    required this.sourceDigest,
    required this.aggregate,
    this.existingAggregate,
    required this.disposition,
    this.differences = const [],
    required this.issues,
  });

  HistoricalDnsPreviewItem withDisposition(
    OperationSyncRecordDisposition value, {
    HistoricalDnsIssue? issue,
  }) => HistoricalDnsPreviewItem(
    index: index,
    operationDate: operationDate,
    sourceDigest: sourceDigest,
    aggregate: aggregate,
    existingAggregate: existingAggregate,
    disposition: value,
    differences: differences,
    issues: [...issues, ?issue],
  );

  HistoricalDnsPreviewItem classified({
    required OperationSyncRecordDisposition disposition,
    DailyAggregateV1? existingAggregate,
    List<HistoricalImportDifference> differences = const [],
    HistoricalDnsIssue? issue,
  }) => HistoricalDnsPreviewItem(
    index: index,
    operationDate: operationDate,
    sourceDigest: sourceDigest,
    aggregate: aggregate,
    existingAggregate: existingAggregate,
    disposition: disposition,
    differences: differences,
    issues: [...issues, ?issue],
  );

  bool get isSelectable =>
      disposition == OperationSyncRecordDisposition.newRecord ||
      disposition == OperationSyncRecordDisposition.conflict;
}

class HistoricalDnsPreview {
  final String exchangeId;
  final DateTime createdAt;
  final String responseDigest;
  final String packageDigest;
  final String requestedStartDate;
  final String requestedEndDate;
  final Map<String, Object?> envelope;
  final List<HistoricalDnsPreviewItem> records;

  const HistoricalDnsPreview({
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
  int get invalidCount => count(OperationSyncRecordDisposition.invalid);
  int get excludedCount => count(OperationSyncRecordDisposition.excluded);
  int get blockedCount => count(OperationSyncRecordDisposition.blocked);
  int get differentCount => conflictCount;
  int get selectableCount => records.where((item) => item.isSelectable).length;
  bool get canApply =>
      records.isNotEmpty &&
      selectableCount > 0 &&
      invalidCount == 0 &&
      !records.any(
        (item) =>
            item.issues.any((issue) => issue.code == 'duplicateOperationDate'),
      );
  List<String> get dates => [
    for (final item in records)
      if (item.operationDate != null) item.operationDate!,
  ]..sort();
  String? get startDate => dates.isEmpty ? null : dates.first;
  String? get endDate => dates.isEmpty ? null : dates.last;
}

class HistoricalDnsApplyResult {
  final OperationSyncRecord record;

  const HistoricalDnsApplyResult(this.record);
}

abstract interface class HistoricalDnsWorkflow {
  String buildPrompt({required String startDate, required String endDate});

  Future<HistoricalDnsPreview> preview(
    String responseJson, {
    required String startDate,
    required String endDate,
  });

  Future<HistoricalDnsApplyResult> apply(
    HistoricalDnsPreview preview, {
    Set<int>? selectedIndexes,
  });

  Future<List<OperationSyncRecord>> listRecords();
}

class HistoricalDnsWorkflowService implements HistoricalDnsWorkflow {
  static const _format = 'operation-reboot-operation-sync';
  static const _schemaVersion = '1.0';
  static const _exchangeType = 'historicalDns';
  static const _recordType = 'dailyAggregateV1';
  static const _maxResponseBytes = 5 * 1024 * 1024;
  static const _recordFields = {
    'operationDate',
    'weightKg',
    'bodyFatPercent',
    'sleepDurationMinutes',
    'sleepScore',
    'sleepType',
    'plantarFasciitisLevel',
    'workStartTime',
    'workEndTime',
    'workBreakMinutes',
    'actualWorkMinutes',
    'intakeCaloriesKcal',
    'estimatedExpenditureKcal',
    'estimatedCalorieBalanceKcal',
    'proteinG',
    'fatG',
    'carbsG',
    'hydrationMl',
    'officialSteps',
    'measuredSteps',
    'trainingPerformed',
    'digestiveCount',
    'digestiveEvents',
    'operationStatus',
    'conditionFactSummary',
    'sourceType',
  };

  final IndexedDbDatabase database;
  final DailyAggregateRepository repository;
  final DateTime Function() clock;
  final OperationTransferIdGenerator operationIdGenerator;

  HistoricalDnsWorkflowService({
    required this.database,
    required this.repository,
    DateTime Function()? clock,
    OperationTransferIdGenerator? operationIdGenerator,
  }) : clock = clock ?? DateTime.now,
       operationIdGenerator =
           operationIdGenerator ?? OperationTransferIdGenerator();

  factory HistoricalDnsWorkflowService.production() {
    final container = AppRepositoryRegistry.container;
    return HistoricalDnsWorkflowService(
      database: container.database,
      repository: container.dailyAggregates,
    );
  }

  @override
  String buildPrompt({required String startDate, required String endDate}) {
    _validateRequestedRange(startDate, endDate);
    final exampleRecord = const DailyAggregateV1(
      operationDate: '2026-08-08',
      weightKg: 95.6,
      bodyFatPercent: 32.5,
      sleepDurationMinutes: 141,
      sleepScore: null,
      sleepType: SleepType.nap,
      plantarFasciitisLevel: 3,
      workStartTime: '10:00',
      workEndTime: '18:00',
      workBreakMinutes: 60,
      actualWorkMinutes: 420,
      intakeCaloriesKcal: 1479,
      estimatedExpenditureKcal: 2650,
      estimatedCalorieBalanceKcal: -1150,
      proteinG: 99.3,
      fatG: 57.9,
      carbsG: 149.1,
      hydrationMl: 3600,
      officialSteps: 6970,
      measuredSteps: 7512,
      trainingPerformed: false,
      digestiveCount: 2,
      digestiveEvents: [
        DailyAggregateDigestiveEventV1(amount: 3, shape: 2, relief: null),
        DailyAggregateDigestiveEventV1(amount: 2, shape: 3, relief: null),
      ],
      operationStatus: 'RED',
      conditionFactSummary: [
        '睡眠2時間21分',
        '正式歩数6,970歩',
        '水分3,600mL',
        'トレーニングなし',
        '排便2回',
        '夕食は帰宅後就寝により欠食',
      ],
      sourceType: DailyAggregateSourceType.legacyDns,
    ).toJson();
    final example = <String, Object?>{
      'format': _format,
      'envelopeVersion': 1,
      'schemaVersion': _schemaVersion,
      'direction': 'response',
      'exchangeType': _exchangeType,
      'exchangeId': '<UNIQUE_RESPONSE_ID>',
      'createdAt': '<UTC_TIMESTAMP>',
      'payload': {
        'recordType': _recordType,
        'sourceMode': 'dateRange',
        'importMode': 'missingRecordsOnly',
        'requestedStartDate': startDate,
        'requestedEndDate': endDate,
        'records': [exampleRecord],
      },
      'packageDigest': null,
    };
    return '''
Create one Operation Reboot Historical DNS response from every formal Legacy DNS record you retain whose operationDate is from $startDate through $endDate, inclusive.

SOURCE CONTRACT
This prompt is not source data. Use only formal Legacy DNS records already retained in the requested range. Do not use STATUS, FOOD, ACTIVITY, TRAINING, Morning Brief, Daily Debrief, or inferred records. Do not output dates outside the requested range or duplicate a date. Do not invent, estimate, reconstruct, round, or complete missing values. Keep null, numeric zero, and false distinct. A numeric value explicitly recorded with an approximate label remains that recorded number; do not recalculate it.

For estimated expenditure and estimated calorie balance only, if the formal Legacy DNS records the value as a numeric range, convert that range to its arithmetic midpoint and output the midpoint as one JSON number. For example, 2500 through 2800 becomes 2650, and -1000 through -1300 becomes -1150. This midpoint conversion is the only permitted transformation of source data. Do not recalculate either value from intake calories, activity, steps, work, training, or any other field. Preserve the sign of calorie balance: a deficit is negative and a surplus is positive.

RESPONSE CONTRACT
Return exactly one fenced Plain Text code block whose opening fence is ```text and closing fence is ```.
Inside it return only one JSON object and no explanation. Use format "$_format", envelopeVersion 1, schemaVersion "$_schemaVersion", direction "response", exchangeType "$_exchangeType", recordType "$_recordType", sourceMode "dateRange", importMode "missingRecordsOnly", requestedStartDate "$startDate", and requestedEndDate "$endDate" exactly. Create a unique exchangeId and UTC createdAt. Set packageDigest to null.

Each payload.records item may contain only the fields shown in the example. Set sourceType to "legacyDns". Preserve operationDate. Use JSON numbers and booleans, not numeric or boolean Strings. sleepType is only "sleep", "nap", or null. operationStatus is only "GREEN", "YELLOW", "RED", or null. Use null for an unrecorded nullable value; never replace it with 0, false, or empty text. If a formal Legacy DNS does not contain a nullable fact, output null for that field. Do not drop the entire daily record because a fact is unavailable.

Preserve every formally recorded digestive event in digestiveEvents using only amount, shape, and relief. Preserve null when shape or relief was not recorded; do not infer it. Preserve the formal Condition fact summary lines in conditionFactSummary without summarizing, rewording, or splitting them again. Omit every line that contains CI information. Do not add any CI field or CI-derived value. Output only total hydrationMl; do not add hydration breakdown or beverage details. Do not add record status.

The structure below is a type example, not source data. Repeat payload.records for each formal DNS record in the selected range.
${const JsonEncoder.withIndent('  ').convert(example)}
'''
        .trim();
  }

  @override
  Future<HistoricalDnsPreview> preview(
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
    final mapped = <HistoricalDnsPreviewItem>[];
    for (var index = 0; index < rawRecords.length; index++) {
      mapped.add(
        _mapRecord(
          rawRecords[index],
          index,
          requestedStartDate: startDate,
          requestedEndDate: endDate,
        ),
      );
    }
    return _classify(
      decoded: decoded,
      responseDigest: responseDigest,
      packageDigest: packageDigest,
      mapped: mapped,
      existing: await database.findAll(
        IndexedDbStoreNames.dailyAggregateRecords,
      ),
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
        value['exchangeType'] != _exchangeType ||
        value['packageDigest'] != null) {
      throw const FormatException('Unsupported Historical DNS envelope.');
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
    if (payload['recordType'] != _recordType ||
        payload['sourceMode'] != 'dateRange' ||
        payload['importMode'] != 'missingRecordsOnly' ||
        payload['requestedStartDate'] is! String ||
        payload['requestedEndDate'] is! String ||
        payload['records'] is! List) {
      throw const FormatException('Unsupported Historical DNS payload.');
    }
    return value;
  }

  HistoricalDnsPreviewItem _mapRecord(
    Object? raw,
    int index, {
    required String requestedStartDate,
    required String requestedEndDate,
  }) {
    String? operationDate;
    String? sourceDigest;
    try {
      if (raw is! Map) throw const FormatException('Record must be an object.');
      final value = Map<String, Object?>.from(raw);
      final unknown = value.keys.toSet().difference(_recordFields);
      if (unknown.isNotEmpty) {
        throw FormatException(
          'Record contains unknown fields: ${unknown.join(', ')}.',
        );
      }
      sourceDigest = OperationTransferCanonicalService.digest(value);
      final aggregate = DailyAggregateV1.fromJson(value);
      operationDate = aggregate.operationDate;
      if (aggregate.sourceType != DailyAggregateSourceType.legacyDns) {
        throw const FormatException('sourceType must be legacyDns.');
      }
      _validateDate(operationDate);
      if (operationDate.compareTo(requestedStartDate) < 0 ||
          operationDate.compareTo(requestedEndDate) > 0) {
        throw const FormatException(
          'Daily Aggregate is outside the requested date range.',
        );
      }
      return HistoricalDnsPreviewItem(
        index: index,
        operationDate: operationDate,
        sourceDigest: sourceDigest,
        aggregate: aggregate,
        existingAggregate: null,
        disposition: OperationSyncRecordDisposition.newRecord,
        differences: const [],
        issues: const [],
      );
    } catch (error) {
      return HistoricalDnsPreviewItem(
        index: index,
        operationDate: operationDate,
        sourceDigest: sourceDigest,
        aggregate: null,
        existingAggregate: null,
        disposition: OperationSyncRecordDisposition.invalid,
        differences: const [],
        issues: [
          HistoricalDnsIssue('invalidRecord', error.toString(), path: r'$'),
        ],
      );
    }
  }

  HistoricalDnsPreview _classify({
    required Map<String, Object?> decoded,
    required String responseDigest,
    required String packageDigest,
    required List<HistoricalDnsPreviewItem> mapped,
    required List<Map<String, Object?>> existing,
  }) {
    final existingByDate = <String, DailyAggregateV1>{};
    for (final raw in existing) {
      final aggregate = DailyAggregateV1.fromJson(raw);
      existingByDate[aggregate.operationDate] = aggregate;
    }
    final packageDates = <String>{};
    final result = <HistoricalDnsPreviewItem>[];
    for (final item in mapped) {
      if (item.disposition == OperationSyncRecordDisposition.invalid) {
        result.add(item);
        continue;
      }
      final date = item.operationDate!;
      if (!packageDates.add(date)) {
        result.add(
          item.withDisposition(
            OperationSyncRecordDisposition.blocked,
            issue: const HistoricalDnsIssue(
              'duplicateOperationDate',
              'The package contains the same operationDate more than once.',
            ),
          ),
        );
      } else {
        final existingAggregate = existingByDate[date];
        if (existingAggregate == null) {
          result.add(item);
          continue;
        }
        if (existingAggregate.sourceType == DailyAggregateSourceType.records) {
          result.add(
            item.classified(
              disposition: OperationSyncRecordDisposition.blocked,
              existingAggregate: existingAggregate,
              issue: const HistoricalDnsIssue(
                'recordsAggregateProtected',
                'FINALIZE由来のDaily AggregateはHistorical DNSで置換できません。',
              ),
            ),
          );
          continue;
        }
        final differences = historicalImportDifferences(
          existingAggregate.toJson(),
          item.aggregate!.toJson(),
        );
        result.add(
          item.classified(
            disposition: differences.isEmpty
                ? OperationSyncRecordDisposition.identical
                : OperationSyncRecordDisposition.conflict,
            existingAggregate: existingAggregate,
            differences: differences,
          ),
        );
      }
    }
    return HistoricalDnsPreview(
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

  @override
  Future<HistoricalDnsApplyResult> apply(
    HistoricalDnsPreview preview, {
    Set<int>? selectedIndexes,
  }) async {
    if (!preview.canApply) {
      throw StateError('Historical DNS package is blocked.');
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
      throw StateError('Historical DNS selection is invalid.');
    }
    final now = clock().toUtc();
    return database.runTransaction(
      storeNames: const [
        IndexedDbStoreNames.dailyAggregateRecords,
        IndexedDbStoreNames.operationSyncHistory,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final revalidated = _classify(
          decoded: preview.envelope,
          responseDigest: preview.responseDigest,
          packageDigest: preview.packageDigest,
          mapped: preview.records,
          existing: await transaction.findAll(
            IndexedDbStoreNames.dailyAggregateRecords,
          ),
        );
        if (!_samePlan(preview, revalidated) || !revalidated.canApply) {
          throw StateError('Historical DNS import preview is stale.');
        }
        final appliedItems = revalidated.records
            .where((item) => selected.contains(item.index) && item.isSelectable)
            .toList();
        for (final item in appliedItems) {
          await repository.putInTransaction(transaction, item.aggregate!);
        }
        final auditItems = [
          for (final item in revalidated.records)
            OperationSyncRecordItem(
              sourceRecordId: null,
              operationDate: item.operationDate!,
              sourceDigest: item.sourceDigest!,
              targetRecordId: selected.contains(item.index) && item.isSelectable
                  ? item.operationDate
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
          workflowKind: _exchangeType,
          recordType: _recordType,
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
        return HistoricalDnsApplyResult(record);
      },
    );
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
      if (record.workflowKind == _exchangeType) records.add(record);
    }
    records.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return List.unmodifiable(records);
  }

  static bool _samePlan(
    HistoricalDnsPreview first,
    HistoricalDnsPreview second,
  ) =>
      first.packageDigest == second.packageDigest &&
      first.requestedStartDate == second.requestedStartDate &&
      first.requestedEndDate == second.requestedEndDate &&
      first.records.length == second.records.length &&
      List.generate(first.records.length, (index) {
        final a = first.records[index];
        final b = second.records[index];
        return a.sourceDigest == b.sourceDigest &&
            a.operationDate == b.operationDate &&
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
    _validateDate(startDate);
    _validateDate(endDate);
    if (startDate.compareTo(endDate) > 0) {
      throw const FormatException('Invalid requested date range.');
    }
  }

  static void _validateDate(String value) {
    final pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (!pattern.hasMatch(value) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != value) {
      throw const FormatException('Invalid operationDate.');
    }
  }
}
