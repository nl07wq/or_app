import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/services/training_history_overview_adapter.dart';

void main() {
  const adapter = TrainingHistoryOverviewAdapter();

  test(
    'derives chronological recorded overview metrics from formal records',
    () {
      final overview = adapter.build([
        _record('later', '2026-08-10', weight: 20, reps: 5),
        _record('earlier', '2026-08-03', weight: 10, reps: 3),
      ], period: TrainingHistoryOverviewPeriod.all);

      expect(overview.sessionCount, 2);
      expect(overview.trainingDays, 2);
      expect(overview.recordedVolume, 130);
      expect(overview.recordedReps, 8);
      expect(overview.points.map((point) => point.date.day), [3, 10]);
      expect(overview.points.map((point) => point.recordedSetCount), [1, 1]);
      expect(overview.frequencyPoints.map((point) => point.sessions), [1, 1]);
    },
  );

  test(
    'period selection uses formal operation dates and returns no fake points',
    () {
      final overview = adapter.build(
        [
          _record('old', '2026-06-01', weight: 10, reps: 1),
          _record('latest', '2026-08-01', weight: 0, reps: 0),
        ],
        period: TrainingHistoryOverviewPeriod.oneWeek,
        referenceDate: DateTime(2026, 8, 1),
      );

      expect(overview.sessionCount, 1);
      expect(overview.points.single.recordedVolume, 0);
      expect(overview.points.single.recordedReps, 0);
    },
  );

  test('excludes cardio-only records but retains mixed strength records', () {
    final overview = adapter.build(
      [
        _record('strength', '2026-08-03', weight: 10, reps: 3),
        _cardioOnly('cardio', '2026-08-04'),
        _record('mixed', '2026-08-05', weight: 20, reps: 5, cardio: true),
      ],
      period: TrainingHistoryOverviewPeriod.all,
      referenceDate: DateTime(2026, 8, 9),
    );

    expect(overview.sessionCount, 2);
    expect(overview.trainingDays, 2);
    expect(overview.recordedVolume, 130);
    expect(overview.recordedReps, 8);
    expect(overview.points.map((point) => point.date.day), [3, 5]);
    expect(
      overview.frequencyPoints
          .where((point) => point.weekStart.day == 3)
          .single
          .sessions,
      2,
    );
  });

  test('includes zero-strength weeks in the weekly frequency series', () {
    final overview = adapter.build(
      [_record('strength', '2026-08-03', weight: 10, reps: 3)],
      period: TrainingHistoryOverviewPeriod.oneMonth,
      referenceDate: DateTime(2026, 8, 30),
    );

    expect(overview.frequencyPoints.map((point) => point.sessions), [
      0,
      1,
      0,
      0,
      0,
    ]);
  });

  test('uses Body History-equivalent 15-day and custom formal-date ranges', () {
    final records = [
      _record('old', '2026-07-19', weight: 10, reps: 1),
      _record('included', '2026-07-20', weight: 20, reps: 2),
      _record('custom', '2026-08-04', weight: 30, reps: 3),
    ];

    final fifteenDays = adapter.build(
      records,
      period: TrainingHistoryOverviewPeriod.fifteenDays,
      referenceDate: DateTime(2026, 8, 3),
    );
    expect(fifteenDays.points.map((point) => point.date.day), [20]);

    final custom = adapter.build(
      records,
      period: TrainingHistoryOverviewPeriod.custom,
      referenceDate: DateTime(2026, 8, 10),
      customRange: DateTimeRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 5),
      ),
    );
    expect(custom.points.map((point) => point.date.day), [4]);
  });
}

TrainingRecordReadModel _record(
  String id,
  String localDate, {
  required double weight,
  required int reps,
  bool cardio = false,
}) => TrainingRecordReadModel.v1(
  id: id,
  localDate: localDate,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  data: TrainingSession(
    date: '${localDate}T00:00:00.000',
    memo: '',
    exercises: [
      TrainingExercise(
        exerciseName: 'Bench Press',
        order: 1,
        sets: [TrainingSet(setNo: 1, weight: weight, reps: reps)],
      ),
    ],
    cardioEntries: cardio ? [_cardio()] : const [],
  ),
);

TrainingRecordReadModel _cardioOnly(String id, String localDate) =>
    TrainingRecordReadModel.v1(
      id: id,
      localDate: localDate,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      data: TrainingSession(
        date: '${localDate}T00:00:00.000',
        memo: '',
        exercises: const [],
        cardioEntries: [_cardio()],
      ),
    );

CardioEntry _cardio() => CardioEntry(
  type: CardioType.walking,
  intensity: CardioIntensity.light,
  durationMinutes: 20,
);
