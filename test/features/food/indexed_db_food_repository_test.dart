import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/food/models/persisted_food_record.dart';
import 'package:or_app/features/food/repository/indexed_db_food_repository.dart';
import 'package:or_app/features/repositories/repository_exception.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late List<DateTime> timestamps;
  late IndexedDbFoodRepository repository;

  setUp(() {
    database = FakeIndexedDbDatabase();
    timestamps = [
      DateTime.parse('2026-07-26T00:00:00Z'),
      DateTime.parse('2026-07-26T01:00:00Z'),
      DateTime.parse('2026-07-26T02:00:00Z'),
      DateTime.parse('2026-07-26T03:00:00Z'),
      DateTime.parse('2026-07-26T04:00:00Z'),
      DateTime.parse('2026-07-26T05:00:00Z'),
    ];
    repository = IndexedDbFoodRepository(
      database,
      now: () => timestamps.removeAt(0),
    );
  });

  test('saves and overwrites ID while preserving Envelope createdAt', () async {
    await repository.save(_meal(id: 'meal-1', memo: 'first'));
    var envelope = PersistedFoodRecord.fromRecord(
      (await database.findAll(IndexedDbStoreNames.foodRecords)).single,
    );
    expect(envelope.id, 'food:meal-1');
    expect(envelope.data.id, 'meal-1');
    expect(envelope.createdAt, DateTime.parse('2026-07-26T00:00:00Z'));
    expect(envelope.updatedAt, DateTime.parse('2026-07-26T00:00:00Z'));

    await repository.update(_meal(id: 'meal-1', memo: 'updated'));
    envelope = PersistedFoodRecord.fromRecord(
      (await database.findAll(IndexedDbStoreNames.foodRecords)).single,
    );
    expect(envelope.data.memo, 'updated');
    expect(envelope.createdAt, DateTime.parse('2026-07-26T00:00:00Z'));
    expect(envelope.updatedAt, DateTime.parse('2026-07-26T01:00:00Z'));
  });

  test(
    'keeps same-day multiple meals, other dates, and insertion order',
    () async {
      await repository.save(_meal(id: 'breakfast', mealType: 'Breakfast'));
      await repository.save(_meal(id: 'lunch', mealType: 'Lunch'));
      await repository.save(
        _meal(id: 'other-day', date: '2026-07-27', mealType: 'Dinner'),
      );

      expect((await repository.findAll()).map((meal) => meal.id), [
        'breakfast',
        'lunch',
        'other-day',
      ]);
      final daily = await repository.findByLocalDate('2026-07-26');
      expect(daily.map((meal) => meal.id), ['breakfast', 'lunch']);
      expect(() => daily.clear(), throwsUnsupportedError);
      expect((await repository.findById('lunch'))?.mealType, 'Lunch');
      expect((await repository.findById('food:lunch'))?.mealType, 'Lunch');

      final recreated = IndexedDbFoodRepository(database);
      expect((await recreated.findById('other-day'))?.date, '2026-07-27');
    },
  );

  test(
    'fixes localDate from the source date without UTC recalculation',
    () async {
      await repository.save(
        _meal(id: 'timezone', date: '2026-07-26T00:30:00+09:00'),
      );

      final stored = PersistedFoodRecord.fromRecord(
        (await database.findAll(IndexedDbStoreNames.foodRecords)).single,
      );
      expect(stored.localDate, '2026-07-26');
      expect(
        (await repository.findByLocalDate('2026-07-26')).single.id,
        'timezone',
      );
    },
  );

  test('preserves items, order, values, totals, memo, and water', () async {
    final meal = _meal(
      id: 'complete',
      memo: 'memo',
      items: const [
        FoodItem(
          name: 'Rice',
          calories: 250,
          protein: 4.5,
          fat: 0.5,
          carbohydrate: 55.25,
          quantity: 2,
        ),
        FoodItem(
          name: 'Egg',
          calories: 80,
          protein: 7.25,
          fat: 5.5,
          carbohydrate: 1.0,
        ),
      ],
    );
    final water = _meal(
      id: 'water',
      mealType: 'Water',
      items: const [],
      waterMl: 350.5,
    );

    await repository.save(meal);
    await repository.save(water);

    final restored = await repository.findById('complete');
    expect(restored?.toJson(), meal.toJson());
    expect(restored?.items.map((item) => item.name), ['Rice', 'Egg']);
    expect(restored?.calories, meal.calories);
    expect(restored?.protein, meal.protein);
    expect(restored?.fat, meal.fat);
    expect(restored?.carbohydrate, meal.carbohydrate);
    expect((await repository.findById('water'))?.waterMl, 350.5);

    restored!.items.clear();
    expect((await repository.findById('complete'))?.items, hasLength(2));
  });

  test('delete and clear affect only FOOD Store', () async {
    await repository.save(_meal(id: 'meal-1'));
    await repository.save(_meal(id: 'meal-2'));
    database.seed(IndexedDbStoreNames.statusRecords, 'unrelated', {
      'id': 'unrelated',
    });

    await repository.deleteById('meal-1');
    expect(await repository.findById('meal-1'), isNull);
    expect(await repository.findAll(), hasLength(1));

    await repository.clear();
    expect(await repository.findAll(), isEmpty);
    expect(
      await database.findById(IndexedDbStoreNames.statusRecords, 'unrelated'),
      isNotNull,
    );
  });

  test('does not report a failed transaction as a successful save', () async {
    database.failNextTransactionWith = StateError('failed');

    await expectLater(
      repository.save(_meal(id: 'meal-1')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.transactionFailed,
        ),
      ),
    );
    expect(await database.findAll(IndexedDbStoreNames.foodRecords), isEmpty);
  });

  test('separates partial corruption from valid FOOD records', () async {
    await repository.save(_meal(id: 'valid'));
    database.seed(IndexedDbStoreNames.foodRecords, 'broken', {
      'id': 'broken',
      'recordVersion': 999,
    });

    final result = await repository.findAllWithIssues();
    expect(result.records, hasLength(1));
    expect(result.issues, hasLength(1));
    expect(result.issues.single.recordId, 'broken');
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
}

MealData _meal({
  required String id,
  String date = '2026-07-26',
  String mealType = 'Breakfast',
  String memo = '',
  List<FoodItem>? items,
  double? waterMl,
}) {
  return MealData(
    id: id,
    date: date,
    mealType: mealType,
    memo: memo,
    items:
        items ??
        const [
          FoodItem(
            name: 'Food',
            calories: 100,
            protein: 10,
            fat: 3,
            carbohydrate: 12,
          ),
        ],
    waterMl: waterMl,
  );
}
