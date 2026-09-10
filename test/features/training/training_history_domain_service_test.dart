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

  test('date-only exposure and missing policy return no precise recovery', () {
    final recovery = service.recoveryEstimate(MuscleGroup.chest, [
      _v1(),
    ], now: DateTime.parse('2026-08-04T04:00:00+09:00'));

    expect(recovery.precision, RecoveryPrecision.dateOnly);
    expect(recovery.status, RecoveryStatus.noData);
    expect(recovery.referenceProgressRatio, isNull);
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
