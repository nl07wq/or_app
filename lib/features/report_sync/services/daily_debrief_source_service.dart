import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../../daily_aggregate/repository/daily_aggregate_repository.dart';
import '../../daily_aggregate/services/recent_context_builder.dart';
import '../../daily_log_confirmation/models/daily_log_confirmation_lifecycle.dart';
import '../../daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../../daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../../operation_date/repository/operation_state_repository.dart';
import '../../operation_date/models/operation_state.dart';
import '../models/daily_debrief_record.dart';
import '../models/morning_brief_record.dart';
import '../repository/morning_brief_repository.dart';
import 'report_sync_canonical_service.dart';

class DailyDebriefSourceException implements Exception {
  final String code;
  final String message;

  const DailyDebriefSourceException(this.code, this.message);

  @override
  String toString() => message;
}

class DailyDebriefSourcePackage {
  final String operationDate;
  final DailyDebriefSources references;
  final Map<String, Object?> promptSource;

  const DailyDebriefSourcePackage({
    required this.operationDate,
    required this.references,
    required this.promptSource,
  });
}

class DailyDebriefSourceService {
  final DailyAggregateRepository dailyAggregates;
  final RecentContextBuilder recentContextBuilder;
  final DailyLogConfirmationLifecycleStore confirmations;
  final MorningBriefRepository morningBriefs;
  final OperationStateRepository operationState;

  const DailyDebriefSourceService({
    required this.dailyAggregates,
    required this.recentContextBuilder,
    required this.confirmations,
    required this.morningBriefs,
    required this.operationState,
  });

  Future<DailyDebriefSourcePackage> requireEligible(String localDate) async {
    final aggregate = await dailyAggregates.getByDate(localDate);
    if (aggregate == null) {
      throw const DailyDebriefSourceException(
        'dailyAggregateMissing',
        'DAILY AGGREGATEが存在しません。',
      );
    }
    if (aggregate.operationDate != localDate ||
        aggregate.sourceType != DailyAggregateSourceType.records) {
      throw const DailyDebriefSourceException(
        'dailyAggregateInvalid',
        'records DAILY AGGREGATEが必要です。',
      );
    }
    final confirmation = await confirmations.findPersistedByLocalDate(
      localDate,
    );
    if (confirmation == null) {
      throw const DailyDebriefSourceException(
        'confirmationMissing',
        'CONFIRMATIONが存在しません。',
      );
    }
    if (!_isValidConfirmation(confirmation, localDate)) {
      throw const DailyDebriefSourceException(
        'confirmationInvalid',
        '対象日のCONFIRMATIONが有効な確定状態ではありません。',
      );
    }
    final morningBrief = await morningBriefs.readByLocalDate(localDate);
    final recentContext = await recentContextBuilder.build(
      targetDate: localDate,
      window: RecentContextWindow.dailyDebrief,
    );
    final references = DailyDebriefSources(
      dailyAggregate: DailyDebriefDailyAggregateReference(
        operationDate: localDate,
        sourceType: aggregate.sourceType.name,
        recordDigest: ReportSyncCanonicalService.digest(aggregate.toJson()),
      ),
      confirmation: DailyDebriefConfirmationReference(
        recordId: confirmation.id,
        recordVersion: confirmation.recordVersion,
        revision: confirmation.projectedRevision,
        snapshotDigest: confirmation.projectedSnapshotDigest,
        recordDigest: ReportSyncCanonicalService.digest(
          confirmation.toRecord(),
        ),
      ),
      morningBrief: morningBrief == null
          ? null
          : DailyDebriefMorningBriefReference(
              localDate: morningBrief.localDate,
              recordVersion: morningBrief.recordVersion,
              responseDigest: morningBrief.responseDigest,
              recordDigest: ReportSyncCanonicalService.digest(
                morningBrief.toRecord(),
              ),
            ),
    );
    return DailyDebriefSourcePackage(
      operationDate: localDate,
      references: references,
      promptSource: {
        'operationDate': localDate,
        'dailyAggregate': aggregate.toJson(),
        'recentContext': recentContext.toJson(),
        'confirmation': {
          'recordId': confirmation.id,
          'recordVersion': confirmation.recordVersion,
          'revision': confirmation.projectedRevision,
          'snapshotDigest': confirmation.projectedSnapshotDigest,
        },
        'morningBrief': _morningBriefProjection(morningBrief),
      },
    );
  }

  Future<List<String>> eligibleDates() async {
    final aggregates = await dailyAggregates.getRange(
      '0001-01-01',
      '9999-12-31',
    );
    final confirmationsByDate = {
      for (final value in await confirmations.findAllPersisted())
        value.localDate: value,
    };
    final result = <String>[];
    for (final aggregate in aggregates) {
      final confirmation = confirmationsByDate[aggregate.operationDate];
      if (aggregate.sourceType == DailyAggregateSourceType.records &&
          confirmation != null &&
          _isValidConfirmation(confirmation, aggregate.operationDate)) {
        result.add(aggregate.operationDate);
      }
    }
    result.sort((a, b) => b.compareTo(a));
    return List.unmodifiable(result);
  }

  Future<String?> defaultEligibleDate() async {
    final eligible = await eligibleDates();
    final state = await operationState.requireCurrent();
    if (state.phase == OperationPhase.awaitingDebrief &&
        eligible.contains(state.operationDate.value)) {
      return state.operationDate.value;
    }
    final lastFinalized = state.lastFinalizedDate?.value;
    if (lastFinalized != null && eligible.contains(lastFinalized)) {
      return lastFinalized;
    }
    return eligible.isEmpty ? null : eligible.first;
  }

  Future<DailyDebriefLifecycleStatus> projectLifecycle(
    DailyDebriefRecord record,
  ) async {
    try {
      final current = await requireEligible(record.localDate);
      return ReportSyncCanonicalService.encode(current.references.toJson()) ==
              ReportSyncCanonicalService.encode(record.sources.toJson())
          ? DailyDebriefLifecycleStatus.active
          : DailyDebriefLifecycleStatus.stale;
    } on DailyDebriefSourceException catch (error) {
      return error.code == 'dailyAggregateMissing' ||
              error.code == 'confirmationMissing'
          ? DailyDebriefLifecycleStatus.invalidated
          : DailyDebriefLifecycleStatus.stale;
    }
  }

  static bool _isValidConfirmation(
    PersistedDailyLogConfirmationRecord value,
    String localDate,
  ) =>
      value.id == 'confirmation:$localDate' &&
      value.localDate == localDate &&
      value.data.date.toIso8601String().substring(0, 10) == localDate &&
      value.projectedLifecycleStatus ==
          DailyLogConfirmationLifecycleStatus.finalized;

  static Map<String, Object?>? _morningBriefProjection(
    MorningBriefRecord? value,
  ) => value == null
      ? null
      : {
          'operationStatus': value.operationStatus.stableId,
          'commanderIntent': value.commanderIntent,
          'actions': [for (final action in value.actions) action.toJson()],
        };
}
