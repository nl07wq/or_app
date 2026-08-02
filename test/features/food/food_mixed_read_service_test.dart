import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/food_unified_read_model.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/persisted_food_record.dart';
import 'package:or_app/features/food/repository/daily_meal_v2_repository.dart';
import 'package:or_app/features/food/repository/indexed_db_daily_meal_v2_repository.dart';
import 'package:or_app/features/food/repository/indexed_db_food_repository.dart';
import 'package:or_app/features/food/services/food_mixed_read_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late IndexedDbFoodRepository legacy;
  late IndexedDbDailyMealV2Repository v2;
  late FoodMixedReadService service;

  setUp(() {
    database = FakeIndexedDbDatabase();
    legacy = IndexedDbFoodRepository(
      database,
      now: () => DateTime.utc(2026, 8, 1, 9),
    );
    v2 = IndexedDbDailyMealV2Repository(database);
    service = FoodMixedReadService(legacyRepository: legacy, v2Repository: v2);
  });

  test(
    'projects v1 without inferred references, provenance, or v2 quantity',
    () async {
      await legacy.save(_legacy('legacy-1', '2026-08-01', name: 'Same'));

      final record = (await service.readHistory()).single;
      expect(
        record.identity,
        const FoodRecordIdentity(FoodRecordKind.legacyV1, 'legacy-1'),
      );
      expect(record.items.single.displayName, 'Same');
      expect(record.items.single.quantityLabel, '2');
      expect(record.items.single.catalogReferenceId, isNull);
      expect(record.items.single.recipeReferenceId, isNull);
      expect(record.items.single.provenance, isNull);
      expect(record.items.single.nutritionStatus, isNull);
      expect(record.nutritionAggregate.calories.knownTotal, 200);
    },
  );

  test(
    'projects v2 consumed nutrition and preserves snapshot metadata',
    () async {
      await v2.create(_v2(_v2Id1, '2026-08-01', name: 'Same'));

      final record = (await service.readHistory()).single;
      final item = record.items.single;
      expect(record.identity.recordKind, FoodRecordKind.dailyMealV2);
      expect(item.catalogReferenceId, _foodId);
      expect(item.provenance, isNotNull);
      expect(item.nutritionStatus, NutritionStatus.declared);
      expect(record.nutritionAggregate.calories.knownTotal, 50);
      expect(record.nutritionAggregate.calories.knownTotal, isNot(100));
    },
  );

  test(
    'v2 projection distinguishes recipe and snapshot-only sources',
    () async {
      await v2.create(
        _v2(
          _v2Id2,
          '2026-08-01',
          foodReferenceId: null,
          recipeReferenceId: _recipeId,
        ),
      );
      await v2.create(_v2(_v2Id3, '2026-08-01', foodReferenceId: null));

      final records = await service.readHistory();
      expect(
        records
            .singleWhere((value) => value.identity.recordId == _v2Id2)
            .items
            .single
            .sourceKind,
        FoodReadItemSourceKind.recipe,
      );
      expect(
        records
            .singleWhere((value) => value.identity.recordId == _v2Id3)
            .items
            .single
            .sourceKind,
        FoodReadItemSourceKind.snapshotOnly,
      );
    },
  );

  test(
    'keeps same-name v1 and v2 records independent on the same date',
    () async {
      await legacy.save(_legacy('legacy-1', '2026-08-01', name: 'Same'));
      await v2.create(_v2(_v2Id1, '2026-08-01', name: 'Same'));

      final records = await service.readForLocalDate('2026-08-01');
      expect(records, hasLength(2));
      expect(records.map((value) => value.identity.recordKind), {
        FoodRecordKind.legacyV1,
        FoodRecordKind.dailyMealV2,
      });
    },
  );

  test(
    'history is date descending and recent is a non-persisted limit',
    () async {
      await legacy.save(_legacy('legacy-1', '2026-08-01'));
      await v2.create(_v2(_v2Id2, '2026-08-02'));

      final history = await service.readHistory();
      expect(history.map((value) => value.localDate), [
        '2026-08-02',
        '2026-08-01',
      ]);
      expect((await service.readRecent(1)).single.identity.recordId, _v2Id2);
      expect(await service.readRecent(0), isEmpty);
    },
  );

  test('day summary excludes water from nutrition item counts', () async {
    await legacy.save(_legacy('legacy-1', '2026-08-01'));
    await v2.create(_water(_waterId, '2026-08-01'));
    final records = await service.readForLocalDate('2026-08-01');

    final summary = FoodMixedDaySummary.fromRecords(records);
    expect(summary.mealCount, 1);
    expect(summary.hydrationMl, 300);
    expect(summary.nutrition.calories.knownItemCount, 1);
  });

  test('readByIdentity routes v1 and v2 without converting either', () async {
    await legacy.save(_legacy('legacy-1', '2026-08-01'));
    await v2.create(_v2(_v2Id1, '2026-08-01'));

    expect(
      (await service.readByIdentity(
        const FoodRecordIdentity(FoodRecordKind.legacyV1, 'legacy-1'),
      ))!.identity.recordKind,
      FoodRecordKind.legacyV1,
    );
    expect(
      (await service.readByIdentity(
        const FoodRecordIdentity(FoodRecordKind.dailyMealV2, _v2Id1),
      ))!.identity.recordKind,
      FoodRecordKind.dailyMealV2,
    );
  });

  test('duplicate identity is an integrity error', () async {
    final record = PersistedFoodRecord(
      id: 'food:legacy-1',
      localDate: '2026-08-01',
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
      data: _legacy('legacy-1', '2026-08-01'),
    );
    final target = FoodMixedReadService(
      legacyRepository: _LegacyStub(records: [record, record]),
      v2Repository: const _V2Stub(),
    );

    await expectLater(target.readHistory(), throwsA(isA<Object>()));
  });

  test('repository errors propagate without fallback', () async {
    final target = FoodMixedReadService(
      legacyRepository: _LegacyStub(error: StateError('read failed')),
      v2Repository: const _V2Stub(),
    );

    await expectLater(target.readHistory(), throwsA(isA<StateError>()));
  });
}

