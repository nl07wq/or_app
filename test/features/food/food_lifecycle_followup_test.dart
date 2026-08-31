import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/food/food_entry_page.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/recipe_models_v2.dart';
import 'package:or_app/features/food/services/food_submit_service.dart';
import 'package:or_app/features/food/widgets/food_item_list.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;

  setUp(() {
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    seedOperationState(database, '2026-08-31');
    foodSummaryNotifier.value = null;
  });

  tearDown(() {
    foodSummaryNotifier.value = null;
    AppRepositoryRegistry.resetForTesting();
  });

  testWidgets(
    "Food Entry TODAY'S TOTAL follows mixed Formal create update delete",
    (tester) async {
      final operationDate = operationDateServiceFromFuture(
        Future.value(operationStateForTest('2026-08-31')),
      );
      await tester.pumpWidget(
        MaterialApp(home: FoodEntryPage(operationDateService: operationDate)),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 kcal'), findsOneWidget);

      await AppRepositoryRegistry.container.food.save(
        const MealData(
          id: 'water-record',
          date: '2026-08-31',
          mealType: 'Water',
          items: [],
          memo: '',
          waterMl: 500,
        ),
      );
      await refreshFoodSummary(localDate: '2026-08-31');
      await tester.pump();
      expect(find.text('500 ml'), findsOneWidget);

      final first = _meal(
        id: '11111111-1111-4111-8111-111111111111',
        calories: 184,
      );
      final second = _meal(
        id: '22222222-2222-4222-8222-222222222222',
        calories: 97,
      );
      await AppRepositoryRegistry.container.dailyMealsV2.create(first);
      await refreshFoodSummary(localDate: '2026-08-31');
      await tester.pump();
      expect(find.text('184 kcal'), findsOneWidget);

      await AppRepositoryRegistry.container.dailyMealsV2.create(second);
      await refreshFoodSummary(localDate: '2026-08-31');
      await tester.pump();
      expect(find.text('281 kcal'), findsOneWidget);

      await AppRepositoryRegistry.container.dailyMealsV2.update(
        _meal(id: first.mealId, calories: 200, createdAt: first.createdAt),
      );
      await refreshFoodSummary(localDate: '2026-08-31');
      await tester.pump();
      expect(find.text('297 kcal'), findsOneWidget);

      await FoodSubmitService.deleteV2(second);
      await tester.pump();
      expect(find.text('200 kcal'), findsOneWidget);
      expect(
        await AppRepositoryRegistry.container.dailyMealsV2.readById(
          second.mealId,
        ),
        isNull,
      );

      await FoodSubmitService.deleteV2(
        (await AppRepositoryRegistry.container.dailyMealsV2.readById(
          first.mealId,
        ))!,
      );
      await tester.pump();
      expect(find.text('0 kcal'), findsOneWidget);
      expect(find.text('500 ml'), findsOneWidget);
    },
  );

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('compact Meal item UI is responsive at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodItemList(
                items: const [
                  FoodItem(
                    name: '長い食品名でも読みやすさを維持する食材',
                    calories: 33,
                    protein: 1,
                    fat: 0.1,
                    carbohydrate: 8.4,
                    amount: 1,
                    baseAmount: 100,
                    baseUnit: FoodBaseUnit.g,
                    amountMode: FoodAmountMode.baseMultiplier,
                  ),
                ],
                catalogSources: [_catalog()],
                recipeSources: const [null],
                onDelete: (_) {},
                onTap: (_) {},
                onQuantityChanged: (_, _) {},
                editableItemCount: 1,
                actionIcon: Icons.add,
                actionText: 'ADD FOOD',
                onAction: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('food-thumbnail-meat')), findsOneWidget);
      expect(find.text('食材  100g'), findsOneWidget);
      expect(find.text('33kcal  P 1g  F 0.1g  C 8.4g'), findsOneWidget);
      expect(find.text('Calculated'), findsNothing);
      expect(find.textContaining('Calories :'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Recipe Meal preview uses serving instead of transient g unit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodItemList(
            items: const [
              FoodItem(
                name: 'Recipe Meal',
                calories: 300,
                protein: 20,
                fat: 10,
                carbohydrate: 30,
                amount: 0.5,
                baseAmount: 1,
                baseUnit: FoodBaseUnit.g,
                amountMode: FoodAmountMode.baseMultiplier,
              ),
            ],
            catalogSources: const [null],
            recipeSources: [_recipe()],
            onDelete: (_) {},
            onTap: (_) {},
            onQuantityChanged: (_, _) {},
            editableItemCount: 1,
            actionIcon: Icons.add,
            actionText: 'ADD FOOD',
            onAction: () {},
          ),
        ),
      ),
    );

    expect(find.text('RECIPE  0.5serving'), findsOneWidget);
    expect(find.textContaining('0.5g'), findsNothing);
    expect(
      find.byKey(const ValueKey('food-thumbnail-fallback')),
      findsOneWidget,
    );
  });
}

