import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/food_recipe_page.dart';
import 'package:or_app/features/food/food_nutrition_formatter.dart';
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

    final foodName = tester.widget<Text>(
      find.byKey(const ValueKey('food-catalog-name-$_foodId')),
    );
    final foodMetadata = tester.widget<Text>(
      find.byKey(const ValueKey('food-catalog-metadata-$_foodId')),
    );
    final foodNutrition = tester.widget<Text>(
      find.byKey(const ValueKey('food-catalog-nutrition-$_foodId')),
    );

    await tester.tap(find.text('RECIPE'));
    await tester.pumpAndSettle();
    expect(find.text('Rice Bowl'), findsOneWidget);
    expect(find.text('Archived Soup'), findsNothing);
    expect(find.textContaining('INGREDIENTS'), findsNothing);
    expect(find.textContaining('2 SERVINGS'), findsOneWidget);
    expect(find.textContaining('YIELD 2 serving'), findsNothing);
    expect(find.text('286kcal  P 12.2g  F 19.3g  C 16.2g'), findsOneWidget);
    const recipeId = '22222222-2222-4222-8222-222222222222';
    final serving = find.byKey(ValueKey('food-recipe-serving-$recipeId'));
    final nutrition = find.byKey(ValueKey('food-recipe-nutrition-$recipeId'));
    expect(
      tester.getRect(serving).top,
      lessThan(tester.getRect(nutrition).top),
    );
    final recipeName = tester.widget<Text>(
      find.byKey(ValueKey('food-recipe-name-$recipeId')),
    );
    final servingText = tester.widget<Text>(serving);
    final recipeNutrition = tester.widget<Text>(nutrition);
    expect(recipeName.style?.fontWeight, FontWeight.w700);
    expect(recipeName.style?.fontSize, foodName.style?.fontSize);
    expect(recipeName.style?.fontWeight, foodName.style?.fontWeight);
    expect(servingText.style?.fontSize, foodMetadata.style?.fontSize);
    expect(servingText.style?.color, foodMetadata.style?.color);
    expect(recipeNutrition.style?.fontSize, foodNutrition.style?.fontSize);
    expect(recipeNutrition.style?.color, foodNutrition.style?.color);

    await tester.enterText(
      find.byKey(const ValueKey('food-catalog-search')),
      'missing',
    );
    await tester.pump();
    expect(find.text('RECIPE NOT FOUND'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('food-catalog-search')),
      '',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('food-recipe-$recipeId')));
    await tester.pumpAndSettle();
    expect(find.text('EDIT RECIPE'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('recipe list metadata is overflow-free at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recipes = _MemoryRecipeRepository([
        _recipe(name: '非常に長いレシピ名でも読みやすさを維持するテスト'),
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

      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.text('2 SERVINGS'), findsOneWidget);
      expect(find.text('286kcal  P 12.2g  F 19.3g  C 16.2g'), findsOneWidget);
      expect(find.textContaining('INGREDIENTS'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

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
      await tester.scrollUntilVisible(
        find.text('Rice'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('100 g'), findsOneWidget);
      expect(find.text('TOTAL PFC BALANCE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('recipe-total-pfc-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('recipe-total-pfc-donut')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('recipe-total-nutrition')),
        findsNothing,
      );
      expect(find.text('286'), findsOneWidget);
      expect(find.text('12.2 g'), findsWidgets);
      expect(find.text('19.3 g'), findsWidgets);
      expect(find.text('16.2 g'), findsWidgets);
      final servingMetadata = find.byKey(
        const ValueKey('recipe-serving-metadata'),
      );
      final totalCard = find.byKey(const ValueKey('recipe-total-pfc-card'));
      expect(
        tester.getRect(servingMetadata).top,
        lessThan(tester.getRect(totalCard).top),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('recipe-save'), skipOffstage: false),
      );
      await tester.pumpAndSettle();
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

  test('recipe display formatter removes floating-point artifacts', () {
    expect(FoodNutritionFormatter.displayNumber(48.879999999999995), '48.9');
    expect(FoodNutritionFormatter.displayNumber(9.684999999999999), '9.7');
    expect(FoodNutritionFormatter.displayNumber(49.0), '49');
    expect(
      FoodNutritionFormatter.quantity(
        FoodQuantityDefinition(value: 22.5, unit: FoodQuantityUnit.gram),
      ),
      '22.5 g',
    );
    expect(
      FoodNutritionFormatter.quantity(
        FoodQuantityDefinition(value: 22.5, unit: FoodQuantityUnit.milliliter),
      ),
      '22.5 ml',
    );
    expect(FoodNutritionFormatter.servings(1), '1 SERVING');
    expect(FoodNutritionFormatter.servings(2), '2 SERVINGS');
    expect(FoodNutritionFormatter.servings(0.5), '0.5 SERVING');
    expect(
      FoodNutritionFormatter.compactQuantity(
        FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
      ),
      '100g',
    );
    expect(
      FoodNutritionFormatter.compactQuantity(
        FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.milliliter),
      ),
      '100ml',
    );
    expect(
      FoodNutritionFormatter.compactNutrition(
        NutritionSnapshot(
          calories: 33,
          protein: 1,
          fat: 0.1,
          carbohydrate: 8.4,
        ),
      ),
      '33kcal  P 1g  F 0.1g  C 8.4g',
    );
  });

  test('recipe display formatting does not mutate formal precision', () {
    const formalProtein = 48.879999999999995;
    final snapshot = NutritionSnapshot(
      calories: 332.7,
      protein: formalProtein,
      fat: 9.684999999999999,
      carbohydrate: null,
    );

    expect(
      FoodNutritionFormatter.nutrition(snapshot),
      '332.7 kcal · P 48.9 g · F 9.7 g · C —',
    );
    expect(snapshot.protein, formalProtein);
    expect(snapshot.carbohydrate, isNull);
    expect(
      FoodNutritionFormatter.compactNutrition(snapshot),
      '332.7kcal  P 48.9g  F 9.7g  C —',
    );
  });

  test('recipe summary avoids duplicate serving semantics', () {
    expect(foodRecipeSummaryLabel(_recipe()), '2 SERVINGS');
    expect(
      foodRecipeSummaryLabel(
        FoodRecipeDefinition.fromJson({
          ..._recipe().toJson(),
          'yieldQuantity': FoodQuantityDefinition(
            value: 500,
            unit: FoodQuantityUnit.gram,
          ).toJson(),
          'servingCount': 1,
        }),
      ),
      'YIELD 500 g · 1 SERVING',
    );
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
      expect(find.text('TOTAL PFC BALANCE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('recipe-total-pfc-horizontal')),
        findsOneWidget,
      );
      final ingredientName = tester.widget<Text>(
        find.byKey(const ValueKey('recipe-ingredient-name-0')),
      );
      final ingredientMetadata = tester.widget<Text>(find.text('100 g'));
      expect(ingredientName.style?.fontWeight, FontWeight.w700);
      expect(
        ingredientName.style?.fontSize,
        greaterThan(ingredientMetadata.style!.fontSize!),
      );
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
