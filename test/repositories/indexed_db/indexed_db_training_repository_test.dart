import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/features/repositories/repository_record.dart';
import 'package:or_app/repositories/indexed_db/indexed_db_training_repository.dart';

import 'fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late IndexedDbTrainingRepository repository;

  setUp(() {
    database = FakeIndexedDbDatabase();
    repository = IndexedDbTrainingRepository(database);
  });

  test('supports CRUD, overwrite, immutable findAll, and clear', () async {
    final first = _record('training-1', weight: 80);
    final updated = _record('training-1', weight: 82.5);
    final second = _record('training-2', weight: 60);

    expect(await repository.findAll(), isEmpty);
    expect(await repository.findById('missing'), isNull);

    await repository.save(first);
    expect(
      (await repository.findById(
        first.id,
      ))?.value.exercises.single.sets.single.weight,
      80,
    );

    await repository.save(updated);
    await repository.save(second);
    final records = await repository.findAll();
    expect(records, hasLength(2));
    expect(
      (await repository.findById(
        first.id,
      ))?.value.exercises.single.sets.single.weight,
      82.5,
    );
    expect(() => records.add(first), throwsUnsupportedError);

    await repository.delete('missing');
    expect(await repository.findAll(), hasLength(2));
    await repository.delete(first.id);
    expect(await repository.findById(first.id), isNull);

    await repository.clear();
    expect(await repository.findAll(), isEmpty);
  });

  test('defensively copies on save and load', () async {
    final sets = <TrainingSet>[
      const TrainingSet(setNo: 1, weight: 80, reps: 10),
    ];
    final exercises = <TrainingExercise>[
      TrainingExercise(exerciseName: 'BenchPress', order: 1, sets: sets),
    ];
    final record = RepositoryRecord(
      id: 'training-1',
      value: TrainingSession(
        date: '2026-07-25T10:00:00.000',
        memo: '',
        exercises: exercises,
      ),
    );

    await repository.save(record);
    sets.add(const TrainingSet(setNo: 2, weight: 80, reps: 8));
    exercises.clear();

    final stored = await repository.findById(record.id);
    expect(stored?.value.exercises, hasLength(1));
    expect(stored?.value.exercises.single.sets, hasLength(1));
    expect(() => stored!.value.exercises.clear(), throwsUnsupportedError);
    expect(
      () => stored!.value.exercises.single.sets.clear(),
      throwsUnsupportedError,
    );

    final recreated = IndexedDbTrainingRepository(database);
    expect(
      (await recreated.findById(record.id))?.value.exercises,
      hasLength(1),
    );
  });
}

RepositoryRecord<TrainingSession> _record(String id, {required double weight}) {
  return RepositoryRecord(
    id: id,
    value: TrainingSession(
      date: '2026-07-25T10:00:00.000',
      memo: '',
      exercises: [
        TrainingExercise(
          exerciseName: 'BenchPress',
          order: 1,
          sets: [TrainingSet(setNo: 1, weight: weight, reps: 10)],
        ),
      ],
    ),
  );
}
