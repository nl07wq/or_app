import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/services/training_exercise_identity.dart';
import 'package:or_app/features/training/services/training_history_domain_service.dart';

void main() {
  const service = TrainingHistoryDomainService();

  test('ships the approved Recovery Reference Policy V1 table', () {
    const policy = RecoveryReferencePolicy();

    expect(policy.policyVersion, RecoveryReferencePolicy.policyVersionV1);
    expect(policy.referenceDurations, hasLength(11));
    for (final muscle in [
      MuscleGroup.chest,
      MuscleGroup.back,
      MuscleGroup.shoulders,
      MuscleGroup.biceps,
      MuscleGroup.triceps,
      MuscleGroup.forearms,
      MuscleGroup.core,
      MuscleGroup.calves,
    ]) {
      expect(policy.durationFor(muscle), const Duration(hours: 48));
    }
    for (final muscle in [
      MuscleGroup.quadriceps,
      MuscleGroup.hamstrings,
      MuscleGroup.glutes,
    ]) {
      expect(policy.durationFor(muscle), const Duration(hours: 72));
    }
  });

  test('separates v2 main working volume from recorded volume and RPE', () {
    final aggregate = service.sessionAggregate(_v2());

    expect(aggregate.workingVolume, 800);
    expect(aggregate.recordedVolume, 1000);
    expect(aggregate.workingSetCount, 1);
    expect(aggregate.recordedSetCount, 2);
    expect(aggregate.recordedReps, 15);
    expect(aggregate.recordedRpeAverage, 8);
    expect(aggregate.recordedRpeMax, 8);
    expect(aggregate.duration, const Duration(hours: 1));
  });

  test(
    'v1 has recorded metrics but no working classification or exact time',
    () {
      final aggregate = service.sessionAggregate(_v1());

      expect(aggregate.recordedVolume, 500);
      expect(aggregate.workingVolume, isNull);
      expect(aggregate.workingSetCount, isNull);
      expect(aggregate.startTime, isNull);
      expect(aggregate.recordedRpeAverage, isNull);
    },
  );

  test(
    'registry uses canonical exercise identity and preserves secondary data',
    () {
      final point = service.exerciseHistory([_v2()]).single;
      final mapping = ExerciseMuscleRegistry.resolve(point.identity);

      expect(point.maxWeight, 80);
      expect(point.recordedReps, 15);
      expect(point.recordedVolume, 1000);
      expect(mapping?.primaryMuscles, [MuscleGroup.chest]);
      expect(mapping?.secondaryMuscles, contains(MuscleGroup.triceps));
      expect(
        ExerciseMuscleRegistry.resolve(
          TrainingExerciseIdentity.fromV1(
            exerciseName: 'Custom Unknown',
            equipmentId: null,
          ),
        ),
        isNull,
      );
    },
  );

  test('uses only formally recorded exercise RPE values in the average', () {
    final record = TrainingRecordReadModel.v2(
      id: 'partial-rpe',
      localDate: '2026-08-04',
      createdAt: DateTime.utc(2026, 8, 4),
      updatedAt: DateTime.utc(2026, 8, 4),
      data: TrainingSessionV2(
        date: '2026-08-04T00:00:00.000',
        exercises: [
          TrainingExerciseV2(
            exerciseName: 'Bench Press',
            order: 1,
            sets: [
              TrainingSetV2(
                setNo: 1,
                setType: TrainingSetType.warmUp,
                weightKg: 40,
                reps: 5,
              ),
              TrainingSetV2(
                setNo: 2,
                setType: TrainingSetType.main,
                weightKg: 80,
                reps: 10,
                rpe: 8,
              ),
              TrainingSetV2(
                setNo: 3,
                setType: TrainingSetType.main,
                weightKg: 80,
                reps: 8,
                rpe: 9,
              ),
            ],
          ),
        ],
      ),
    );

    final point = service.exerciseHistory([record]).single;

    expect(point.workingVolume, 1440);
    expect(point.workingSetCount, 2);
    expect(point.recordedRpeAverage, 8.5);
    expect(point.recordedRpeMax, 9);
  });

  test(
    'recovery uses latest exact primary exposure and never uses secondary',
    () {
      final policy = RecoveryReferencePolicy(
        referenceDurations: {MuscleGroup.chest: const Duration(hours: 72)},
      );
      final recovery = TrainingHistoryDomainService(recoveryPolicy: policy)
          .recoveryEstimate(MuscleGroup.chest, [
            _v1(),
            _v2(),
          ], now: DateTime.parse('2026-08-04T04:00:00+09:00'));

      expect(recovery.precision, RecoveryPrecision.exact);
      expect(recovery.referenceProgressRatio, closeTo(.25, .0001));
      expect(recovery.status, RecoveryStatus.recovering);
      expect(
        recovery.estimatedReadyAt,
        DateTime.parse('2026-08-06T10:00:00+09:00'),
      );
    },
  );

  test(
    'date-only exposure keeps the policy but returns no precise recovery',
    () {
      final recovery = service.recoveryEstimate(MuscleGroup.chest, [
        _v1(),
      ], now: DateTime.parse('2026-08-04T04:00:00+09:00'));

      expect(recovery.precision, RecoveryPrecision.dateOnly);
      expect(recovery.status, RecoveryStatus.noData);
      expect(recovery.referenceProgressRatio, isNull);
      expect(recovery.referenceRecoveryDuration, const Duration(hours: 48));
    },
  );

  test('missing policy preserves a formal exact exposure time', () {
    const noPolicy = TrainingHistoryDomainService(
      recoveryPolicy: RecoveryReferencePolicy(referenceDurations: {}),
    );
    final recovery = noPolicy.recoveryEstimate(MuscleGroup.chest, [
      _v2(),
    ], now: DateTime(2026, 8, 4));

    expect(
      recovery.lastExposureDateTime,
      DateTime.parse('2026-08-03T10:00:00+09:00'),
    );
    expect(recovery.precision, RecoveryPrecision.exact);
    expect(recovery.referenceProgressRatio, isNull);
  });

  test('uses V1 progress thresholds and caps display progress', () {
    final exposure = _v2();
    final cases =
        <({DateTime now, RecoveryStatus status, double raw, double displayed})>[
          (
            now: DateTime.parse('2026-08-03T10:00:00+09:00'),
            status: RecoveryStatus.loaded,
            raw: 0,
            displayed: 0,
          ),
          (
            now: DateTime.parse('2026-08-03T21:59:00+09:00'),
            status: RecoveryStatus.loaded,
            raw: 0.24965,
            displayed: 0.24965,
          ),
          (
            now: DateTime.parse('2026-08-03T22:00:00+09:00'),
            status: RecoveryStatus.recovering,
            raw: .25,
            displayed: .25,
          ),
          (
            now: DateTime.parse('2026-08-04T22:00:00+09:00'),
            status: RecoveryStatus.nearReady,
            raw: .75,
            displayed: .75,
          ),
          (
            now: DateTime.parse('2026-08-05T10:00:00+09:00'),
            status: RecoveryStatus.estimatedReady,
            raw: 1,
            displayed: 1,
          ),
          (
            now: DateTime.parse('2026-08-06T10:00:00+09:00'),
            status: RecoveryStatus.estimatedReady,
            raw: 1.5,
            displayed: 1,
          ),
        ];
    for (final entry in cases) {
      final recovery = service.recoveryEstimate(MuscleGroup.chest, [
        exposure,
      ], now: entry.now);
      expect(recovery.status, entry.status);
      expect(recovery.referenceProgressRatio, closeTo(entry.raw, .001));
      expect(recovery.displayProgressRatio, closeTo(entry.displayed, .001));
    }
  });

  test('future formal exposure is unavailable rather than zero progress', () {
    final recovery = service.recoveryEstimate(MuscleGroup.chest, [
      _v2(),
    ], now: DateTime.parse('2026-08-03T09:59:00+09:00'));

    expect(recovery.precision, RecoveryPrecision.invalid);
    expect(recovery.status, RecoveryStatus.noData);
    expect(recovery.elapsedDuration, isNull);
    expect(recovery.referenceProgressRatio, isNull);
    expect(recovery.displayProgressRatio, isNull);
    expect(recovery.estimatedReadyAt, isNull);
  });
}

