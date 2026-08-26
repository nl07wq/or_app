import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/features/command_center/services/daily_assessment_fact_loader.dart';
import 'package:or_app/features/command_center/services/training_readiness_fact_builder.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/models/active_training_draft.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/repository/indexed_db_active_training_draft_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test('uses end time for hours and falls back to calendar days', () {
    expect(
      TrainingReadinessFactBuilder.build(
        operationDate: '2026-08-25',
        currentTime: DateTime.parse('2026-08-25T12:00:00+09:00'),
        records: const [],
      ),
      isNull,
    );

    final precise = TrainingReadinessFactBuilder.build(
      operationDate: '2026-08-25',
      currentTime: DateTime.parse('2026-08-25T12:00:00+09:00'),
      records: [
        _record(
          '2026-08-23',
          startTime: '2026-08-23T18:00:00+09:00',
          endTime: '2026-08-23T19:00:00+09:00',
        ),
      ],
    )!;
    expect(precise.lastTraining.compactLabel, '41h');
    expect(precise.last7DaysSessionCount, 1);
    expect(precise.currentWeekSessionCount, 0);
    expect(precise.recentIntervals, isEmpty);

    final fallback = TrainingReadinessFactBuilder.build(
      operationDate: '2026-08-25',
      currentTime: DateTime.parse('2026-08-25T12:00:00+09:00'),
      records: [_legacyRecord('2026-08-23')],
    )!;
    expect(fallback.lastTraining.compactLabel, '2d');
  });

  test('counts D-6 through D, Monday week, streak, and three intervals', () {
    final facts = TrainingReadinessFactBuilder.build(
      operationDate: '2026-08-25',
      currentTime: DateTime.parse('2026-08-25T20:00:00+09:00'),
      records: [
        _record('2026-08-18'),
        _record('2026-08-19'),
        _record('2026-08-21'),
        _record('2026-08-23'),
        _record('2026-08-24'),
        _record('2026-08-25'),
      ],
    )!;

    expect(facts.last7DaysSessionCount, 5);
    expect(facts.currentWeekSessionCount, 2);
    expect(facts.consecutiveTrainingDays, 3);
    expect(facts.recentIntervals.map((value) => value.compactLabel), [
      '1d',
      '1d',
      '2d',
    ]);
  });

  test('uses formal end to next start for recent hour intervals', () {
    final facts = TrainingReadinessFactBuilder.build(
      operationDate: '2026-08-25',
      currentTime: DateTime.parse('2026-08-25T20:00:00+09:00'),
      records: [
        _record(
          '2026-08-20',
          startTime: '2026-08-20T08:00:00+09:00',
          endTime: '2026-08-20T10:00:00+09:00',
        ),
        _record(
          '2026-08-22',
          startTime: '2026-08-22T10:00:00+09:00',
          endTime: '2026-08-22T11:00:00+09:00',
        ),
      ],
    )!;

    expect(facts.recentIntervals.single.compactLabel, '48h');
  });

  test('uses only strength records for every readiness fact', () {
    final cardio21 = _cardioRecord('2026-08-21');
    final cardio23 = _cardioRecord('2026-08-23');
    final facts = TrainingReadinessFactBuilder.build(
      operationDate: '2026-08-25',
      currentTime: DateTime.parse('2026-08-25T20:00:00+09:00'),
      records: [
        _record('2026-08-20'),
        cardio21,
        cardio23,
        _record('2026-08-24'),
      ],
    )!;

    expect(facts.lastTraining.compactLabel, '1d');
    expect(facts.last7DaysSessionCount, 2);
    expect(facts.currentWeekSessionCount, 1);
    expect(facts.consecutiveTrainingDays, 1);
    expect(facts.recentIntervals.single.compactLabel, '4d');
    expect(cardio21.strengthTrainingPerformed, isFalse);
    expect(cardio21.cardioPerformed, isTrue);
    expect(cardio21.v2Data!.cardioEntries.single.estimatedCaloriesKcal, 49);
    expect(
      TrainingReadinessFactBuilder.build(
        operationDate: '2026-08-25',
        currentTime: DateTime.parse('2026-08-25T20:00:00+09:00'),
        records: [cardio21, cardio23],
      ),
      isNull,
    );
  });

  test('derives strength eligibility from both v1 and v2 records', () {
    final facts = TrainingReadinessFactBuilder.build(
      operationDate: '2026-08-25',
      currentTime: DateTime.parse('2026-08-25T20:00:00+09:00'),
      records: [_legacyRecord('2026-08-20'), _record('2026-08-24')],
    )!;

    expect(facts.last7DaysSessionCount, 2);
    expect(facts.recentIntervals.single.compactLabel, '4d');
  });

  test('loader excludes every draft and reflects only formal save', () async {
    final database = FakeIndexedDbDatabase();
    final container = AppRepositoryContainer.indexedDb(database);
    final state = await container.operationState.createInitial(
      OperationLocalDate.parse('2026-08-25'),
    );
    await IndexedDbActiveTrainingDraftRepository(database).save(
      ActiveTrainingDraft(
        operationDate: '2026-08-25',
        entryState: const {
          'sessionName': '',
          'sessionMemo': '',
          'overallEvaluation': '',
          'sessionGrade': null,
          'dynamicStretchCompleted': null,
          'cooldownStretchCompleted': null,
          'exercises': <Object?>[],
          'cardioEntries': <Object?>[],
        },
      ),
    );
    final loader = DailyAssessmentFactLoader(
      container,
      clock: () => DateTime.parse('2026-08-25T20:00:00+09:00'),
    );

    expect((await loader.load(state)).trainingReadiness, isNull);

    await container.training.saveNewV2(
      TrainingSessionV2(
        date: '2026-08-25',
        exercises: [TrainingExerciseV2(exerciseName: 'Squat', order: 1)],
      ),
    );
    final afterSave = (await loader.load(state)).trainingReadiness!;
    expect(afterSave.last7DaysSessionCount, 1);
    expect(afterSave.currentWeekSessionCount, 1);
  });
}

