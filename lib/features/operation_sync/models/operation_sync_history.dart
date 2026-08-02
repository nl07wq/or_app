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
