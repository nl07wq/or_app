import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/services/training_history_domain_service.dart';
import 'package:or_app/features/training/services/training_history_overview_adapter.dart';
import 'package:or_app/features/training/services/training_recovery_evidence_adapter.dart';

void main() {
  const adapter = TrainingRecoveryEvidenceAdapter();

  test('uses the latest formal PRIMARY exposure and its exact start time', () {
    final evidence = adapter.evidence(
      [
        _v2('bench', '2026-08-01', '2026-08-01T10:00:00+09:00', 'Bench Press'),
        _v2('chest', '2026-08-03', '2026-08-03T20:14:00+09:00', 'Chest Press'),
      ],
      period: TrainingHistoryOverviewPeriod.all,
      now: DateTime.parse('2026-08-04T00:00:00+09:00'),
      referenceDate: DateTime(2026, 8, 4),
    );

    final chest = evidence.singleWhere(
      (item) => item.estimate.muscleGroup == MuscleGroup.chest,
    );
    expect(chest.estimate.lastExposureOperationDate, '2026-08-03');
    expect(
      chest.estimate.lastExposureDateTime,
      DateTime.parse('2026-08-03T20:14:00+09:00'),
    );
    expect(chest.estimate.precision, RecoveryPrecision.exact);
    expect(chest.source.exerciseLabel, 'チェストプレス');
    expect(chest.estimate.referenceRecoveryDuration, const Duration(hours: 48));
  });

  test('preserves date-only precision without createdAt fallback', () {
    final evidence = adapter
        .evidence(
          [_v1('date-only', '2026-08-03', 'Bench Press')],
          period: TrainingHistoryOverviewPeriod.all,
          now: DateTime(2026, 8, 4),
          referenceDate: DateTime(2026, 8, 4),
        )
        .single;

    expect(evidence.estimate.lastExposureOperationDate, '2026-08-03');
    expect(evidence.estimate.lastExposureDateTime, isNull);
    expect(evidence.estimate.precision, RecoveryPrecision.dateOnly);
  });

  test('does not turn secondary-only mappings into recovery evidence', () {
    final evidence = adapter.evidence(
      [
        _v2('bench', '2026-08-01', '2026-08-01T10:00:00+09:00', 'Bench Press'),
        _v2(
          'shoulder',
          '2026-08-02',
          '2026-08-02T10:00:00+09:00',
          'Shoulder Press',
        ),
      ],
      period: TrainingHistoryOverviewPeriod.all,
      now: DateTime(2026, 8, 4),
      referenceDate: DateTime(2026, 8, 4),
    );

    expect(
      evidence.where(
        (item) => item.estimate.muscleGroup == MuscleGroup.triceps,
      ),
      isEmpty,
    );
    expect(
      evidence
          .singleWhere((item) => item.estimate.muscleGroup == MuscleGroup.chest)
          .estimate
          .lastExposureOperationDate,
      '2026-08-01',
    );
  });

  test('filters evidence by the selected formal operation-date period', () {
    final evidence = adapter.evidence(
      [_v1('older', '2026-08-01', 'Bench Press')],
      period: TrainingHistoryOverviewPeriod.oneWeek,
      now: DateTime(2026, 8, 20),
      referenceDate: DateTime(2026, 8, 20),
    );

    expect(evidence, isEmpty);
  });

  test(
    'derives latest SUPPORT involvement without creating recovery evidence',
    () {
      final support = adapter.supportInvolvement(
        [
          _v2(
            'bench',
            '2026-08-01',
            '2026-08-01T10:00:00+09:00',
            'Bench Press',
          ),
          _v2(
            'press',
            '2026-08-03',
            '2026-08-03T20:14:00+09:00',
            'Shoulder Press',
          ),
        ],
        period: TrainingHistoryOverviewPeriod.all,
        referenceDate: DateTime(2026, 8, 4),
      );

      final triceps = support.singleWhere(
        (item) => item.muscle == MuscleGroup.triceps,
      );
      expect(triceps.operationDate, '2026-08-03');
      expect(triceps.startTime, DateTime.parse('2026-08-03T20:14:00+09:00'));
      expect(triceps.source.exerciseLabel, 'ショルダープレス');
      expect(
        adapter
            .evidence(
              [
                _v2(
                  'bench',
                  '2026-08-01',
                  '2026-08-01T10:00:00+09:00',
                  'Bench Press',
                ),
              ],
              period: TrainingHistoryOverviewPeriod.all,
              now: DateTime(2026, 8, 4),
              referenceDate: DateTime(2026, 8, 4),
            )
            .where((item) => item.estimate.muscleGroup == MuscleGroup.triceps),
        isEmpty,
      );
    },
  );

  test(
    'filters SUPPORT involvement by period and ignores unknown exercises',
    () {
      final records = [
        _v2('old', '2026-08-01', '2026-08-01T10:00:00+09:00', 'Bench Press'),
        _v2(
          'unknown',
          '2026-08-19',
          '2026-08-19T10:00:00+09:00',
          'Unknown Lift',
        ),
      ];

      final support = adapter.supportInvolvement(
        records,
        period: TrainingHistoryOverviewPeriod.oneWeek,
        referenceDate: DateTime(2026, 8, 20),
      );

      expect(support, isEmpty);
    },
  );

  test('treats all LEG PRESS lower-body muscles as recovery targets', () {
    final records = [
      _v2('leg-press', '2026-08-03', '2026-08-03T10:00:00+09:00', 'Leg Press'),
    ];
    final support = adapter.supportInvolvement(
      records,
      period: TrainingHistoryOverviewPeriod.all,
      referenceDate: DateTime(2026, 8, 4),
    );
    final evidence = adapter.evidence(
      records,
      period: TrainingHistoryOverviewPeriod.all,
      now: DateTime.parse('2026-08-03T12:00:00+09:00'),
      referenceDate: DateTime(2026, 8, 4),
    );

    expect(
      support.where((item) => item.muscle == MuscleGroup.hamstrings),
      isEmpty,
    );
    expect(
      evidence.map((item) => item.estimate.muscleGroup),
      containsAll([
        MuscleGroup.quadriceps,
        MuscleGroup.hamstrings,
        MuscleGroup.glutes,
      ]),
    );
  });

  test(
    'derives Lat Pulldown support from the registry without name guessing',
    () {
      final support = adapter.supportInvolvement(
        [
          _v2(
            'pulldown',
            '2026-08-03',
            '2026-08-03T10:00:00+09:00',
            'Lat Pulldown',
          ),
        ],
        period: TrainingHistoryOverviewPeriod.all,
        referenceDate: DateTime(2026, 8, 4),
      );

      expect(
        support.map((item) => item.muscle),
        containsAll([MuscleGroup.biceps, MuscleGroup.forearms]),
      );
    },
  );

  test(
    'uses LATS rather than legacy BACK for Lat Pulldown recovery evidence',
    () {
      final records = [
        _v2(
          'pulldown',
          '2026-08-03',
          '2026-08-03T10:00:00+09:00',
          'Lat Pulldown',
        ),
      ];
      final evidence = adapter.evidence(
        records,
        period: TrainingHistoryOverviewPeriod.all,
        now: DateTime.parse('2026-08-03T12:00:00+09:00'),
        referenceDate: DateTime(2026, 8, 4),
      );

      expect(
        evidence.map((item) => item.estimate.muscleGroup),
        contains(MuscleGroup.lats),
      );
      expect(
        evidence.map((item) => item.estimate.muscleGroup),
        isNot(contains(MuscleGroup.back)),
      );
    },
  );

  test('preserves date-only precision for SUPPORT involvement', () {
    final support = adapter.supportInvolvement(
      [_v1('date-only-support', '2026-08-03', 'Bench Press')],
      period: TrainingHistoryOverviewPeriod.all,
      referenceDate: DateTime(2026, 8, 4),
    );

    final triceps = support.singleWhere(
      (item) => item.muscle == MuscleGroup.triceps,
    );
    expect(triceps.operationDate, '2026-08-03');
    expect(triceps.startTime, isNull);
  });

  test('exposes future policy wiring without shipping a duration', () {
    final policyAdapter = TrainingRecoveryEvidenceAdapter(
      domain: TrainingHistoryDomainService(
        recoveryPolicy: RecoveryReferencePolicy(
          referenceDurations: {MuscleGroup.chest: const Duration(hours: 48)},
        ),
      ),
    );
    final evidence = policyAdapter
        .evidence(
          [
            _v2(
              'bench',
              '2026-08-03',
              '2026-08-03T10:00:00+09:00',
              'Bench Press',
            ),
          ],
          period: TrainingHistoryOverviewPeriod.all,
          now: DateTime.parse('2026-08-04T10:00:00+09:00'),
          referenceDate: DateTime(2026, 8, 4),
        )
        .single;

    expect(
      evidence.estimate.referenceRecoveryDuration,
      const Duration(hours: 48),
    );
  });
}

