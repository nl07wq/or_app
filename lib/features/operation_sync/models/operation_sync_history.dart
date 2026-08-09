import 'operation_sync_issue.dart';

enum OperationSyncHistoryResult {
  success('success'),
  failed('failed'),
  recoveryRequired('recoveryRequired');

  const OperationSyncHistoryResult(this.stableId);
  final String stableId;
}

class OperationSyncHistory {
  static const currentRecordVersion = 1;

  final String operationId;
  final int recordVersion;
  final String packageId;
  final String packageDigest;
  final String sourceType;
  final String transferMode;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<String> moduleIds;
  final int recordCount;
  final int createCount;
  final int noChangeCount;
  final int conflictCount;
  final int quarantineCount;
  final OperationSyncHistoryResult result;
  final OperationSyncIssueCode? failureCode;
  final bool isRecoveryExecution;

  OperationSyncHistory({
    required this.operationId,
    this.recordVersion = currentRecordVersion,
    required this.packageId,
    required this.packageDigest,
    required this.sourceType,
    required this.transferMode,
    required this.startedAt,
    required this.completedAt,
    required Iterable<String> moduleIds,
    required this.recordCount,
    required this.createCount,
    required this.noChangeCount,
    required this.conflictCount,
    required this.quarantineCount,
    required this.result,
    this.failureCode,
    required this.isRecoveryExecution,
  }) : moduleIds = List.unmodifiable(moduleIds) {
    if (operationId.isEmpty ||
        packageId.isEmpty ||
        packageDigest.isEmpty ||
        completedAt.isBefore(startedAt) ||
        [
          recordCount,
          createCount,
          noChangeCount,
          conflictCount,
          quarantineCount,
        ].any((value) => value < 0)) {
      throw const FormatException('Invalid Operation Sync history.');
    }
  }

  Map<String, Object?> toRecord() => {
    'operationId': operationId,
    'recordVersion': recordVersion,
    'packageId': packageId,
    'packageDigest': packageDigest,
    'sourceType': sourceType,
    'transferMode': transferMode,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt.toUtc().toIso8601String(),
    'moduleIds': moduleIds,
    'recordCount': recordCount,
    'createCount': createCount,
    'noChangeCount': noChangeCount,
    'conflictCount': conflictCount,
    'quarantineCount': quarantineCount,
    'result': result.stableId,
    'failureCode': failureCode?.stableId,
    'isRecoveryExecution': isRecoveryExecution,
  };

  factory OperationSyncHistory.fromRecord(Map<String, Object?> record) {
    const fields = {
      'operationId',
      'recordVersion',
      'packageId',
      'packageDigest',
      'sourceType',
      'transferMode',
      'startedAt',
      'completedAt',
      'moduleIds',
      'recordCount',
      'createCount',
      'noChangeCount',
      'conflictCount',
      'quarantineCount',
      'result',
      'failureCode',
      'isRecoveryExecution',
    };
    if (record.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(record.keys.toSet()).isNotEmpty ||
        record['recordVersion'] != currentRecordVersion) {
      throw const FormatException('Invalid Operation Sync history fields.');
    }
    final modules = record['moduleIds'];
    if (modules is! List || modules.any((value) => value is! String)) {
      throw const FormatException('Invalid moduleIds.');
    }
    int count(String key) {
      final value = record[key];
      if (value is! int) throw FormatException('$key must be an integer.');
      return value;
    }

    T enumValue<T>(Iterable<T> values, Object? raw, String Function(T) id) {
      if (raw is! String) throw const FormatException('Invalid stable ID.');
      return values.firstWhere(
        (value) => id(value) == raw,
        orElse: () => throw FormatException('Unknown stable ID: $raw.'),
      );
    }

    final rawFailure = record['failureCode'];
    return OperationSyncHistory(
      operationId: _requiredString(record, 'operationId'),
      packageId: _requiredString(record, 'packageId'),
      packageDigest: _requiredString(record, 'packageDigest'),
      sourceType: _requiredString(record, 'sourceType'),
      transferMode: _requiredString(record, 'transferMode'),
      startedAt: _requiredDate(record, 'startedAt'),
      completedAt: _requiredDate(record, 'completedAt'),
      moduleIds: modules.cast<String>(),
      recordCount: count('recordCount'),
      createCount: count('createCount'),
      noChangeCount: count('noChangeCount'),
      conflictCount: count('conflictCount'),
      quarantineCount: count('quarantineCount'),
      result: enumValue<OperationSyncHistoryResult>(
        OperationSyncHistoryResult.values,
        record['result'],
        (value) => value.stableId,
      ),
      failureCode: rawFailure == null
          ? null
          : enumValue<OperationSyncIssueCode>(
              OperationSyncIssueCode.values,
              rawFailure,
              (value) => value.stableId,
            ),
      isRecoveryExecution: record['isRecoveryExecution'] is bool
          ? record['isRecoveryExecution'] as bool
          : throw const FormatException('Invalid isRecoveryExecution.'),
    );
  }
}

