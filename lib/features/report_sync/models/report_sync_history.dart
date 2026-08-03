import 'report_sync_envelope.dart';
import 'report_sync_issue.dart';
import 'report_sync_record_utils.dart';

enum ReportSyncHistoryResult {
  success('success'),
  failed('failed'),
  noChange('noChange'),
  conflict('conflict');

  const ReportSyncHistoryResult(this.stableId);
  final String stableId;
}

class ReportSyncHistory {
  static const currentRecordVersion = 2;
  static const version1Fields = {
    'exchangeId',
    'recordVersion',
    'exchangeType',
    'direction',
    'operationDate',
    'requestId',
    'requestDigest',
    'responseDigest',
    'confirmationDigest',
    'startedAt',
    'completedAt',
    'result',
    'failureCode',
    'packageDigest',
  };
  static const fields = {
    ...version1Fields,
    'receivedMealCount',
    'selectedMealCount',
    'importedMealCount',
    'conflictMealCount',
    'excludedMealCount',
  };
  final String exchangeId;
  final int recordVersion;
  final ReportSyncExchangeType exchangeType;
  final ReportSyncDirection direction;
  final String operationDate;
  final String requestId;
  final String requestDigest;
  final String? responseDigest;
  final String? confirmationDigest;
  final DateTime startedAt;
  final DateTime completedAt;
  final ReportSyncHistoryResult result;
  final ReportSyncIssueCode? failureCode;
  final String packageDigest;
  final int? receivedMealCount;
  final int? selectedMealCount;
  final int? importedMealCount;
  final int? conflictMealCount;
  final int? excludedMealCount;

  ReportSyncHistory({
    required this.exchangeId,
    this.recordVersion = currentRecordVersion,
    required this.exchangeType,
    required this.direction,
    required this.operationDate,
    required this.requestId,
    required this.requestDigest,
    this.responseDigest,
    this.confirmationDigest,
    required this.startedAt,
    required this.completedAt,
    required this.result,
    this.failureCode,
    required this.packageDigest,
    this.receivedMealCount,
    this.selectedMealCount,
    this.importedMealCount,
    this.conflictMealCount,
    this.excludedMealCount,
  }) {
    if (recordVersion != 1 && recordVersion != currentRecordVersion) {
      throw const FormatException('Unsupported history version.');
    }
    if (completedAt.isBefore(startedAt)) {
      throw const FormatException('completedAt precedes startedAt.');
    }
    if ((result == ReportSyncHistoryResult.failed ||
            result == ReportSyncHistoryResult.conflict) !=
        (failureCode != null)) {
      throw const FormatException('failureCode does not match result.');
    }
    _validateMealCounts();
  }

  Map<String, Object?> toRecord() => {
    'exchangeId': exchangeId,
    'recordVersion': recordVersion,
    'exchangeType': exchangeType.stableId,
    'direction': direction.stableId,
    'operationDate': operationDate,
    'requestId': requestId,
    'requestDigest': requestDigest,
    'responseDigest': responseDigest,
    'confirmationDigest': confirmationDigest,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt.toUtc().toIso8601String(),
    'result': result.stableId,
    'failureCode': failureCode?.stableId,
    'packageDigest': packageDigest,
    if (recordVersion >= 2) ...{
      'receivedMealCount': receivedMealCount,
      'selectedMealCount': selectedMealCount,
      'importedMealCount': importedMealCount,
      'conflictMealCount': conflictMealCount,
      'excludedMealCount': excludedMealCount,
    },
  };