TrainingRecordReadModel _v1(String id, String date, String exerciseName) =>
    TrainingRecordReadModel.v1(
      id: id,
      localDate: date,
      createdAt: DateTime.utc(2030, 1, 1),
      updatedAt: DateTime.utc(2030, 1, 2),
      data: TrainingSession(
        date: '${date}T00:00:00.000',
        memo: '',
        exercises: [
          TrainingExercise(
            exerciseName: exerciseName,
            order: 1,
            sets: [const TrainingSet(setNo: 1, weight: 50, reps: 10)],
          ),
        ],
      ),
    );

TrainingRecordReadModel _v2(
  String id,
  String date,
  String startTime,
  String exerciseName,
) => TrainingRecordReadModel.v2(
  id: id,
  localDate: date,
  createdAt: DateTime.utc(2030, 1, 1),
  updatedAt: DateTime.utc(2030, 1, 2),
  data: TrainingSessionV2(
    date: '${date}T00:00:00.000',
    startTime: startTime,
    exercises: [
      TrainingExerciseV2(
        exerciseName: exerciseName,
        order: 1,
        sets: [
          TrainingSetV2(
            setNo: 1,
            setType: TrainingSetType.main,
            weightKg: 50,
            reps: 10,
          ),
        ],
      ),
    ],
  ),
);