TrainingRecordReadModel _record(
  String localDate, {
  String? startTime,
  String? endTime,
}) => TrainingRecordReadModel.v2(
  id: 'training:$localDate:${startTime ?? 'no-time'}',
  localDate: localDate,
  createdAt: DateTime.parse('${localDate}T12:00:00Z'),
  updatedAt: DateTime.parse('${localDate}T12:00:00Z'),
  data: TrainingSessionV2(
    date: localDate,
    startTime: startTime,
    endTime: endTime,
    exercises: [TrainingExerciseV2(exerciseName: 'Squat', order: 1)],
  ),
);

TrainingRecordReadModel _legacyRecord(String localDate) =>
    TrainingRecordReadModel.v1(
      id: 'legacy-training:$localDate',
      localDate: localDate,
      createdAt: DateTime.parse('${localDate}T12:00:00Z'),
      updatedAt: DateTime.parse('${localDate}T12:00:00Z'),
      data: TrainingSession(
        date: localDate,
        memo: '',
        exercises: const [
          TrainingExercise(exerciseName: 'Squat', order: 1, sets: []),
        ],
      ),
    );

TrainingRecordReadModel _cardioRecord(String localDate) =>
    TrainingRecordReadModel.v2(
      id: 'cardio:$localDate',
      localDate: localDate,
      createdAt: DateTime.parse('${localDate}T12:00:00Z'),
      updatedAt: DateTime.parse('${localDate}T12:00:00Z'),
      data: TrainingSessionV2(
        date: localDate,
        cardioEntries: [
          CardioEntryV2(
            purpose: CardioPurpose.main,
            type: CardioType.walking,
            durationSeconds: 600,
            mets: 3.5,
            estimatedCaloriesKcal: 49,
            weightSnapshotKg: 80,
            calculationMethod: 'metsAcsmV1',
            calculationVersion: 1,
          ),
        ],
      ),
    );