enum OperationSyncRecordResult {
  success('success'),
  failed('failed');

  const OperationSyncRecordResult(this.stableId);
  final String stableId;
}

enum OperationSyncRecordDisposition {
  newRecord('new'),
  identical('identical'),
  conflict('conflict'),
  invalid('invalid'),
  excluded('excluded'),
  blocked('blocked');

  const OperationSyncRecordDisposition(this.stableId);
  final String stableId;
}

class OperationSyncRecordItem {
  final String? sourceRecordId;
  final String operationDate;
  final String sourceDigest;
  final String? targetRecordId;
  final OperationSyncRecordDisposition disposition;
  final OperationSyncRecordResult result;
  final String? errorCode;

  const OperationSyncRecordItem({
    required this.sourceRecordId,
    required this.operationDate,
    required this.sourceDigest,
    required this.targetRecordId,
    required this.disposition,
    required this.result,
    required this.errorCode,
  });

  Map<String, Object?> toJson() => {
    'sourceRecordId': sourceRecordId,
    'operationDate': operationDate,
    'sourceDigest': sourceDigest,
    'targetRecordId': targetRecordId,
    'disposition': disposition.stableId,
    'result': result.stableId,
    'errorCode': errorCode,
  };

  factory OperationSyncRecordItem.fromJson(Map<String, Object?> value) {
    _exactFields(value, const {
      'sourceRecordId',
      'operationDate',
      'sourceDigest',
      'targetRecordId',
      'disposition',
      'result',
      'errorCode',
    });
    return OperationSyncRecordItem(
      sourceRecordId: _nullableString(value, 'sourceRecordId'),
      operationDate: _requiredString(value, 'operationDate'),
      sourceDigest: _requiredDigest(value, 'sourceDigest'),
      targetRecordId: _nullableString(value, 'targetRecordId'),
      disposition: _enumValue(
        OperationSyncRecordDisposition.values,
        value['disposition'],
        (item) => item.stableId,
      ),
      result: _enumValue(
        OperationSyncRecordResult.values,
        value['result'],
        (item) => item.stableId,
      ),
      errorCode: _nullableString(value, 'errorCode'),
    );
  }
}

class OperationSyncRecord {
  static const currentRecordVersion = 2;

  final String operationId;
  final int recordVersion;
  final String workflowKind;
  final String recordType;
  final String sourceMode;
  final String importMode;
  final String? startDate;
  final String? endDate;
  final int receivedCount;
  final int newCount;
  final int identicalCount;
  final int conflictCount;
  final int invalidCount;
  final int excludedCount;
  final int blockedCount;
  final int appliedCount;
  final int skippedCount;
  final String exchangeId;
  final String responseDigest;
  final String packageDigest;
  final OperationSyncRecordResult result;
  final String? failureCode;
  final DateTime createdAt;
  final DateTime completedAt;
  final List<OperationSyncRecordItem> records;