DailyMealV2 _meal({
  required String id,
  required double calories,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 8, 31, 12);
  return DailyMealV2(
    mealId: id,
    localDate: '2026-08-31',
    mealType: DailyMealTypeV2.lunch,
    items: [
      DailyMealItemSnapshot(
        mealItemId: '${id.substring(0, 35)}2',
        nameSnapshot: 'Meal $id',
        quantity: FoodQuantityDefinition(
          value: 1,
          unit: FoodQuantityUnit.serving,
        ),
        nutritionPerBase: NutritionSnapshot(
          calories: calories,
          protein: 1,
          fat: 2,
          carbohydrate: 3,
        ),
        nutritionConsumed: NutritionSnapshot(
          calories: calories,
          protein: 1,
          fat: 2,
          carbohydrate: 3,
        ),
        provenanceSnapshot: FoodDataProvenance(
          sourceType: FoodProvenanceSourceType.userInput,
          capturedAt: timestamp,
        ),
        nutritionStatusSnapshot: NutritionStatus.declared,
        sortOrder: 0,
      ),
    ],
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

FoodCatalogEntry _catalog() {
  final timestamp = DateTime.utc(2026, 8, 31);
  return FoodCatalogEntry(
    foodId: '33333333-3333-4333-8333-333333333333',
    name: 'Food',
    category: FoodCatalogCategory.ingredient,
    baseQuantity: FoodQuantityDefinition(
      value: 100,
      unit: FoodQuantityUnit.gram,
    ),
    nutrition: NutritionSnapshot(calories: 33),
    nutritionStatus: NutritionStatus.declared,
    provenance: FoodDataProvenance(
      sourceType: FoodProvenanceSourceType.userInput,
      capturedAt: timestamp,
    ),
    isArchived: false,
    visualKey: FoodVisualKey.meat,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

FoodRecipeDefinition _recipe() {
  final timestamp = DateTime.utc(2026, 8, 31);
  return FoodRecipeDefinition(
    recipeId: '44444444-4444-4444-8444-444444444444',
    name: 'Recipe Meal',
    ingredients: [
      RecipeIngredientV2(
        ingredientId: '55555555-5555-4555-8555-555555555555',
        foodReferenceId: '33333333-3333-4333-8333-333333333333',
        nameSnapshot: 'Food',
        quantity: FoodQuantityDefinition(
          value: 100,
          unit: FoodQuantityUnit.gram,
        ),
        nutritionSnapshot: NutritionSnapshot(calories: 300),
        nutritionStatus: NutritionStatus.declared,
        provenanceSnapshot: FoodDataProvenance(
          sourceType: FoodProvenanceSourceType.userInput,
          capturedAt: timestamp,
        ),
        sortOrder: 0,
      ),
    ],
    yieldQuantity: FoodQuantityDefinition(
      value: 1,
      unit: FoodQuantityUnit.serving,
    ),
    servingCount: 1,
    nutrition: NutritionSnapshot(calories: 300),
    nutritionStatus: NutritionStatus.calculated,
    provenance: FoodDataProvenance(
      sourceType: FoodProvenanceSourceType.recipeCalculation,
      capturedAt: timestamp,
    ),
    isArchived: false,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
