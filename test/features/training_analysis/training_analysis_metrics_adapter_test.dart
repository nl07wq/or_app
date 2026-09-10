import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training_analysis/services/training_analysis_metrics_adapter.dart';

void main() {
  const adapter = TrainingAnalysisMetricsAdapter();

  test('uses canonical v2 session and exercise metrics', () {
    final previous = _v2Record('previous', '2026-09-01', 60, rpe: 7);
    final target = _v2Record('target', '2026-09-02', 70, rpe: 8);

    final result = adapter.build(target: target, records: [target, previous]);
    final exercise = result.exercises.single;

    expect(result.session.duration, const Duration(hours: 1));
    expect(result.session.recordedSetCount, 2);
    expect(result.session.totalReps, 16);
    expect(result.session.recordedVolume, 840);
    expect(result.session.workingVolume, 560);
    expect(result.session.averageRpe, 8);
    expect(exercise.current.maxWeight, 70);
    expect(exercise.current.recordedVolume, 840);
    expect(exercise.current.workingVolume, 560);
    expect(exercise.previous?.maxWeight, 60);
    expect(exercise.recentHistory.single.operationDate, '2026-09-01');
  });

  test('keeps equipment variants separate and makes previous unavailable', () {
    final rack = _v2Record('rack', '2026-09-01', 60, equipment: 'rack');
    final machine = _v2Record(
      'machine',
      '2026-09-02',
      70,
      equipment: 'machine',
    );

    final result = adapter.build(target: machine, records: [machine, rack]);

    expect(result.exercises.single.previous, isNull);
    expect(result.exercises.single.equipmentLabel, isNotNull);
  });

  test('uses only the immediately previous occurrence for comparison', () {
    final oldest = _v2Record('oldest', '2026-08-30', 50);
    final previous = _v2Record('previous', '2026-09-01', 60);
    final target = _v2Record('target', '2026-09-02', 70);

    final result = adapter.build(
      target: target,
      records: [target, oldest, previous],
    );
    final exercise = result.exercises.single;

    expect(exercise.previous?.maxWeight, 60);
    expect(exercise.recentHistory.map((evidence) => evidence.operationDate), [
      '2026-09-01',
      '2026-08-30',
    ]);
  });

  test('does not turn an empty exercise into zero measurements', () {
    final target = TrainingRecordReadModel.v2(
      id: 'empty',
      localDate: '2026-09-02',
      createdAt: DateTime.utc(2026, 9, 2),
      updatedAt: DateTime.utc(2026, 9, 2),
      data: TrainingSessionV2(
        date: '2026-09-02T10:00:00+09:00',
        exercises: [TrainingExerciseV2(exerciseName: 'Bench Press', order: 1)],
      ),
    );

    final metrics = adapter.build(target: target, records: [target]);
    final exercise = metrics.exercises.single.current;

    expect(exercise.maxWeight, isNull);
    expect(exercise.totalReps, isNull);
    expect(exercise.recordedSetCount, isNull);
    expect(exercise.recordedVolume, isNull);
    expect(metrics.session.recordedVolume, isNull);
  });

  test('keeps v1-only metrics unavailable', () {
    final target = TrainingRecordReadModel.v1(
      id: 'legacy',
      localDate: '2026-09-02',
      createdAt: DateTime.utc(2026, 9, 2),
      updatedAt: DateTime.utc(2026, 9, 2),
      data: TrainingSession(
        date: '2026-09-02T10:00:00+09:00',
        memo: '',
        exercises: [
          TrainingExercise(
            exerciseName: 'Bench Press',
            order: 1,
            sets: [TrainingSet(setNo: 1, weight: 60, reps: 8)],
          ),
        ],
      ),
    );

    final metrics = adapter.build(target: target, records: [target]);

    expect(metrics.session.duration, isNull);
    expect(metrics.session.workingVolume, isNull);
    expect(metrics.session.averageRpe, isNull);
    expect(metrics.exercises.single.current.workingVolume, isNull);
    expect(metrics.exercises.single.current.averageRpe, isNull);
  });
}

TrainingRecordReadModel _v2Record(
  String id,
  String date,
  double weight, {
  int? rpe,
  String? equipment,
}) => TrainingRecordReadModel.v2(
  id: id,
  localDate: date,
  createdAt: DateTime.parse('${date}T12:00:00Z'),
  updatedAt: DateTime.parse('${date}T12:00:00Z'),
  data: TrainingSessionV2(
    date: '${date}T10:00:00+09:00',
    startTime: '${date}T10:00:00+09:00',
    endTime: '${date}T11:00:00+09:00',
    exercises: [
      TrainingExerciseV2(
        exerciseName: 'Bench Press',
        order: 1,
        equipment: equipment == null
            ? null
            : TrainingEquipmentSnapshot(name: equipment),
        sets: [
          TrainingSetV2(
            setNo: 1,
            setType: TrainingSetType.warmUp,
            weightKg: weight / 2,
            reps: 8,
            rpe: rpe,
          ),
          TrainingSetV2(
            setNo: 2,
            setType: TrainingSetType.main,
            weightKg: weight,
            reps: 8,
            rpe: rpe,
          ),
        ],
      ),
    ],
  ),
);