  OperationSyncRecord({
    required this.operationId,
    this.recordVersion = currentRecordVersion,
    this.workflowKind = 'historicalTraining',
    this.recordType = 'trainingV2',
    this.sourceMode = 'allAvailableRecords',
    this.importMode = 'missingRecordsOnly',
    required this.startDate,
    required this.endDate,
    required this.receivedCount,
    required this.newCount,
    required this.identicalCount,
    required this.conflictCount,
    required this.invalidCount,
    required this.excludedCount,
    required this.blockedCount,
    required this.appliedCount,
    required this.skippedCount,
    required this.exchangeId,
    required this.responseDigest,
    required this.packageDigest,
    required this.result,
    required this.failureCode,
    required this.createdAt,
    required this.completedAt,
    required Iterable<OperationSyncRecordItem> records,
  }) : records = List.unmodifiable(records) {
    if (operationId.isEmpty ||
        exchangeId.isEmpty ||
        completedAt.isBefore(createdAt) ||
        [
          receivedCount,
          newCount,
          identicalCount,
          conflictCount,
          invalidCount,
          excludedCount,
          blockedCount,
          appliedCount,
          skippedCount,
        ].any((count) => count < 0) ||
        receivedCount != records.length) {
      throw const FormatException('Invalid Operation Sync record.');
    }
    _validateStableContract();
    _validateRange(startDate, endDate);
    _validateDigest(responseDigest);
    _validateDigest(packageDigest);
  }

  void _validateStableContract() {
    final supportedRecord =
        (workflowKind == 'historicalTraining' &&
            recordType == 'trainingV2' &&
            const {'allAvailableRecords', 'dateRange'}.contains(sourceMode)) ||
        (workflowKind == 'historicalDns' &&
            recordType == 'dailyAggregateV1' &&
            sourceMode == 'dateRange');
    if (recordVersion != currentRecordVersion ||
        !supportedRecord ||
        importMode != 'missingRecordsOnly') {
      throw const FormatException('Unsupported Operation Sync record.');
    }
  }

  Map<String, Object?> toRecord() => {
    'operationId': operationId,
    'recordVersion': recordVersion,
    'workflowKind': workflowKind,
    'recordType': recordType,
    'sourceMode': sourceMode,
    'importMode': importMode,
    'startDate': startDate,
    'endDate': endDate,
    'receivedCount': receivedCount,
    'newCount': newCount,
    'identicalCount': identicalCount,
    'conflictCount': conflictCount,
    'invalidCount': invalidCount,
    'excludedCount': excludedCount,
    'blockedCount': blockedCount,
    'appliedCount': appliedCount,
    'skippedCount': skippedCount,
    'exchangeId': exchangeId,
    'responseDigest': responseDigest,
    'packageDigest': packageDigest,
    'result': result.stableId,
    'failureCode': failureCode,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'completedAt': completedAt.toUtc().toIso8601String(),
    'records': records.map((item) => item.toJson()).toList(),
  };

