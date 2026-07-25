import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/morning_fact/models/morning_fact.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:or_app/features/repositories/repository_record.dart';
import 'package:or_app/repositories/indexed_db/indexed_db_morning_fact_repository.dart';
import 'package:or_app/repositories/indexed_db/indexed_db_training_repository.dart';

import 'fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late IndexedDbMorningFactRepository repository;

  setUp(() {
    database = FakeIndexedDbDatabase();
    repository = IndexedDbMorningFactRepository(database);
  });

  test('supports CRUD, overwrite, immutable findAll, and clear', () async {
    final first = RepositoryRecord(
      id: 'morning-1',
      value: MorningFact(
        date: DateTime.utc(2026, 7, 25),
        weight: 72.5,
        bodyFat: 18,
        sleepDuration: const Duration(hours: 7, minutes: 30),
        sleepScore: 82,
        footPain: 2,
        condition: 4,
        bowel: 'normal',
        hydration: 500,
        workSchedule: '11:00–18:00',
      ),
    );
    const updated = RepositoryRecord(
      id: 'morning-1',
      value: MorningFact(weight: 72, sleepScore: 90),
    );
    const second = RepositoryRecord(
      id: 'morning-2',
      value: MorningFact(condition: 4),
    );

    expect(await repository.findAll(), isEmpty);
    expect(await repository.findById('missing'), isNull);

    await repository.save(first);
    final stored = await repository.findById(first.id);
    expect(stored?.value.date, DateTime.utc(2026, 7, 25));
    expect(stored?.value.weight, 72.5);
    expect(stored?.value.bodyFat, 18);
    expect(stored?.value.sleepDuration, const Duration(hours: 7, minutes: 30));
    expect(stored?.value.sleepScore, 82);
    expect(stored?.value.footPain, 2);
    expect(stored?.value.condition, 4);
    expect(stored?.value.bowel, 'normal');
    expect(stored?.value.hydration, 500);
    expect(stored?.value.workSchedule, '11:00–18:00');

    await repository.save(updated);
    await repository.save(second);
    final records = await repository.findAll();
    expect(records, hasLength(2));
    expect((await repository.findById(first.id))?.value.sleepScore, 90);
    expect(() => records.add(first), throwsUnsupportedError);

    await repository.delete('missing');
    expect(await repository.findAll(), hasLength(2));
    await repository.delete(first.id);
    expect(await repository.findById(first.id), isNull);

    await repository.clear();
    expect(await repository.findAll(), isEmpty);
  });

  test(
    'persists across repository instances and keeps stores independent',
    () async {
      const morning = RepositoryRecord(
        id: 'shared-id',
        value: MorningFact(weight: 72.5),
      );
      final training = RepositoryRecord(
        id: 'shared-id',
        value: TrainingSession(
          date: '2026-07-25T10:00:00.000',
          memo: '',
          exercises: const [],
        ),
      );
      await repository.save(morning);
      await IndexedDbTrainingRepository(database).save(training);

      final recreated = IndexedDbMorningFactRepository(database);
      expect((await recreated.findById(morning.id))?.value.weight, 72.5);

      await recreated.clear();
      expect(await recreated.findAll(), isEmpty);
      expect(
        await IndexedDbTrainingRepository(database).findById(training.id),
        isNotNull,
      );
    },
  );

  test('wraps invalid stored records in RepositoryException', () async {
    database.seed(IndexedDbStoreNames.morningFacts, 'broken', {
      'id': 'broken',
      'data': {'date': 42},
    });

    await expectLater(
      repository.findById('broken'),
      throwsA(isA<RepositoryException>()),
    );
  });
}