TrainingRecordReadModel _v2() => TrainingRecordReadModel.v2(
  id: 'v2',
  localDate: '2026-08-03',
  createdAt: DateTime.utc(2026, 8, 3),
  updatedAt: DateTime.utc(2026, 8, 3),
  data: TrainingSessionV2(
    date: '2026-08-03T00:00:00.000',
    startTime: '2026-08-03T10:00:00+09:00',
    endTime: '2026-08-03T11:00:00+09:00',
    exercises: [
      TrainingExerciseV2(
        exerciseName: 'Bench Press',
        order: 1,
        sets: [
          TrainingSetV2(
            setNo: 1,
            setType: TrainingSetType.warmUp,
            weightKg: 40,
            reps: 5,
          ),
          TrainingSetV2(
            setNo: 2,
            setType: TrainingSetType.main,
            weightKg: 80,
            reps: 10,
            rpe: 8,
          ),
        ],
      ),
    ],
  ),
);

TrainingRecordReadModel _v1() => TrainingRecordReadModel.v1(
  id: 'v1',
  localDate: '2026-08-02',
  createdAt: DateTime.utc(2026, 8, 2),
  updatedAt: DateTime.utc(2026, 8, 2),
  data: TrainingSession(
    date: '2026-08-02T00:00:00.000',
    memo: '',
    exercises: [
      TrainingExercise(
        exerciseName: 'Bench Press',
        order: 1,
        sets: [const TrainingSet(setNo: 1, weight: 50, reps: 10)],
      ),
    ],
  ),
);