  factory ReportSyncHistory.fromRecord(Map<String, Object?> json) {
    final version = json['recordVersion'];
    if (version is! int || (version != 1 && version != currentRecordVersion)) {
      throw const FormatException('Unsupported history version.');
    }
    ReportSyncRecordUtils.exactFields(
      json,
      version == 1 ? version1Fields : fields,
    );
    T parse<T>(Iterable<T> values, Object? raw, String Function(T) id) {
      if (raw is! String) {
        throw const FormatException('Invalid stable ID.');
      }
      return values.firstWhere(
        (value) => id(value) == raw,
        orElse: () => throw FormatException('Unknown stable ID: $raw.'),
      );
    }

    final failureRaw = json['failureCode'];
    return ReportSyncHistory(
      exchangeId: ReportSyncRecordUtils.string(json, 'exchangeId'),
      exchangeType: parse(
        ReportSyncExchangeType.values,
        json['exchangeType'],
        (v) => v.stableId,
      ),
      direction: parse(
        ReportSyncDirection.values,
        json['direction'],
        (v) => v.stableId,
      ),
      operationDate: ReportSyncRecordUtils.localDate(json, 'operationDate'),
      requestId: ReportSyncRecordUtils.string(json, 'requestId'),
      requestDigest: ReportSyncRecordUtils.digest(json, 'requestDigest'),
      responseDigest: ReportSyncRecordUtils.nullableDigest(
        json,
        'responseDigest',
      ),
      confirmationDigest: ReportSyncRecordUtils.nullableDigest(
        json,
        'confirmationDigest',
      ),
      startedAt: ReportSyncRecordUtils.date(json, 'startedAt'),
      completedAt: ReportSyncRecordUtils.date(json, 'completedAt'),
      result: parse(
        ReportSyncHistoryResult.values,
        json['result'],
        (v) => v.stableId,
      ),
      failureCode: failureRaw == null
          ? null
          : parse<ReportSyncIssueCode>(
              ReportSyncIssueCode.values,
              failureRaw,
              (v) => v.stableId,
            ),
      packageDigest: ReportSyncRecordUtils.digest(json, 'packageDigest'),
      receivedMealCount: version == 1
          ? null
          : _nullableNonNegativeInteger(json, 'receivedMealCount'),
      selectedMealCount: version == 1
          ? null
          : _nullableNonNegativeInteger(json, 'selectedMealCount'),
      importedMealCount: version == 1
          ? null
          : _nullableNonNegativeInteger(json, 'importedMealCount'),
      conflictMealCount: version == 1
          ? null
          : _nullableNonNegativeInteger(json, 'conflictMealCount'),
      excludedMealCount: version == 1
          ? null
          : _nullableNonNegativeInteger(json, 'excludedMealCount'),
      recordVersion: version,
    );
  }

  void _validateMealCounts() {
    final counts = [
      receivedMealCount,
      selectedMealCount,
      importedMealCount,
      conflictMealCount,
      excludedMealCount,
    ];
    if (recordVersion == 1 && counts.any((value) => value != null)) {
      throw const FormatException(
        'History version 1 cannot contain meal counts.',
      );
    }
    if (exchangeType != ReportSyncExchangeType.food &&
        counts.any((value) => value != null)) {
      throw const FormatException(
        'Meal counts are only valid for FOOD history.',
      );
    }
    if (counts.any((value) => value != null && value < 0)) {
      throw const FormatException(
        'Meal counts must be non-negative integers or null.',
      );
    }
    if ((receivedMealCount != null &&
            selectedMealCount != null &&
            selectedMealCount! > receivedMealCount!) ||
        (selectedMealCount != null &&
            importedMealCount != null &&
            importedMealCount! > selectedMealCount!) ||
        (receivedMealCount != null &&
            conflictMealCount != null &&
            conflictMealCount! > receivedMealCount!) ||
        (receivedMealCount != null &&
            importedMealCount != null &&
            excludedMealCount != null &&
            excludedMealCount != receivedMealCount! - importedMealCount!)) {
      throw const FormatException('Meal counts are inconsistent.');
    }
  }

  static int? _nullableNonNegativeInteger(
    Map<String, Object?> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is! int || value < 0) {
      throw FormatException('$key must be a non-negative integer or null.');
    }
    return value;
  }
}

class ReportSyncMealCounts {
  const ReportSyncMealCounts({
    required this.received,
    required this.selected,
    required this.imported,
    required this.conflict,
  });

  final int received;
  final int selected;
  final int imported;
  final int conflict;
  int get excluded => received - imported;
}
