import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/services/daily_log_confirmation_validation.dart';
import 'package:or_app/features/command_center/models/daily_command_read_model.dart';
import 'package:or_app/features/command_center/services/daily_command_read_model_builder.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';

void main() {
  group('DailyCommandReadModelBuilder', () {
    test('derives STANDBY and required module states without STATUS', () {
      final model = _build();

      expect(model.cycleState, DailyCommandCycleState.standby);
      expect(model.operationStatus, isNull);
      expect(model.statusModuleState, DailyCommandModuleState.missing);
      expect(model.foodModuleState, DailyCommandModuleState.missing);
      expect(
        model.trainingModuleState,
        DailyCommandModuleState.optionalMissing,
      );
      expect(model.activityModuleState, DailyCommandModuleState.missing);
      expect(model.canPrepareDailyDebrief, isFalse);
    });

    test('derives ACTIVE from the shared validation result', () {
      final model = _build(status: _status());

      expect(model.cycleState, DailyCommandCycleState.active);
      expect(model.statusModuleState, DailyCommandModuleState.recorded);
      expect(model.finalizeBlockingReasons, [
        DailyLogModule.food,
        DailyLogModule.activity,
      ]);
    });

    test('task088: current-date Morning Brief owns all command content', () {
      final first = _build(status: _status(), morningBrief: _morningBrief());
      final afterOtherStatusUpdate = _build(
        status: _status(weight: 75),
        morningBrief: _morningBrief(),
      );

      for (final model in [first, afterOtherStatusUpdate]) {
        expect(model.operationStatus?.name, 'yellow');
        expect(model.statusReason, 'formal situation');
        expect(model.commanderIntent, 'formal intent');
        expect(model.morningBriefSummary, 'formal argo comment');
      }
    });

    test('task088: different-date records do not replace STANDBY', () {
      final model = _build(
        status: _status(),
        morningBrief: _morningBrief(localDate: '2026-07-31'),
      );

      expect(model.operationStatus, isNull);
      expect(model.statusReason, '当日のMORNING BRIEFが未登録です。');
      expect(model.commanderIntent, isNull);
      expect(model.morningBriefSummary, isNull);
    });

    test('derives REVIEW READY when required modules are valid', () {
      final model = _build(
        status: _status(),
        food: _food(),
        activity: _activity(),
      );

      expect(model.cycleState, DailyCommandCycleState.reviewReady);
      expect(model.canPrepareDailyDebrief, isTrue);
      expect(model.finalizeBlockingReasons, isEmpty);
      expect(model.estimatedTotalBurnKcal, 1760);
    });

    test('keeps invalid optional TRAINING as a blocker', () {
      final model = _build(
        status: _status(),
        food: _food(),
        activity: _activity(),
        training: const TrainingSummary(
          completed: false,
          exerciseCount: 0,
          setCount: 0,
          duration: null,
          sessionName: null,
        ),
      );

      expect(model.trainingModuleState, DailyCommandModuleState.invalid);
      expect(model.finalizeBlockingReasons, [DailyLogModule.training]);
    });

    test('maps finalizing to FINALIZING', () {
      final model = _build(phase: OperationPhase.finalizing);
      expect(model.cycleState, DailyCommandCycleState.finalizing);
      expect(model.canPrepareDailyDebrief, isFalse);
    });

    test('maps awaiting debrief without review or recovery semantics', () {
      final model = _build(phase: OperationPhase.awaitingDebrief);

      expect(model.cycleState, DailyCommandCycleState.awaitingDebrief);
      expect(model.canPrepareDailyDebrief, isFalse);
      expect(model.recoveryRequired, isFalse);
    });

    for (final phase in [
      OperationPhase.finalizedPendingBackup,
      OperationPhase.advancing,
    ]) {
      test('maps ${phase.name} to RECOVERY REQUIRED', () {
        final model = _build(phase: phase);
        expect(model.cycleState, DailyCommandCycleState.recoveryRequired);
        expect(model.recoveryRequired, isTrue);
      });
    }

    test('historical view disables finalization', () {
      final model = _build(
        status: _status(),
        food: _food(),
        activity: _activity(),
        isHistoricalView: true,
      );
      expect(model.cycleState, DailyCommandCycleState.reviewReady);
      expect(model.canPrepareDailyDebrief, isFalse);
    });
  });
}

DailyCommandReadModel _build({
  MorningFact? status,
  FoodSummary? food,
  TrainingSummary? training,
  ActivitySummary activity = const ActivitySummary.empty(),
  OperationPhase phase = OperationPhase.open,
  bool isHistoricalView = false,
  MorningBriefRecord? morningBrief,
}) {
  final date = OperationLocalDate.parse('2026-08-01');
  final now = DateTime.utc(2026, 8, 1);
  final attempt = phase == OperationPhase.open
      ? null
      : OperationActiveAttempt(
          idempotencyKey: 'daily-finalize:${date.value}',
          targetLocalDate: date,
          startedAt: now,
          confirmationId: phase == OperationPhase.finalizing ? null : 'c1',
          confirmationDigest: phase == OperationPhase.finalizing ? null : 'd1',
          backupPackageDigest: phase == OperationPhase.advancing ? 'b1' : null,
          backupGeneratedAt: phase == OperationPhase.advancing ? now : null,
        );
  return DailyCommandReadModelBuilder.build(
    operationState: OperationState(
      operationDate: date,
      phase: phase,
      activeAttempt: attempt,
      createdAt: now,
      updatedAt: now,
    ),
    status: status,
    food: food,
    training: training,
    activity: activity,
    morningBrief: morningBrief,
    isHistoricalView: isHistoricalView,
  );
}

MorningBriefRecord _morningBrief({String localDate = '2026-08-01'}) =>
    MorningBriefRecord(
      localDate: localDate,
      requestId: 'request-1',
      requestDigest:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      responseDigest:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      generatedAt: DateTime.utc(2026, 8, 1),
      importedAt: DateTime.utc(2026, 8, 1),
      situationAnalysis: 'formal situation',
      operationStatus: MorningBriefOperationStatus.yellow,
      commanderIntent: 'formal intent',
      argoComment: 'formal argo comment',
      strategicResourceDecision: 'formal resource decision',
      actions: const [],
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    );

MorningFact _status({double weight = 80}) => MorningFact(
  date: DateTime(2026, 8, 1),
  weight: weight,
  bodyFat: 20,
  sleepDuration: const Duration(hours: 8),
  sleepScore: 80,
  workHours: 0,
  footPain: 0,
  medications: const [],
  freeNotes: null,
);

FoodSummary _food() => const FoodSummary(
  calories: 1800,
  protein: 100,
  fat: 60,
  carbohydrates: 200,
  hydrationMl: 2000,
  mealCount: 3,
);

ActivitySummary _activity() => const ActivitySummary(
  steps: 5000,
  measuredSteps: 5000,
  isRecorded: true,
  calculationBasis: ActivityCalculationBasis(
    rawSteps: 5000,
    currentCarryOver: 0,
    previousCarryOverDeduction: 0,
    officialSteps: 5000,
  ),
);
