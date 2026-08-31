import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/food_recipe_page.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/recipe_models_v2.dart';
import 'package:or_app/features/food/repository/food_catalog_repository.dart';
import 'package:or_app/features/food/repository/food_meal_id_generator.dart';
import 'package:or_app/features/food/repository/food_recipe_repository.dart';
import 'package:or_app/features/food/services/food_catalog_meal_mapper.dart';

void main() {
  testWidgets('recipe list excludes archived definitions and supports search', (
    tester,
  ) async {
    final recipes = _MemoryRecipeRepository([
      _recipe(name: 'Rice Bowl'),
      _recipe(
        id: '44444444-4444-4444-8444-444444444444',
        name: 'Archived Soup',
        archived: true,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogPage(
          repository: _MemoryCatalogRepository([_food()]),
          recipeRepository: recipes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('RECIPE'));
    await tester.pumpAndSettle();
    expect(find.text('Rice Bowl'), findsOneWidget);
    expect(find.text('Archived Soup'), findsNothing);
    expect(find.textContaining('1 INGREDIENTS'), findsOneWidget);
    expect(find.textContaining('YIELD 2 serving'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('food-catalog-search')),
      'missing',
    );
    await tester.pump();
    expect(find.text('RECIPE NOT FOUND'), findsOneWidget);
  });

  testWidgets(
    'recipe create uses catalog snapshots, calculates, and archives',
    (tester) async {
      final catalog = _MemoryCatalogRepository([_food()]);
      final recipes = _MemoryRecipeRepository(const []);
      final ids = FoodMealIdGenerator(nextInt: (_) => 7);
      await tester.pumpWidget(
        MaterialApp(
          home: FoodRecipeEditorPage(
            repository: recipes,
            catalogRepository: catalog,
            now: () => DateTime.utc(2026, 8, 31),
            idGenerator: ids,
          ),
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('recipe-name')), 'Bowl');
      await tester.tap(find.byKey(const ValueKey('recipe-add-ingredient')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rice'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'ADD'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE RECIPE'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.textContaining('286 kcal'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('recipe-save')));
      await tester.tap(find.byKey(const ValueKey('recipe-save')));
      await tester.pumpAndSettle();

      final saved = (await recipes.list()).single;
      expect(saved.name, 'Bowl');
      expect(saved.ingredients.single.foodReferenceId, _foodId);
      expect(saved.ingredients.single.nameSnapshot, 'Rice');
      expect(saved.nutrition.calories, 286);
      expect(saved.nutritionStatus, NutritionStatus.calculated);
      expect(
        saved.provenance.sourceType,
        FoodProvenanceSourceType.recipeCalculation,
      );

      await catalog.update(
        FoodCatalogEntry.fromJson({
          ..._food().toJson(),
          'name': 'Changed Rice',
          'nutrition': NutritionSnapshot(calories: 999).toJson(),
        }),
      );
      expect(saved.ingredients.single.nameSnapshot, 'Rice');
      expect(saved.nutrition.calories, 286);

      await recipes.archive(saved.recipeId);
      expect((await recipes.list()).single.isArchived, isTrue);
    },
  );

  test('recipe meal mapping copies a serving snapshot and reference', () {
    final recipe = _recipe(name: 'Rice Bowl');
    const meal = MealData(
      date: '2026-08-31',
      mealType: 'Lunch',
      items: [
        FoodItem(
          name: 'Rice Bowl',
          calories: 143,
          protein: 6.1,
          fat: 9.65,
          carbohydrate: 8.1,
          quantity: 2,
        ),
      ],
      memo: '',
      id: 'legacy-id',
    );
    final mapped = FoodCatalogMealMapper.map(
      meal: meal,
      catalogSources: const [null],
      recipeSources: [recipe],
      localDate: '2026-08-31',
      timestamp: DateTime.utc(2026, 8, 31),
      idGenerator: FoodMealIdGenerator(nextInt: (_) => 8),
    );

    final item = mapped.items.single;
    expect(item.recipeReferenceId, recipe.recipeId);
    expect(item.foodReferenceId, isNull);
    expect(item.quantity.unit, FoodQuantityUnit.serving);
    expect(item.quantity.value, 2);
    expect(item.nutritionPerBase.calories, 143);
    expect(item.nutritionConsumed.calories, 286);
  });

  test('recipe meal mapping preserves a fractional serving', () {
    final recipe = _recipe(name: 'Rice Bowl');
    const meal = MealData(
      date: '2026-08-31',
      mealType: 'Lunch',
      items: [
        FoodItem(
          name: 'Rice Bowl',
          calories: 143,
          protein: 6.1,
          fat: 9.65,
          carbohydrate: 8.1,
          amount: 0.5,
          baseAmount: 1,
          baseUnit: FoodBaseUnit.g,
          amountMode: FoodAmountMode.baseMultiplier,
        ),
      ],
      memo: '',
      id: 'legacy-id',
    );
    final mapped = FoodCatalogMealMapper.map(
      meal: meal,
      catalogSources: const [null],
      recipeSources: [recipe],
      localDate: '2026-08-31',
      timestamp: DateTime.utc(2026, 8, 31),
      idGenerator: FoodMealIdGenerator(nextInt: (_) => 9),
    );

    final item = mapped.items.single;
    expect(item.quantity.value, 0.5);
    expect(item.quantity.unit, FoodQuantityUnit.serving);
    expect(item.nutritionConsumed.calories, 71.5);
  });

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('recipe editor is overflow-free at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: FoodRecipeEditorPage(
            repository: _MemoryRecipeRepository(const []),
            catalogRepository: _MemoryCatalogRepository([_food()]),
            initialRecipe: _recipe(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

const _foodId = '11111111-1111-4111-8111-111111111111';

FoodCatalogEntry _food() {
  final timestamp = DateTime.utc(2026, 8, 31);
  return FoodCatalogEntry(
    foodId: _foodId,
    name: 'Rice',
    category: FoodCatalogCategory.ingredient,
    baseQuantity: FoodQuantityDefinition(
      value: 100,
      unit: FoodQuantityUnit.gram,
    ),
    nutrition: NutritionSnapshot(
      calories: 286,
      protein: 12.2,
      fat: 19.3,
      carbohydrate: 16.2,
    ),
    nutritionStatus: NutritionStatus.declared,
    provenance: _provenance(timestamp),
    isArchived: false,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

FoodRecipeDefinition _recipe({
  String id = '22222222-2222-4222-8222-222222222222',
  String name = 'Recipe',
  bool archived = false,
}) {
  final timestamp = DateTime.utc(2026, 8, 31);
  return FoodRecipeDefinition(
    recipeId: id,
    name: name,
    ingredients: [
      RecipeIngredientV2(
        ingredientId: '33333333-3333-4333-8333-333333333333',
        foodReferenceId: _foodId,
        nameSnapshot: 'Rice',
        quantity: FoodQuantityDefinition(
          value: 100,
          unit: FoodQuantityUnit.gram,
        ),
        nutritionSnapshot: _food().nutrition,
        nutritionStatus: NutritionStatus.declared,
        provenanceSnapshot: _provenance(timestamp),
        sortOrder: 0,
      ),
    ],
    yieldQuantity: FoodQuantityDefinition(
      value: 2,
      unit: FoodQuantityUnit.serving,
    ),
    servingCount: 2,
    nutrition: _food().nutrition,
    nutritionStatus: NutritionStatus.calculated,
    provenance: FoodDataProvenance(
      sourceType: FoodProvenanceSourceType.recipeCalculation,
      capturedAt: timestamp,
    ),
    isArchived: archived,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

FoodDataProvenance _provenance(DateTime timestamp) => FoodDataProvenance(
  sourceType: FoodProvenanceSourceType.userInput,
  capturedAt: timestamp,
);

class _MemoryCatalogRepository implements FoodCatalogRepository {
  _MemoryCatalogRepository(Iterable<FoodCatalogEntry> entries)
    : _entries = {for (final entry in entries) entry.foodId: entry};
  final Map<String, FoodCatalogEntry> _entries;

  @override
  Future<void> archive(String foodId) async {}
  @override
  Future<void> create(FoodCatalogEntry entry) async =>
      _entries[entry.foodId] = entry;
  @override
  Future<void> delete(String foodId) async => _entries.remove(foodId);
  @override
  Future<List<FoodCatalogEntry>> list() async => _entries.values.toList();
  @override
  Future<FoodCatalogEntry?> readById(String foodId) async => _entries[foodId];
  @override
  Future<void> update(FoodCatalogEntry entry) async =>
      _entries[entry.foodId] = entry;
}

class _MemoryRecipeRepository implements FoodRecipeRepository {
  _MemoryRecipeRepository(Iterable<FoodRecipeDefinition> recipes)
    : _recipes = {for (final recipe in recipes) recipe.recipeId: recipe};
  final Map<String, FoodRecipeDefinition> _recipes;

  @override
  Future<void> archive(String recipeId) async {
    final recipe = _recipes[recipeId]!;
    _recipes[recipeId] = FoodRecipeDefinition.fromJson({
      ...recipe.toJson(),
      'isArchived': true,
    });
  }

  @override
  Future<void> create(FoodRecipeDefinition recipe) async =>
      _recipes[recipe.recipeId] = recipe;
  @override
  Future<List<FoodRecipeDefinition>> list() async => _recipes.values.toList();
  @override
  Future<FoodRecipeDefinition?> readById(String recipeId) async =>
      _recipes[recipeId];
  @override
  Future<void> update(FoodRecipeDefinition recipe) async =>
      _recipes[recipe.recipeId] = recipe;
}
