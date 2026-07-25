import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/features/activity/services/activity_summary_engine.dart';

void main() {
  const engine = ActivitySummaryEngine();

  test('empty data produces an unrecorded summary', () {
    const summary = ActivitySummary.empty();
    expect(summary.status, ActivitySummaryStatus.unrecorded);
    expect(summary.isRecorded, isFalse);
  });

  test('calculates current and previous carryover with signed net result', () {
    final positive = engine.generate(
      record: ActivityData(
        date: DateTime(2026, 7, 25),
        measuredSteps: 8000,
        carryOver: 2000,
        plannedWork: 'work',
        actualWork: 'completed',
        trainingStatus: ActivityTrainingStatus.completed,
        bowelMovement: const BowelMovementRecord.none(),
      ),
    );
    final negative = engine.generate(
      record: ActivityData(
        date: DateTime(2026, 7, 26),
        measuredSteps: 10000,
        carryOver: 1000,
        plannedWork: 'work',
        actualWork: 'completed',
        trainingStatus: ActivityTrainingStatus.skipped,
        bowelMovement: const BowelMovementRecord.none(),
      ),
      previousCarryOver: 3000,
    );

    expect(positive.officialSteps, 10000);
    expect(positive.calculationBasis?.netCarryOver, 2000);
    expect(negative.officialSteps, 8000);
    expect(negative.calculationBasis?.netCarryOver, -2000);
  });

  test(
    'does not infer unentered fields and emits machine-readable warnings',
    () {
      final record = ActivityData(
        date: DateTime(2026, 7, 25),
        stepsEntered: false,
        carryOverEntered: false,
      );

      final summary = engine.generate(record: record);

      expect(summary.status, ActivitySummaryStatus.incomplete);
      expect(summary.calculationBasis?.rawSteps, isNull);
      expect(summary.calculationBasis?.currentCarryOver, isNull);
      expect(summary.unconfirmedFields, contains('bowelMovement'));
      expect(
        summary.warnings.map((warning) => warning.code),
        contains(ActivitySummaryWarningCode.stepsUnconfirmed),
      );
      expect(
        () => summary.unconfirmedFields.add('invalid'),
        throwsUnsupportedError,
      );
      expect(record.stepsEntered, isFalse);
    },
  );

  test('distinguishes bowel none, recorded, and unconfirmed', () {
    const unconfirmed = BowelMovementRecord.unconfirmed();
    const none = BowelMovementRecord.none();
    final recorded = BowelMovementRecord.recorded(amount: 3, shape: 3);

    expect(unconfirmed.hasMovement, isNull);
    expect(none.hasMovement, isFalse);
    expect(recorded.hasMovement, isTrue);
    expect(recorded.amount, 3);
    expect(recorded.shape, 3);
  });

  test('same input produces the same summary without mutating the record', () {
    final record = ActivityData(
      date: DateTime(2026, 7, 25),
      measuredSteps: 8420,
      carryOver: 500,
      plannedWork: 'rest',
      actualWork: 'rest',
      trainingStatus: ActivityTrainingStatus.skipped,
      bowelMovement: const BowelMovementRecord.none(),
    );
    final before = record.toJson();

    final first = engine.generate(record: record).toJson();
    final second = engine.generate(record: record).toJson();

    expect(first, second);
    expect(record.toJson(), before);
  });
}
