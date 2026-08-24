import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
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

    await container.training.saveNewV2(TrainingSessionV2(date: '2026-08-25'));
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
        exercises: const [],
      ),
    );
