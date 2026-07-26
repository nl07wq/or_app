import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:or_app/features/training/repository/custom_training_exercise_id_generator.dart';
import 'package:or_app/features/training/repository/indexed_db_custom_training_exercise_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test('supports ID-based CRUD and survives repository recreation', () async {
    final database = FakeIndexedDbDatabase();
    final times = <DateTime>[
      DateTime.utc(2026, 7, 26, 1),
      DateTime.utc(2026, 7, 26, 2),
    ];
    var timeIndex = 0;
    final repository = IndexedDbCustomTrainingExerciseRepository(
      database,
      idGenerator: CustomTrainingExerciseIdGenerator(nextInt: (_) => 1),
      now: () => times[timeIndex++],
    );

    final created = await repository.create('Custom Press');
    final createdRecord = database.rawRecord(
      IndexedDbStoreNames.customTrainingExercises,
      created.id,
    )!;
    expect(created.id, startsWith('custom-exercise:'));
    expect((await repository.findById(created.id))!.name, 'Custom Press');
    expect(await repository.findAll(), hasLength(1));

    final updated = await repository.updateById(created.id, 'Custom Row');
    final updatedRecord = database.rawRecord(
      IndexedDbStoreNames.customTrainingExercises,
      created.id,
    )!;
    expect(updated.id, created.id);
    expect(updated.name, 'Custom Row');
    expect(updatedRecord['createdAt'], createdRecord['createdAt']);
    expect(updatedRecord['updatedAt'], isNot(createdRecord['updatedAt']));
    expect(updatedRecord['normalizedName'], 'customrow');

    final recreated = IndexedDbCustomTrainingExerciseRepository(database);
    expect((await recreated.findAll()).single.id, created.id);
    expect((await recreated.findAll()).single.name, 'Custom Row');

    await recreated.deleteById(created.id);
    expect(await recreated.findAll(), isEmpty);
  });

  test('rejects normalized name collision without overwriting', () async {
    var byte = 0;
    final repository = IndexedDbCustomTrainingExerciseRepository(
      FakeIndexedDbDatabase(),
      idGenerator: CustomTrainingExerciseIdGenerator(
        nextInt: (_) => byte++ % 256,
      ),
    );
    final first = await repository.create('Custom Press');
    final second = await repository.create('Custom Row');

    await expectLater(
      repository.updateById(second.id, ' custom_press '),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.invalidRecord,
        ),
      ),
    );

    expect((await repository.findById(first.id))!.name, 'Custom Press');
    expect((await repository.findById(second.id))!.name, 'Custom Row');
  });

  test(
    'findAll is immutable and clear removes only custom exercises',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbCustomTrainingExerciseRepository(
        database,
        idGenerator: CustomTrainingExerciseIdGenerator(nextInt: (_) => 2),
      );
      await repository.create('Custom Press');
      final records = await repository.findAll();

      expect(() => records.add(records.single), throwsUnsupportedError);
      await repository.clear();
      expect(await repository.findAll(), isEmpty);
    },
  );

  test('invalid stored record is reported and not returned as empty', () async {
    final database = FakeIndexedDbDatabase()
      ..seed(IndexedDbStoreNames.customTrainingExercises, 'broken', {
        'id': 'broken',
      });
    final repository = IndexedDbCustomTrainingExerciseRepository(database);

    final audit = await repository.findAllWithIssues();
    expect(audit.records, isEmpty);
    expect(audit.issues, hasLength(1));
    await expectLater(
      repository.findAll(),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.partialCorruption,
        ),
      ),
    );
  });

  test('transaction failure does not persist a partial create', () async {
    final database = FakeIndexedDbDatabase()
      ..failNextTransactionWith = StateError('write failed');
    final repository = IndexedDbCustomTrainingExerciseRepository(
      database,
      idGenerator: CustomTrainingExerciseIdGenerator(nextInt: (_) => 3),
    );

    await expectLater(
      repository.create('Custom Press'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.transactionFailed,
        ),
      ),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.customTrainingExercises),
      isEmpty,
    );
  });
}
