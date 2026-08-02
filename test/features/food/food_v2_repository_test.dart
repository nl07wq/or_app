import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/recipe_models_v2.dart';
import 'package:or_app/features/food/repository/indexed_db_daily_meal_v2_repository.dart';
import 'package:or_app/features/food/repository/indexed_db_food_catalog_repository.dart';
import 'package:or_app/features/food/repository/indexed_db_food_recipe_repository.dart';
import 'package:or_app/features/food/repository/indexed_db_food_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final created = DateTime.utc(2026, 8, 2, 9);
  final updated = DateTime.utc(2026, 8, 2, 10);
  final next = DateTime.utc(2026, 8, 2, 11);

  test(
    'catalog create, update, archive, list and conflicts are transactional',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbFoodCatalogRepository(
        database,
        now: () => next,
      );
      final entry = _catalog(created, updated);

      await repository.create(entry);
      expect((await repository.readById(entry.foodId))!.name, 'Rice');
      await expectLater(repository.create(entry), throwsA(isA<Object>()));
      await repository.update(
        FoodCatalogEntry.fromJson({...entry.toJson(), 'name': 'Brown Rice'}),
      );
      final changed = (await repository.readById(entry.foodId))!;
      expect(changed.name, 'Brown Rice');
      expect(changed.createdAt, created);
      expect(changed.updatedAt, next);
      await repository.archive(entry.foodId);
      expect((await repository.list()).single.isArchived, isTrue);
    },
  );

  test(
    'recipe create, update and archive preserve identity and createdAt',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbFoodRecipeRepository(
        database,
        now: () => next,
      );
      final recipe = _recipe(created, updated);

      await repository.create(recipe);
      await repository.update(
        FoodRecipeDefinition.fromJson({
          ...recipe.toJson(),
          'name': 'Rice Bowl',
        }),
      );
      final changed = (await repository.readById(recipe.recipeId))!;
      expect(changed.name, 'Rice Bowl');
      expect(changed.createdAt, created);
      expect(changed.updatedAt, next);
      await repository.archive(recipe.recipeId);
      expect((await repository.list()).single.isArchived, isTrue);
    },
  );

  test(
    'daily meal v2 coexists with v1 and updates only its envelope',
    () async {
      final database = FakeIndexedDbDatabase();
      await IndexedDbFoodRepository(database).save(
        const MealData(
          date: '2026-08-02',
          mealType: 'Breakfast',
          items: [],
          memo: '',
          id: 'legacy',
        ),
      );
      final repository = IndexedDbDailyMealV2Repository(
        database,
        now: () => next,
      );
      final meal = _meal(created, updated);

      await repository.create(meal);
      expect(
        (await repository.readForLocalDate('2026-08-02')).single.mealId,
        meal.mealId,
      );
      await repository.update(
        DailyMealV2.fromJson({...meal.toJson(), 'memo': 'updated'}),
      );
      final changed = (await repository.readById(meal.mealId))!;
      expect(changed.memo, 'updated');
      expect(changed.createdAt, created);
      expect(changed.updatedAt, next);
      expect(
        database.rawRecord(IndexedDbStoreNames.foodRecords, 'food:legacy'),
        isNotNull,
      );
    },
  );

  test('failed v2 write rolls back without a partial record', () async {
    final database = FakeIndexedDbDatabase()
      ..failNextTransactionWith = StateError('fail');
    final repository = IndexedDbDailyMealV2Repository(database);
    final meal = _meal(created, updated);

    await expectLater(repository.create(meal), throwsA(isA<Object>()));
    expect(await repository.readById(meal.mealId), isNull);
  });

  test('v1 and v2 repositories exclude the other known version', () async {
    final database = FakeIndexedDbDatabase();
    final legacy = IndexedDbFoodRepository(database);
    final daily = IndexedDbDailyMealV2Repository(database);
    await legacy.save(
      const MealData(
        date: '2026-08-02',
        mealType: 'Breakfast',
        items: [],
        memo: '',
        id: 'legacy',
      ),
    );
    await daily.create(_meal(created, updated));

    expect(await legacy.findAll(), hasLength(1));
    expect(await daily.findAll(), hasLength(1));
  });

  test('unknown version and malformed known records are not hidden', () async {
    final database = FakeIndexedDbDatabase();
    database.seed(IndexedDbStoreNames.foodRecords, 'food:unknown', {
      'id': 'food:unknown',
      'recordVersion': 99,
    });
    final legacy = IndexedDbFoodRepository(database);
    final daily = IndexedDbDailyMealV2Repository(database);

    expect((await legacy.findAllWithIssues()).issues, hasLength(1));
    await expectLater(daily.findAll(), throwsA(isA<Object>()));
  });

  test('malformed v1 and malformed v2 records remain integrity failures', () async {
    final invalidV1 = FakeIndexedDbDatabase()
      ..seed(IndexedDbStoreNames.foodRecords, 'food:bad-v1', {
        'id': 'food:bad-v1',
        'recordVersion': 1,
      });
    expect(
      (await IndexedDbFoodRepository(invalidV1).findAllWithIssues()).issues,
      hasLength(1),
    );
    await expectLater(
      IndexedDbDailyMealV2Repository(invalidV1).findAll(),
      throwsA(isA<Object>()),
    );

    final invalidV2 = FakeIndexedDbDatabase()
      ..seed(IndexedDbStoreNames.foodRecords, 'food:bad-v2', {
        'id': 'food:bad-v2',
        'recordVersion': 2,
      });
    expect(
      (await IndexedDbFoodRepository(invalidV2).findAllWithIssues()).issues,
      hasLength(1),
    );
    await expectLater(
      IndexedDbDailyMealV2Repository(invalidV2).findAll(),
      throwsA(isA<Object>()),
    );
  });
}