const _foodId = '11111111-1111-4111-8111-111111111111';
const _recipeId = '11111111-1111-4111-8111-111111111112';
const _v2Id1 = '22222222-2222-4222-8222-222222222221';
const _v2Id2 = '22222222-2222-4222-8222-222222222222';
const _v2Id3 = '22222222-2222-4222-8222-222222222224';
const _waterId = '22222222-2222-4222-8222-222222222223';

MealData _legacy(String id, String date, {String name = 'Rice'}) => MealData(
  date: date,
  mealType: 'Breakfast',
  items: [
    FoodItem(
      name: name,
      calories: 100,
      protein: 2,
      fat: 1,
      carbohydrate: 20,
      quantity: 2,
    ),
  ],
  memo: '',
  id: id,
);

DailyMealV2 _v2(
  String id,
  String date, {
  String name = 'Rice',
  String? foodReferenceId = _foodId,
  String? recipeReferenceId,
}) => DailyMealV2(
  mealId: id,
  localDate: date,
  mealType: DailyMealTypeV2.breakfast,
  items: [
    DailyMealItemSnapshot(
      mealItemId: id.replaceFirst('22222222', '33333333'),
      foodReferenceId: foodReferenceId,
      recipeReferenceId: recipeReferenceId,
      nameSnapshot: name,
      quantity: FoodQuantityDefinition(value: 50, unit: FoodQuantityUnit.gram),
      nutritionPerBase: NutritionSnapshot(calories: 100, protein: 4),
      nutritionConsumed: NutritionSnapshot(calories: 50, protein: 2),
      provenanceSnapshot: FoodDataProvenance(
        sourceType: FoodProvenanceSourceType.userInput,
        capturedAt: DateTime.utc(2026, 8, 1),
      ),
      nutritionStatusSnapshot: NutritionStatus.declared,
      sortOrder: 0,
    ),
  ],
  createdAt: DateTime.parse('${date}T10:00:00.000Z'),
  updatedAt: DateTime.parse('${date}T10:00:00.000Z'),
);

DailyMealV2 _water(String id, String date) => DailyMealV2(
  mealId: id,
  localDate: date,
  mealType: DailyMealTypeV2.water,
  items: const [],
  waterMl: 300,
  createdAt: DateTime.parse('${date}T11:00:00.000Z'),
  updatedAt: DateTime.parse('${date}T11:00:00.000Z'),
);

class _LegacyStub implements FoodAuditRepository {
  final List<PersistedFoodRecord> records;
  final Object? error;

  const _LegacyStub({this.records = const [], this.error});

  @override
  Future<FoodReadResult> findAllWithIssues() async {
    if (error != null) throw error!;
    return FoodReadResult(records: records);
  }
}

class _V2Stub implements DailyMealV2Repository {
  const _V2Stub();

  @override
  Future<void> create(DailyMealV2 meal) => throw UnimplementedError();

  @override
  Future<List<DailyMealV2>> findAll() async => const [];

  @override
  Future<DailyMealV2?> readById(String mealId) async => null;

  @override
  Future<List<DailyMealV2>> readForLocalDate(String localDate) async =>
      const [];

  @override
  Future<void> update(DailyMealV2 meal) => throw UnimplementedError();
}
