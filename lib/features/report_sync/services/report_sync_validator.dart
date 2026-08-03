import '../../daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../../operation_date/models/operation_state.dart';
import '../../operation_date/repository/operation_state_repository.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_issue.dart';
import '../repository/report_sync_history_repository.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_payload_registry.dart';

class ReportSyncValidator {
  final ReportSyncHistoryRepository historyRepository;
  final DailyLogConfirmationStore confirmationRepository;
  final OperationStateRepository operationStateRepository;
  final ReportSyncPayloadRegistry payloadRegistry;
  ReportSyncValidator({
    required this.historyRepository,
    required this.confirmationRepository,
    required this.operationStateRepository,
    ReportSyncPayloadRegistry? payloadRegistry,
  }) : payloadRegistry =
           payloadRegistry ?? ReportSyncPayloadRegistry.standard();

  Future<void> validateResponse(
    ReportSyncEnvelope response, {
    String? expectedOperationDate,
  }) async {
    if (response.direction != ReportSyncDirection.response) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'A response envelope is required.',
      );
    }
    final state = await operationStateRepository.requireCurrent();
    final expectedDate =
        expectedOperationDate ??
        (response.exchangeType == ReportSyncExchangeType.dailyDebrief
            ? state.lastFinalizedDate?.value
            : state.operationDate.value);
    if (expectedDate == null || expectedDate != response.operationDate) {
      throw const ReportSyncException(
        ReportSyncIssueCode.operationDateMismatch,
        'operationDate does not match the active exchange target.',
      );
    }
    if (response.exchangeType == ReportSyncExchangeType.morningBrief &&
        state.phase != OperationPhase.open) {
      throw const ReportSyncException(
        ReportSyncIssueCode.operationDateMismatch,
        'Morning Brief requires the open operation date.',
      );
    }
    payloadRegistry.validate(response);
    if (response.exchangeType == ReportSyncExchangeType.dailyDebrief) {
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
