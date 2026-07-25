import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/features/morning_fact/models/morning_fact.dart';
import 'package:or_app/features/repositories/memory/in_memory_morning_fact_repository.dart';
import 'package:or_app/features/repositories/memory/in_memory_training_repository.dart';
import 'package:or_app/features/repositories/repository_provider.dart';
import 'package:or_app/features/repositories/repository_record.dart';

void main() {
  test('MorningFact repository supports CRUD, findAll, and clear', () async {
    final repository = InMemoryMorningFactRepository();
    const first = RepositoryRecord(
      id: 'morning-1',
      value: MorningFact(weight: 72.5),
    );
    const updated = RepositoryRecord(
      id: 'morning-1',
      value: MorningFact(weight: 72),
    );
    const second = RepositoryRecord(
      id: 'morning-2',
      value: MorningFact(sleepScore: 82),
    );

    expect(await repository.findAll(), isEmpty);
    expect(await repository.findById(first.id), isNull);

    await repository.save(first);
    expect((await repository.findById(first.id))?.value.weight, 72.5);

    await repository.save(updated);
    await repository.save(second);
    final records = await repository.findAll();
    expect(records, hasLength(2));
    expect(records.first.value.weight, 72);
    expect(() => records.add(first), throwsUnsupportedError);

    await repository.delete(first.id);
    expect(await repository.findById(first.id), isNull);
    expect(await repository.findAll(), hasLength(1));

    await repository.clear();
    expect(await repository.findAll(), isEmpty);
  });

  test('Training repository supports CRUD and protects nested lists', () async {
    final repository = InMemoryTrainingRepository();
    final sets = <TrainingSet>[
      const TrainingSet(setNo: 1, weight: 80, reps: 10),
    ];
    final exercises = <TrainingExercise>[
      TrainingExercise(exerciseName: 'BenchPress', order: 1, sets: sets),
    ];
    final session = TrainingSession(
      date: '2026-07-25T10:00:00.000',
      memo: '',
      exercises: exercises,
    );
    final record = RepositoryRecord(id: 'training-1', value: session);

    await repository.save(record);
    sets.add(const TrainingSet(setNo: 2, weight: 80, reps: 8));
    exercises.clear();

    final stored = await repository.findById(record.id);
    expect(stored?.value.exercises, hasLength(1));
    expect(stored?.value.exercises.single.sets, hasLength(1));
    expect(
      () => stored!.value.exercises.add(
        const TrainingExercise(exerciseName: 'Squat', order: 2, sets: []),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => stored!.value.exercises.single.sets.add(
        const TrainingSet(setNo: 2, weight: 80, reps: 8),
      ),
      throwsUnsupportedError,
    );

    expect(await repository.findAll(), hasLength(1));
    await repository.delete(record.id);
    expect(await repository.findAll(), isEmpty);

    await repository.save(record);
    await repository.clear();
    expect(await repository.findById(record.id), isNull);
  });

  test('RepositoryProvider creates independent in-memory repositories', () {
    final first = RepositoryProvider.inMemory();
    final second = RepositoryProvider.inMemory();

    expect(first.morningFactRepository, isA<InMemoryMorningFactRepository>());
    expect(first.trainingRepository, isA<InMemoryTrainingRepository>());
    expect(
      first.morningFactRepository,
      isNot(same(second.morningFactRepository)),
    );
    expect(first.trainingRepository, isNot(same(second.trainingRepository)));
  });
}
