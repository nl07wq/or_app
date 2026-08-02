import '../../daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_issue.dart';
import '../repository/report_sync_history_repository.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_payload_registry.dart';

class ReportSyncValidator {
  final ReportSyncHistoryRepository historyRepository;
  final DailyLogConfirmationStore confirmationRepository;
  final ReportSyncPayloadRegistry payloadRegistry;
  ReportSyncValidator({
    required this.historyRepository,
    required this.confirmationRepository,
    ReportSyncPayloadRegistry? payloadRegistry,
  }) : payloadRegistry =
           payloadRegistry ?? ReportSyncPayloadRegistry.standard();

  Future<void> validateResponse(ReportSyncEnvelope response) async {
    if (response.direction != ReportSyncDirection.response) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'A response envelope is required.',
      );
    }
    final requests = (await historyRepository.list())
        .where(
          (history) =>
              history.direction == ReportSyncDirection.request &&
              history.requestId == response.requestId,
        )
        .toList();
    if (requests.length != 1) {
      throw const ReportSyncException(
        ReportSyncIssueCode.requestNotFound,
        'The matching saved request was not found.',
      );
    }
    final request = requests.single;
    if (request.exchangeType != response.exchangeType) {
      throw const ReportSyncException(
        ReportSyncIssueCode.exchangeTypeMismatch,
        'exchangeType does not match the request.',
      );
    }
    if (request.operationDate != response.operationDate) {
      throw const ReportSyncException(
        ReportSyncIssueCode.operationDateMismatch,
        'operationDate does not match the request.',
      );
    }
    if (request.requestDigest != response.requestDigest) {
      throw const ReportSyncException(
        ReportSyncIssueCode.requestDigestMismatch,
        'requestDigest does not match the request.',
      );
    }
    payloadRegistry.validate(response);
    if (response.exchangeType == ReportSyncExchangeType.dailyDebrief) {
      if (request.confirmationDigest != response.confirmationDigest) {
        throw const ReportSyncException(
          ReportSyncIssueCode.confirmationDigestMismatch,
          'confirmationDigest does not match the request.',
        );
      }
      final confirmation = await confirmationRepository.findByLocalDate(
        response.operationDate,
      );
      if (confirmation == null) {
        throw const ReportSyncException(
          ReportSyncIssueCode.confirmationDigestMismatch,
          'The operation date is not confirmed.',
        );
      }
      final current = ReportSyncCanonicalService.digest(confirmation.toJson());
      if (current != response.confirmationDigest) {
        throw const ReportSyncException(
          ReportSyncIssueCode.confirmationDigestMismatch,
          'The current confirmation digest differs.',
        );
      }
    }
  }

  void validatePayload(ReportSyncEnvelope envelope) {
    payloadRegistry.validate(envelope);
    if (ReportSyncCanonicalService.digest(envelope.payload).isEmpty) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Payload digest failed.',
      );
    }
  }
}
