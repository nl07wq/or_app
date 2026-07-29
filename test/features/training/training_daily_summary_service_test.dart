import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/services/training_daily_summary_service.dart';

import 'training_v2_calculation_test_fixture.dart';

void main() {
  test('keeps v1-only summary on the Legacy set contract', () {
    final summary = TrainingDailySummaryService.calculate(
      preferredRecords: [
        v1Record(
          id: 'v1',
          createdAt: DateTime.utc(2026, 7, 30, 8),
          memo: 'Legacy',
          sets: const [
            TrainingSet(setNo: 1, weight: 50, reps: 10),
            TrainingSet(setNo: 2, weight: 60, reps: 8),
          ],
          cardioCount: 1,
        ),
      ],
      localDate: '2026-07-30',
    );

    expect(summary.sessionCount, 1);
    expect(summary.v2SessionCount, 0);
    expect(summary.exerciseCount, 1);
    expect(summary.legacySetCount, 2);
    expect(summary.mainSetCount, 0);
    expect(summary.displaySetCount, 2);
    expect(summary.cardioEntryCount, 1);
  });

  test('counts only Main Sets for v2 daily summary', () {
    final summary = TrainingDailySummaryService.calculate(
      preferredRecords: [
        v2Record(
          id: 'v2',
          createdAt: DateTime.utc(2026, 7, 30, 9),
          sessionName: 'Upper',
          grade: null,
          exercises: [
            v2Exercise(
              sets: [
                v2Set(
                  setNo: 1,
                  type: TrainingSetType.warmUp,
                  weight: 20,
                  reps: 10,
                ),
                v2Set(
                  setNo: 2,
                  type: TrainingSetType.main,
                  weight: 80,
                  reps: 8,
                ),
                v2Set(
                  setNo: 3,
                  type: TrainingSetType.legacyUnknown,
                  weight: 90,
                  reps: 8,
                ),
              ],
            ),
          ],
          cardioEntries: [
            CardioEntryV2(
              purpose: CardioPurpose.main,
              type: CardioType.running,
              durationSeconds: 600,
            ),
          ],
        ),
      ],
      localDate: '2026-07-30',
    );

    expect(summary.v2SessionCount, 1);
    expect(summary.mainSetCount, 1);
    expect(summary.displaySetCount, 1);
    expect(summary.cardioEntryCount, 1);
    expect(summary.sessionNames, ['Upper']);
  });

  test('aggregates multiple preferred sessions without lineage guessing', () {
    final summary = TrainingDailySummaryService.calculate(
      preferredRecords: [
        v2Record(
          id: 'shadow',
          createdAt: DateTime.utc(2026, 7, 30, 9),
          sessionName: 'Upper',
          exercises: [
            v2Exercise(
              sets: [
                v2Set(
                  setNo: 1,
                  type: TrainingSetType.main,
                  weight: 80,
                  reps: 8,
                ),
              ],
            ),
          ],
        ),
        v1Record(
          id: 'different-lineage',
          createdAt: DateTime.utc(2026, 7, 30, 11),
          memo: 'Legacy Session',
          sets: const [TrainingSet(setNo: 1, weight: 50, reps: 10)],
        ),
      ],
      localDate: '2026-07-30',
    );

    expect(summary.sessionCount, 2);
    expect(summary.exerciseCount, 2);
    expect(summary.mainSetCount, 1);
    expect(summary.legacySetCount, 1);
    expect(summary.displaySetCount, 1);
    expect(summary.toDashboardSummary()?.sessionName, '2 sessions');
  });

  test('does not count records from another date', () {
    final summary = TrainingDailySummaryService.calculate(
      preferredRecords: [
        v1Record(
          id: 'yesterday',
          localDate: '2026-07-29',
          createdAt: DateTime.utc(2026, 7, 29),
        ),
      ],
      localDate: '2026-07-30',
    );

    expect(summary.recorded, isFalse);
    expect(summary.toDashboardSummary(), isNull);
  });
}
