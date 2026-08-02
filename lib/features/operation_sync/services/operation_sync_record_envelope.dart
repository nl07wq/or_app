import '../models/operation_sync_issue.dart';
import '../models/operation_transfer_package.dart';
import 'operation_transfer_canonical_service.dart';

class OperationSyncRecordEnvelope {
  static const _payloadFields = {'recordType', 'record'};

  final String recordType;
  final Map<String, Object?> record;

  OperationSyncRecordEnvelope({
    required this.recordType,
    required Map<String, Object?> record,
  }) : record = _copyMap(record) {
    if (recordType.isEmpty) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Sync recordType is required.',
      );
    }
    _validateTimestamps(this.record);
  }

  factory OperationSyncRecordEnvelope.fromTransfer(
    OperationTransferRecord source,
  ) {
    if (source.canonicalPayload.keys.any(
      (key) => !_payloadFields.contains(key),
    )) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Sync canonicalPayload contains an unknown field.',
      );
    }
    final recordType = source.canonicalPayload['recordType'];
    final record = source.canonicalPayload['record'];
    if (recordType is! String || recordType.isEmpty || record is! Map) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Sync canonicalPayload is invalid.',
      );
    }
    return OperationSyncRecordEnvelope(
      recordType: recordType,
      record: Map<String, Object?>.from(record),
    );
  }

  Map<String, Object?> toPayload() => {
    'recordType': recordType,
    'record': _copyMap(record),
  };

  String get domainDigest =>
      OperationTransferCanonicalService.digest(_withoutTimestamps(record));

  String get persistedDigest =>
      OperationTransferCanonicalService.digest(record);

  static OperationTransferRecord transferRecord({
    required String recordType,
    required Map<String, Object?> record,
    required String recordId,
    required int recordVersion,
    required String localDate,
  }) {
    final envelope = OperationSyncRecordEnvelope(
      recordType: recordType,
      record: record,
    );
    final unsigned = OperationTransferRecord(
      recordId: recordId,
      recordVersion: recordVersion,
      localDate: localDate,
      canonicalPayload: envelope.toPayload(),
      recordDigest: '',
    );
    return OperationTransferRecord(
      recordId: recordId,
      recordVersion: recordVersion,
      localDate: localDate,
      canonicalPayload: envelope.toPayload(),
      recordDigest: OperationTransferCanonicalService.recordDigest(unsigned),
    );
  }

  static bool persistedEqual(
    Map<String, Object?> first,
    Map<String, Object?> second,
  ) =>
      OperationTransferCanonicalService.encode(first) ==
      OperationTransferCanonicalService.encode(second);

  static void _validateTimestamps(Map<String, Object?> record) {
    final createdAt = _timestamp(record, 'createdAt');
    final updatedAt = _timestamp(record, 'updatedAt');
    if (updatedAt.isBefore(createdAt)) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Sync updatedAt precedes createdAt.',
      );
    }
  }

  static DateTime _timestamp(Map<String, Object?> record, String key) {
    final value = record[key];
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null ||
        !parsed.isUtc ||
        parsed.toUtc().toIso8601String() != value) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Sync $key must be a canonical UTC timestamp.',
      );
    }
    return parsed;
  }

  static Object? _withoutTimestamps(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          if (entry.key != 'createdAt' && entry.key != 'updatedAt')
            entry.key.toString(): _withoutTimestamps(entry.value),
      };
    }
    if (value is Iterable) {
      return [for (final item in value) _withoutTimestamps(item)];
    }
    return value;
  }

  static Map<String, Object?> _copyMap(Map source) => {
    for (final entry in source.entries)
      entry.key.toString(): _copyValue(entry.value),
  };

  static Object? _copyValue(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is Iterable) {
      return [for (final item in value) _copyValue(item)];
    }
    return value;
  }
}
