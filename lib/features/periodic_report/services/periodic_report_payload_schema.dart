import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/models/report_sync_issue.dart';
import '../../report_sync/models/report_sync_record_utils.dart';
import '../../report_sync/services/report_sync_payload_registry.dart';
import '../models/periodic_report.dart';

class PeriodicReportPayloadSchema implements ReportSyncPayloadSchema {
  const PeriodicReportPayloadSchema();

  static const requestFields = {
    'operationDate',
    'periodId',
    'reportType',
    'sourceDigest',
    'facts',
  };
  static const responseFields = {
    'operationDate',
    'periodId',
    'reportType',
    'sourceDigest',
    'analysis',
  };

  @override
  ReportSyncExchangeType get exchangeType =>
      ReportSyncExchangeType.periodicReport;

  @override
  void validateRequest(Map<String, Object?> payload) {
    try {
      ReportSyncRecordUtils.exactFields(payload, requestFields);
      final facts = PeriodicReportFacts.fromJson(_map(payload['facts']));
      ReportSyncRecordUtils.localDate(payload, 'operationDate');
      _identity(payload, facts.reportType, facts.periodId);
      ReportSyncRecordUtils.digest(payload, 'sourceDigest');
    } catch (error) {
      throw ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        error.toString(),
      );
    }
  }

  @override
  void validateResponse(Map<String, Object?> payload) {
    try {
      ReportSyncRecordUtils.exactFields(payload, responseFields);
      final type = PeriodicReportType.parse(payload['reportType']);
      ReportSyncRecordUtils.localDate(payload, 'operationDate');
      _identity(
        payload,
        type,
        ReportSyncRecordUtils.string(payload, 'periodId'),
      );
      ReportSyncRecordUtils.digest(payload, 'sourceDigest');
      PeriodicReportAnalysis.fromJson(_map(payload['analysis']));
    } catch (error) {
      throw ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        error.toString(),
      );
    }
  }

  static void _identity(
    Map<String, Object?> payload,
    PeriodicReportType type,
    String periodId,
  ) {
    if (payload['reportType'] != type.stableId ||
        payload['periodId'] != periodId ||
        !periodId.startsWith('${type.stableId}:')) {
      throw const FormatException('Periodic report identity is invalid.');
    }
  }

  @override
  Map<String, Object?> get minimalResponseExample => {
    'operationDate': '2000-01-09',
    'periodId': 'weekly:2000-01-03',
    'reportType': 'weekly',
    'sourceDigest':
        '0000000000000000000000000000000000000000000000000000000000000000',
    'analysis': {
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
    },
  };
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const FormatException('Expected an object.');
  return Map<String, Object?>.from(value);
}
