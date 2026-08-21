import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/models/report_sync_issue.dart';
import '../../report_sync/models/report_sync_record_utils.dart';
import '../../report_sync/services/report_sync_payload_registry.dart';
import '../models/training_analysis_report.dart';

class TrainingAnalysisPayloadSchema implements ReportSyncPayloadSchema {
  const TrainingAnalysisPayloadSchema();

  static const requestFields = {
    'operationDate',
    'targetRecordId',
    'sourceDigest',
    'facts',
  };
  static const responseFields = {
    'operationDate',
    'targetRecordId',
    'sourceDigest',
    'analysis',
  };

  @override
  ReportSyncExchangeType get exchangeType =>
      ReportSyncExchangeType.trainingAnalysis;

  @override
  void validateRequest(Map<String, Object?> payload) {
    try {
      ReportSyncRecordUtils.exactFields(payload, requestFields);
      ReportSyncRecordUtils.localDate(payload, 'operationDate');
      ReportSyncRecordUtils.string(payload, 'targetRecordId');
      ReportSyncRecordUtils.digest(payload, 'sourceDigest');
      if (payload['facts'] is! Map) {
        throw const FormatException('facts is invalid.');
      }
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
      ReportSyncRecordUtils.localDate(payload, 'operationDate');
      ReportSyncRecordUtils.string(payload, 'targetRecordId');
      ReportSyncRecordUtils.digest(payload, 'sourceDigest');
      final analysis = payload['analysis'];
      if (analysis is! Map) {
        throw const FormatException('analysis is invalid.');
      }
      TrainingAnalysis.fromJson(Map<String, Object?>.from(analysis));
    } catch (error) {
      throw ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        error.toString(),
      );
    }
  }

  @override
  Map<String, Object?> get minimalResponseExample => {
    'operationDate': '2000-01-01',
    'targetRecordId': 'training:00000000-0000-4000-8000-000000000000',
    'sourceDigest':
        '0000000000000000000000000000000000000000000000000000000000000000',
    'analysis': {
      'sessionSummary': '<Japanese analysis>',
      'performanceAnalysis': '<Japanese analysis>',
      'previousComparison': '<Japanese analysis>',
      'progressAnalysis': '<Japanese analysis>',
      'recoveryFrequencyComment': '<Japanese analysis>',
      'nextSessionProposal': '<Japanese proposal>',
      'riskAttentionNotes': '<Japanese notes>',
      'exerciseAnalyses': <Object?>[],
    },
  };
}
