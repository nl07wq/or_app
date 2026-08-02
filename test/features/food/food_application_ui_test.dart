import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/features/food/daily_meal_v2_page.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/food/food_recipe_page.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/recipe_models_v2.dart';
import 'package:or_app/features/food/services/food_application_service.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;

  setUp(() {
    database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-08-02');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  test('quantity calculation supports physical and explicit count basis', () {
    final nutrition = NutritionSnapshot(calories: 200, protein: 10);
    final physical = FoodApplicationService.calculateConsumed(
      base: FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
      consumed: FoodQuantityDefinition(value: 150, unit: FoodQuantityUnit.gram),
      nutritionPerBase: nutrition,
    );
    expect(physical.multiplier, 1.5);
    expect(physical.nutrition!.calories, 300);

    final count = FoodApplicationService.calculateConsumed(
      base: FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
      consumed: FoodQuantityDefinition(
        value: 2,
        unit: FoodQuantityUnit.piece,
        basisValue: 50,
        basisUnit: FoodQuantityUnit.gram,
      ),
      nutritionPerBase: nutrition,
    );
    expect(count.multiplier, 1);
    expect(count.nutrition!.protein, 10);
  });

  test('quantity calculation refuses an unconfirmed conversion', () {
    final result = FoodApplicationService.calculateConsumed(
      base: FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
      consumed: FoodQuantityDefinition(value: 1, unit: FoodQuantityUnit.pack),
      nutritionPerBase: NutritionSnapshot(calories: 200),
    );
    expect(result.multiplier, isNull);
    expect(result.nutrition, isNull);
  });

  testWidgets('FOOD module exposes the five formal entry sections', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FoodPage()));
    await tester.pumpAndSettle();
    expect(find.text('REPORT SYNC'), findsOneWidget);
    expect(find.text('MANUAL ENTRY'), findsOneWidget);
    expect(find.text('RECORD'), findsWidgets);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    expect(find.text('FOOD DATABASE'), findsWidgets);
    expect(find.text('RECIPE DATABASE'), findsWidgets);
  });

  testWidgets('manual entry opens Daily Meal v2 and fixes Operation Date', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FoodPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD MEAL'));
    await tester.pumpAndSettle();
    expect(find.byType(DailyMealV2Page), findsOneWidget);
    expect(find.text('Operation Date: 2026-08-02'), findsOneWidget);
    expect(find.text('SAVE MEAL'), findsOneWidget);
  });

  testWidgets('water entry hides item actions and requires water input', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DailyMealV2Page()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water').last);
    await tester.pumpAndSettle();
    expect(find.text('ADD CUSTOM ITEM'), findsNothing);
    expect(find.widgetWithText(TextField, 'Water Ml'), findsOneWidget);
  });

  testWidgets('catalog list excludes archived until explicitly requested', (
    tester,
  ) async {
    await AppRepositoryRegistry.container.foodCatalog.create(
      _catalog('Active', false),
    );
    await AppRepositoryRegistry.container.foodCatalog.create(
      _catalog('Archived', true),
    );
    await tester.pumpWidget(const MaterialApp(home: FoodCatalogPage()));
    await tester.pumpAndSettle();
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Archived'), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsOneWidget);
  });

  testWidgets('catalog editor validates and archives without deleting', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FoodCatalogEditorPage()));
    await tester.dragUntilVisible(
      find.widgetWithText(OperationButton, 'ADD FOOD'),
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.tap(find.widgetWithText(OperationButton, 'ADD FOOD'));
    await tester.pump();
    expect(find.text('Name is required.'), findsOneWidget);

    final created = _catalog('Oats', false);
    await AppRepositoryRegistry.container.foodCatalog.create(created);

    await tester.pumpWidget(
      MaterialApp(home: FoodCatalogEditorPage(entry: created)),
    );
    await tester.dragUntilVisible(
      find.widgetWithText(OperationButton, 'ARCHIVE FOOD'),
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.tap(find.widgetWithText(OperationButton, 'ARCHIVE FOOD'));
    await tester.pumpAndSettle();
    expect(
      (await AppRepositoryRegistry.container.foodCatalog.list())
          .single
          .isArchived,
      isTrue,
    );
  });

  testWidgets('recipe list exposes saved snapshots', (tester) async {
    final catalog = _catalog('Rice', false);
    final now = DateTime.utc(2026, 8, 2);
    await AppRepositoryRegistry.container.foodRecipes.create(
      FoodRecipeDefinition(
        recipeId: FoodApplicationService.newId(),
        name: 'Rice Bowl',
        ingredients: [
          RecipeIngredientV2(
            ingredientId: FoodApplicationService.newId(),
            foodReferenceId: catalog.foodId,
            nameSnapshot: catalog.name,
            quantity: catalog.baseQuantity,
            nutritionSnapshot: catalog.nutrition,
            nutritionStatus: catalog.nutritionStatus,
            provenanceSnapshot: catalog.provenance,
            sortOrder: 0,
          ),
        ],
        yieldQuantity: FoodQuantityDefinition(
          value: 1,
          unit: FoodQuantityUnit.serving,
        ),
        nutrition: catalog.nutrition,
        nutritionStatus: NutritionStatus.calculated,
        provenance: _provenance(FoodProvenanceSourceType.recipeCalculation),
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: FoodRecipePage()));
    await tester.pumpAndSettle();
    expect(find.text('Rice Bowl'), findsOneWidget);
    expect(find.text('1 ingredients'), findsOneWidget);
  });

  test('saved meal snapshot does not follow later catalog updates', () async {
    final catalog = _catalog('Original', false);
    await AppRepositoryRegistry.container.foodCatalog.create(catalog);
    final item = FoodApplicationService.itemFromCatalog(
      catalog,
      FoodQuantityDefinition(value: 150, unit: FoodQuantityUnit.gram),
      0,
    );
    final now = DateTime.utc(2026, 8, 2);
    final meal = DailyMealV2(
      mealId: FoodApplicationService.newId(),
      localDate: '2026-08-02',
      mealType: DailyMealTypeV2.lunch,
      items: [item],
      createdAt: now,
      updatedAt: now,
    );
    await FoodApplicationService.createMeal(meal);
    await AppRepositoryRegistry.container.foodCatalog.update(
      FoodCatalogEntry.fromJson({...catalog.toJson(), 'name': 'Changed'}),
    );
    final stored = await AppRepositoryRegistry.container.dailyMealsV2.readById(
      meal.mealId,
    );
    expect(stored!.items.single.nameSnapshot, 'Original');
    expect(stored.items.single.nutritionConsumed.calories, 195);
  });

  testWidgets('Food pages have no overflow at responsive widths and themes', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final width in [320.0, 390.0, 900.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const DailyMealV2Page(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'width $width ${brightness.name}',
        );
      }
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

FoodCatalogEntry _catalog(String name, bool archived) {
  final now = DateTime.utc(2026, 8, 2);
  return FoodCatalogEntry(
    foodId: FoodApplicationService.newId(),
    name: name,
    category: FoodCatalogCategory.ingredient,
    baseQuantity: FoodQuantityDefinition(
      value: 100,
      unit: FoodQuantityUnit.gram,
    ),
    nutrition: NutritionSnapshot(calories: 130, protein: 2.5),
    nutritionStatus: NutritionStatus.declared,
    provenance: _provenance(FoodProvenanceSourceType.manufacturerLabel),
    isArchived: archived,
    createdAt: now,
    updatedAt: now,
  );
}

FoodDataProvenance _provenance(FoodProvenanceSourceType type) =>
    FoodDataProvenance(sourceType: type, capturedAt: DateTime.utc(2026, 8, 2));