FoodDataProvenance _provenance(DateTime created) => FoodDataProvenance(
  sourceType: FoodProvenanceSourceType.userInput,
  capturedAt: created,
);

NutritionSnapshot _nutrition() => NutritionSnapshot(calories: 100, protein: 2);

FoodCatalogEntry _catalog(DateTime created, DateTime updated) =>
    FoodCatalogEntry(
      foodId: '11111111-1111-4111-8111-111111111111',
      name: 'Rice',
      category: FoodCatalogCategory.ingredient,
      baseQuantity: FoodQuantityDefinition(
        value: 100,
        unit: FoodQuantityUnit.gram,
      ),
      nutrition: _nutrition(),
      nutritionStatus: NutritionStatus.declared,
      provenance: _provenance(created),
      isArchived: false,
      createdAt: created,
      updatedAt: updated,
    );

FoodRecipeDefinition _recipe(DateTime created, DateTime updated) =>
    FoodRecipeDefinition(
      recipeId: '22222222-2222-4222-8222-222222222222',
      name: 'Rice Plate',
      ingredients: [
        RecipeIngredientV2(
          ingredientId: '33333333-3333-4333-8333-333333333333',
          nameSnapshot: 'Rice',
          quantity: FoodQuantityDefinition(
            value: 100,
            unit: FoodQuantityUnit.gram,
          ),
          nutritionSnapshot: _nutrition(),
          nutritionStatus: NutritionStatus.declared,
          provenanceSnapshot: _provenance(created),
          sortOrder: 0,
        ),
      ],
      yieldQuantity: FoodQuantityDefinition(
        value: 1,
        unit: FoodQuantityUnit.serving,
      ),
      nutrition: _nutrition(),
      nutritionStatus: NutritionStatus.calculated,
      provenance: _provenance(created),
      isArchived: false,
      createdAt: created,
      updatedAt: updated,
    );

DailyMealV2 _meal(DateTime created, DateTime updated) => DailyMealV2(
  mealId: '44444444-4444-4444-8444-444444444444',
  localDate: '2026-08-02',
  mealType: DailyMealTypeV2.water,
  items: const [],
  waterMl: 300,
  createdAt: created,
  updatedAt: updated,
);
