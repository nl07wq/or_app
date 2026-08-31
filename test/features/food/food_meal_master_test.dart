import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_meal_master_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/recipe_models_v2.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/food_meal_master_page.dart';
import 'package:or_app/features/food/repository/indexed_db_food_catalog_repository.dart';
import 'package:or_app/features/food/repository/indexed_db_food_meal_master_repository.dart';
import 'package:or_app/features/food/repository/indexed_db_food_recipe_repository.dart';
import 'package:or_app/features/food/services/food_meal_master_expander.dart';
import 'package:or_app/features/food/services/food_catalog_meal_mapper.dart';
import 'package:or_app/features/food/repository/food_meal_id_generator.dart';
import 'package:or_app/features/food/widgets/food_input_form.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final timestamp = DateTime.utc(2026, 9, 1);

  tearDown(AppRepositoryRegistry.resetForTesting);

  test(
    'Meal Master repository preserves identity, order, edits, and archive',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbFoodMealMasterRepository(
        database,
        now: () => timestamp.add(const Duration(hours: 1)),
      );
      final meal = _meal(timestamp);
      await repository.create(meal);

      final stored = await repository.readById(_mealId);
      expect(stored!.components.map((value) => value.sortOrder), [0, 1]);
      expect(stored.components.first.foodReferenceId, _foodId);
      expect(stored.components.last.recipeReferenceId, _recipeId);

      await repository.update(
        FoodMealMaster.fromJson({...meal.toJson(), 'name': '朝食定番 EDIT'}),
      );
      expect((await repository.readById(_mealId))!.name, '朝食定番 EDIT');

      await repository.archive(_mealId);
      expect((await repository.readById(_mealId))!.isArchived, isTrue);
      expect(
        await database.findAll(IndexedDbStoreNames.foodMealMasterRecords),
        hasLength(1),
      );
    },
  );

  test(
    'mixed Meal expands in order with stable references and native units',
    () async {
      final database = FakeIndexedDbDatabase();
      final foods = IndexedDbFoodCatalogRepository(database);
      final recipes = IndexedDbFoodRecipeRepository(
        database,
        now: () => timestamp.add(const Duration(hours: 1)),
      );
      await foods.create(_food(timestamp));
      await recipes.create(_recipe(timestamp));

      final result = await FoodMealMasterExpander(
        foods: foods,
        recipes: recipes,
      ).expand(_meal(timestamp));

      expect(result.items.map((value) => value.name), ['ゆで卵', '朝食レシピ']);
      expect(result.foodSources.first!.foodId, _foodId);
      expect(result.recipeSources.last!.recipeId, _recipeId);
      expect(result.quantityUnits, [
        FoodQuantityUnit.piece,
        FoodQuantityUnit.serving,
      ]);
      expect(result.items.first.multiplier, 2);
      expect(result.items.last.multiplier, 0.5);

      var nextByte = 0;
      final formal = FoodCatalogMealMapper.map(
        meal: MealData(
          id: 'draft',
          date: '2026-09-01',
          mealType: 'Breakfast',
          items: result.items,
          memo: '',
        ),
        catalogSources: result.foodSources,
        recipeSources: result.recipeSources,
        quantityUnits: result.quantityUnits,
        localDate: '2026-09-01',
        timestamp: timestamp,
        idGenerator: FoodMealIdGenerator(nextInt: (_) => nextByte++ % 256),
      );
      expect(formal.items, hasLength(2));
      expect(formal.items.first.foodReferenceId, _foodId);
      expect(formal.items.first.recipeReferenceId, isNull);
      expect(formal.items.first.quantity.toJson(), {
        'value': 2.0,
        'unit': 'piece',
        'basisValue': null,
        'basisUnit': null,
      });
      expect(formal.items.last.recipeReferenceId, _recipeId);
      expect(formal.items.last.foodReferenceId, isNull);
      expect(formal.items.last.quantity.unit, FoodQuantityUnit.serving);
      expect(formal.items.last.quantity.value, 0.5);
    },
  );

  test('broken or archived component blocks the entire expansion', () async {
    final database = FakeIndexedDbDatabase();
    final foods = IndexedDbFoodCatalogRepository(database);
    final recipes = IndexedDbFoodRecipeRepository(
      database,
      now: () => timestamp.add(const Duration(hours: 1)),
    );
    await foods.create(_food(timestamp));
    await recipes.create(_recipe(timestamp));
    await recipes.archive(_recipeId);

    expect(
      () => FoodMealMasterExpander(
        foods: foods,
        recipes: recipes,
      ).expand(_meal(timestamp)),
      throwsA(
        isA<FoodMealMasterExpansionException>().having(
          (error) => error.componentLabel,
          'component',
          contains('RECIPE $_recipeId'),
        ),
      ),
    );
  });

  testWidgets('Food Entry MEAL selection expands every component', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    database.seed(
      IndexedDbStoreNames.foodCatalogRecords,
      _foodId,
      _food(timestamp).toJson(),
    );
    database.seed(
      IndexedDbStoreNames.foodRecipeRecords,
      _recipeId,
      _recipe(timestamp).toJson(),
    );
    database.seed(
      IndexedDbStoreNames.foodMealMasterRecords,
      _mealId,
      _meal(timestamp).toJson(),
    );
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FoodInputForm(onSave: (_) async => true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('SELECT FROM FOOD DATABASE'));
    await tester.pumpAndSettle();
    expect(find.text('FOOD'), findsWidgets);
    expect(find.text('RECIPE'), findsOneWidget);
    expect(find.text('MEAL'), findsOneWidget);

    await tester.tap(find.text('MEAL'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('food-meal-master-$_mealId')));
    await tester.pumpAndSettle();

    expect(find.text('ゆで卵'), findsOneWidget);
    expect(find.text('朝食レシピ'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('MEAL list and editor have no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      final database = FakeIndexedDbDatabase();
      database.seed(
        IndexedDbStoreNames.foodCatalogRecords,
        _foodId,
        _food(timestamp).toJson(),
      );
      database.seed(
        IndexedDbStoreNames.foodRecipeRecords,
        _recipeId,
        _recipe(timestamp).toJson(),
      );
      database.seed(
        IndexedDbStoreNames.foodMealMasterRecords,
        _mealId,
        _meal(timestamp).toJson(),
      );
      final foods = IndexedDbFoodCatalogRepository(database);
      final recipes = IndexedDbFoodRecipeRepository(database);
      final meals = IndexedDbFoodMealMasterRepository(database);
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: FoodCatalogPage(
            repository: foods,
            recipeRepository: recipes,
            mealRepository: meals,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (width == 320) {
        expect(tester.getSize(find.text('RECIPE')).height, lessThan(30));
      }
      await tester.tap(find.text('MEAL'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('朝食定番'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: FoodMealMasterEditorPage(
            repository: meals,
            catalogRepository: foods,
            recipeRepository: recipes,
            initialMeal: _meal(timestamp),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      if (width <= 390) {
        await tester.pumpWidget(
          MaterialApp(
            home: FoodCatalogPage(
              repository: foods,
              recipeRepository: recipes,
              mealRepository: meals,
              selectionMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('SELECT MASTER'), findsOneWidget);
        expect(tester.getSize(find.text('RECIPE')).height, lessThan(30));
        expect(tester.takeException(), isNull);
      }
    });
  }
}

FoodMealMaster _meal(DateTime timestamp) => FoodMealMaster(
  mealMasterId: _mealId,
  name: '朝食定番',
  components: [
    FoodMealMasterComponent(
      componentId: _component1Id,
      componentType: FoodMealMasterComponentType.food,
      foodReferenceId: _foodId,
      quantity: FoodQuantityDefinition(value: 2, unit: FoodQuantityUnit.piece),
      sortOrder: 0,
    ),
    FoodMealMasterComponent(
      componentId: _component2Id,
      componentType: FoodMealMasterComponentType.recipe,
      recipeReferenceId: _recipeId,
      quantity: FoodQuantityDefinition(
        value: 0.5,
        unit: FoodQuantityUnit.serving,
      ),
      sortOrder: 1,
    ),
  ],
  isArchived: false,
  createdAt: timestamp,
  updatedAt: timestamp,
);

FoodCatalogEntry _food(DateTime timestamp) => FoodCatalogEntry(
  foodId: _foodId,
  name: 'ゆで卵',
  category: FoodCatalogCategory.ingredient,
  baseQuantity: FoodQuantityDefinition(value: 1, unit: FoodQuantityUnit.piece),
  nutrition: NutritionSnapshot(
    calories: 80,
    protein: 7.6,
    fat: 6.2,
    carbohydrate: 0.2,
  ),
  nutritionStatus: NutritionStatus.declared,
  provenance: FoodDataProvenance(
    sourceType: FoodProvenanceSourceType.userInput,
    capturedAt: timestamp,
  ),
  isArchived: false,
  createdAt: timestamp,
  updatedAt: timestamp,
);

FoodRecipeDefinition _recipe(DateTime timestamp) => FoodRecipeDefinition(
  recipeId: _recipeId,
  name: '朝食レシピ',
  ingredients: [
    RecipeIngredientV2(
      ingredientId: _ingredientId,
      foodReferenceId: _foodId,
      nameSnapshot: 'ゆで卵',
      quantity: FoodQuantityDefinition(value: 1, unit: FoodQuantityUnit.piece),
      nutritionSnapshot: _food(timestamp).nutrition,
      nutritionStatus: NutritionStatus.declared,
      provenanceSnapshot: _food(timestamp).provenance,
      sortOrder: 0,
    ),
  ],
  yieldQuantity: FoodQuantityDefinition(
    value: 1,
    unit: FoodQuantityUnit.serving,
  ),
  servingCount: 1,
  nutrition: _food(timestamp).nutrition,
  nutritionStatus: NutritionStatus.calculated,
  provenance: FoodDataProvenance(
    sourceType: FoodProvenanceSourceType.recipeCalculation,
    capturedAt: timestamp,
  ),
  isArchived: false,
  createdAt: timestamp,
  updatedAt: timestamp,
);

const _mealId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _component1Id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _component2Id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _foodId = '11111111-1111-4111-8111-111111111111';
const _recipeId = '22222222-2222-4222-8222-222222222222';
const _ingredientId = '33333333-3333-4333-8333-333333333333';