  factory OperationSyncRecord.fromRecord(Map<String, Object?> value) {
    _exactFields(value, const {
      'operationId',
      'recordVersion',
      'workflowKind',
      'recordType',
      'sourceMode',
      'importMode',
      'startDate',
      'endDate',
      'receivedCount',
      'newCount',
      'identicalCount',
      'conflictCount',
      'invalidCount',
      'excludedCount',
      'blockedCount',
      'appliedCount',
      'skippedCount',
      'exchangeId',
      'responseDigest',
      'packageDigest',
      'result',
      'failureCode',
      'createdAt',
      'completedAt',
      'records',
    });
    final rawRecords = value['records'];
    if (rawRecords is! List) {
      throw const FormatException('Invalid Operation Sync record entries.');
    }
    int count(String key) {
      final raw = value[key];
      if (raw is! int) throw FormatException('$key must be an integer.');
      return raw;
    }

    return OperationSyncRecord(
      operationId: _requiredString(value, 'operationId'),
      recordVersion: count('recordVersion'),
      workflowKind: _requiredString(value, 'workflowKind'),
      recordType: _requiredString(value, 'recordType'),
      sourceMode: _requiredString(value, 'sourceMode'),
      importMode: _requiredString(value, 'importMode'),
      startDate: _nullableString(value, 'startDate'),
      endDate: _nullableString(value, 'endDate'),
      receivedCount: count('receivedCount'),
      newCount: count('newCount'),
      identicalCount: count('identicalCount'),
      conflictCount: count('conflictCount'),
      invalidCount: count('invalidCount'),
      excludedCount: count('excludedCount'),
      blockedCount: count('blockedCount'),
      appliedCount: count('appliedCount'),
      skippedCount: count('skippedCount'),
      exchangeId: _requiredString(value, 'exchangeId'),
      responseDigest: _requiredDigest(value, 'responseDigest'),
      packageDigest: _requiredDigest(value, 'packageDigest'),
      result: _enumValue(
        OperationSyncRecordResult.values,
        value['result'],
        (item) => item.stableId,
      ),
      failureCode: _nullableString(value, 'failureCode'),
      createdAt: _requiredDate(value, 'createdAt'),
      completedAt: _requiredDate(value, 'completedAt'),
      records: [
        for (final raw in rawRecords)
          if (raw is Map)
            OperationSyncRecordItem.fromJson(Map<String, Object?>.from(raw))
          else
            throw const FormatException('Invalid Operation Sync record item.'),
      ],
    );
  }
}

void validateOperationSyncStoredRecord(Map<String, Object?> record) {
  switch (record['recordVersion']) {
    case OperationSyncHistory.currentRecordVersion:
      OperationSyncHistory.fromRecord(record);
    case OperationSyncRecord.currentRecordVersion:
      OperationSyncRecord.fromRecord(record);
    default:
      throw const FormatException('Unsupported Operation Sync record version.');
  }
}

String _requiredString(Map<String, Object?> record, String key) {
  final value = record[key];
  if (value is! String || value.isEmpty) throw FormatException('$key invalid.');
  return value;
}

DateTime _requiredDate(Map<String, Object?> record, String key) {
  final parsed = DateTime.tryParse(_requiredString(record, key));
  if (parsed == null || !parsed.isUtc) throw FormatException('$key invalid.');
  return parsed;
}

String? _nullableString(Map<String, Object?> record, String key) {
  final value = record[key];
  if (value != null && (value is! String || value.isEmpty)) {
    throw FormatException('$key invalid.');
  }
  return value as String?;
}

String _requiredDigest(Map<String, Object?> record, String key) {
  final value = _requiredString(record, key);
  _validateDigest(value);
  return value;
}

void _validateDigest(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException('Invalid digest.');
  }
}

void _validateRange(String? startDate, String? endDate) {
  if ((startDate == null) != (endDate == null)) {
    throw const FormatException('Invalid Operation Sync date range.');
  }
  if (startDate == null) return;
  final start = DateTime.tryParse('${startDate}T00:00:00Z');
  final end = DateTime.tryParse('${endDate}T00:00:00Z');
  if (start == null || end == null || end.isBefore(start)) {
    throw const FormatException('Invalid Operation Sync date range.');
  }
}

void _exactFields(Map<String, Object?> value, Set<String> expected) {
  final actual = value.keys.toSet();
  if (actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw const FormatException('Invalid Operation Sync record fields.');
  }
}

T _enumValue<T>(Iterable<T> values, Object? raw, String Function(T) stableId) {
  if (raw is! String) throw const FormatException('Invalid stable ID.');
  return values.firstWhere(
    (value) => stableId(value) == raw,
    orElse: () => throw FormatException('Unknown stable ID: $raw.'),
  );
}
