import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/features/activity/repository/in_memory_activity_repository.dart';

void main() {
  late InMemoryActivityRepository repository;

  setUp(() => repository = InMemoryActivityRepository());

  test(
    'supports save, find, overwrite, multiple records, and immutable lists',
    () async {
      final first = ActivityData(
        id: 'activity-1',
        date: DateTime(2026, 7, 25),
        measuredSteps: 1000,
        bowelMovement: BowelMovementRecord.recorded(amount: 1, shape: 1),
      );
      final updated = first.copyWith(measuredSteps: 2000);
      final second = ActivityData(
        id: 'activity-2',
        date: DateTime(2026, 7, 26),
        measuredSteps: 3000,
      );

      expect(await repository.findAll(), isEmpty);
      expect(await repository.findById('missing'), isNull);

      await repository.save(first);
      expect((await repository.findById(first.id))?.measuredSteps, 1000);
      expect(
        (await repository.findByDate(DateTime(2026, 7, 25)))?.id,
        first.id,
      );

      await repository.save(updated);
      await repository.save(second);
      final records = await repository.findAll();
      expect(records, hasLength(2));
      expect((await repository.findById(first.id))?.measuredSteps, 2000);
      expect(() => records.add(first), throwsUnsupportedError);
    },
  );

  test('delete, missing delete, and clear are safe', () async {
    final record = ActivityData(
      id: 'activity-1',
      date: DateTime(2026, 7, 25),
      measuredSteps: 1000,
    );
    await repository.save(record);

    await repository.delete('missing');
    expect(await repository.findAll(), hasLength(1));
    await repository.delete(record.id);
    expect(await repository.findAll(), isEmpty);

    await repository.save(record);
    await repository.clear();
    expect(await repository.findAll(), isEmpty);
  });

  test('returned records are defensive copies', () async {
    final record = ActivityData(
      id: 'activity-1',
      date: DateTime(2026, 7, 25),
      measuredSteps: 1000,
    );
    await repository.save(record);

    final loaded = await repository.findById(record.id);
    final changed = loaded!.copyWith(measuredSteps: 9999);

    expect(changed.measuredSteps, 9999);
    expect((await repository.findById(record.id))?.measuredSteps, 1000);
  });
}
