import '../../daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_issue.dart';
import '../repository/report_sync_history_repository.dart';
import 'report_sync_canonical_service.dart';

class ReportSyncValidator {
  final ReportSyncHistoryRepository historyRepository;
  final DailyLogConfirmationStore confirmationRepository;
  const ReportSyncValidator({
    required this.historyRepository,
    required this.confirmationRepository,
  });

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
    _validatePayload(response);
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

  void _validatePayload(ReportSyncEnvelope envelope) {
    final allowed = switch ((envelope.exchangeType, envelope.direction)) {
      (ReportSyncExchangeType.training, ReportSyncDirection.request) => const {
        'facts',
      },
      (ReportSyncExchangeType.training, ReportSyncDirection.response) => const {
        'session',
      },
      (ReportSyncExchangeType.food, ReportSyncDirection.request) => const {
        'facts',
      },
      (ReportSyncExchangeType.food, ReportSyncDirection.response) => const {
        'dailyMeal',
      },
      (ReportSyncExchangeType.morningBrief, ReportSyncDirection.request) =>
        const {
          'morningFact',
          'currentDailyState',
          'operationStatus',
          'commanderIntentCandidates',
          'trainingStatus',
          'foodStatus',
          'activityStatus',
          'carryOver',
        },
      (ReportSyncExchangeType.morningBrief, ReportSyncDirection.response) =>
        const {
          'model',
          'generatedAt',
          'situationAnalysis',
          'operationStatus',
          'commanderIntent',
          'argoComment',
          'strategicResourceDecision',
          'actions',
        },
      (ReportSyncExchangeType.dailyDebrief, ReportSyncDirection.request) =>
        const {
          'confirmation',
          'snapshot',
          'dns',
          'training',
          'food',
          'activity',
          'status',
          'operationSummary',
        },
      (ReportSyncExchangeType.dailyDebrief, ReportSyncDirection.response) =>
        const {
          'model',
          'generatedAt',
          'dailySummary',
          'commanderIntentEvaluation',
          'successes',
          'issues',
          'nutritionEvaluation',
          'activityEvaluation',
          'trainingEvaluation',
          'recoveryEvaluation',
          'carryover',
          'tomorrowConsiderations',
        },
    };
    if (envelope.payload.keys.toSet().difference(allowed).isNotEmpty ||
        allowed.difference(envelope.payload.keys.toSet()).isNotEmpty) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'Payload sections do not match the exchange schema.',
      );
    }
    if (ReportSyncCanonicalService.digest(envelope.payload).isEmpty) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Payload digest failed.',
      );
    }
  }
}
