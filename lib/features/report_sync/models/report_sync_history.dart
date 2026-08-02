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
  static const currentRecordVersion = 1;
  static const fields = {
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
  }) {
    if (completedAt.isBefore(startedAt)) {
      throw const FormatException('completedAt precedes startedAt.');
    }
    if ((result == ReportSyncHistoryResult.failed ||
            result == ReportSyncHistoryResult.conflict) !=
        (failureCode != null)) {
      throw const FormatException('failureCode does not match result.');
    }
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
  };

  factory ReportSyncHistory.fromRecord(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    if (json['recordVersion'] != currentRecordVersion) {
      throw const FormatException('Unsupported history version.');
    }
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
    );
  }
}
