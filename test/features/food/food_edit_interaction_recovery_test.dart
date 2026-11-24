import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/food/food_edit_page.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_entry_sources.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/widgets/food_input_form.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('historical item edit remains operable at ${width.toInt()}dp', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_subject(onSave: (_, _) async => true));

      await _openFirstItem(tester);
      await tester.enterText(
        find.byKey(const ValueKey('meal-item-quantity-input')),
        '2',
      );
      await tester.pump();
      expect(_itemNutrition(tester, 0), contains('200kcal'));
      await tester.ensureVisible(
        find.byKey(const ValueKey('meal-item-delete-1')),
      );
      await tester.tap(find.byKey(const ValueKey('meal-item-delete-1')));
      await tester.pump();
      expect(find.text('MEAL ITEMS (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'historical item draft updates the visible list and outer UPDATE payload',
    (tester) async {
      MealData? submittedMeal;
      FoodEntrySources? submittedSources;
      await tester.pumpWidget(
        _subject(
          onSave: (meal, sources) async {
            submittedMeal = meal;
            submittedSources = sources;
            return true;
          },
        ),
      );

      await _openFirstItem(tester);
      final quantity = find.byKey(const ValueKey('meal-item-quantity-input'));
      await tester.enterText(quantity, '2');
      await tester.pump();

      expect(_itemNutrition(tester, 0), contains('200kcal'));
      expect(find.text('MEAL ITEMS (2)'), findsOneWidget);

      await tester.ensureVisible(find.text('UPDATE MEAL'));
      await tester.tap(find.text('UPDATE MEAL'));
      await tester.pumpAndSettle();

      expect(submittedMeal, isNotNull);
      expect(submittedMeal!.items, hasLength(2));
      expect(submittedMeal!.items.first.physicalAmount, 200);
      expect(submittedMeal!.items.first.totalCalories, 200);
      expect(submittedSources!.usageSetQuantities.first, 2);
      expect(submittedSources!.mealItemIds, ['item-a', 'item-b']);
    },
  );

  testWidgets(
    'historical item deletion is immediate while another item editor is open',
    (tester) async {
      MealData? submittedMeal;
      FoodEntrySources? submittedSources;
      await tester.pumpWidget(
        _subject(
          onSave: (meal, sources) async {
            submittedMeal = meal;
            submittedSources = sources;
            return true;
          },
        ),
      );

      await _openFirstItem(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('meal-item-delete-1')),
      );
      await tester.tap(find.byKey(const ValueKey('meal-item-delete-1')));
      await tester.pump();

      expect(find.text('MEAL ITEMS (1)'), findsOneWidget);
      expect(find.byKey(const ValueKey('meal-item-name-1')), findsNothing);
      expect(find.text('Second item'), findsNothing);

      await tester.ensureVisible(find.text('UPDATE MEAL'));
      await tester.tap(find.text('UPDATE MEAL'));
      await tester.pumpAndSettle();

      expect(submittedMeal!.items, hasLength(1));
      expect(submittedMeal!.items.single.name, 'First item');
      expect(submittedSources!.mealItemIds, ['item-a']);
    },
  );

  testWidgets('nested edit cancel keeps the historical item unchanged', (
    tester,
  ) async {
    MealData? submittedMeal;
    await tester.pumpWidget(
      _subject(
        onSave: (meal, _) async {
          submittedMeal = meal;
          return true;
        },
      ),
    );

    await _openFirstItem(tester);
    await tester.enterText(
      find.byKey(const ValueKey('meal-item-quantity-input')),
      '2',
    );
    await tester.pump();
    expect(_itemNutrition(tester, 0), contains('200kcal'));

    await tester.tap(find.byKey(const ValueKey('meal-item-edit-cancel')));
    await tester.pump();
    expect(_itemNutrition(tester, 0), contains('100kcal'));

    await tester.ensureVisible(find.text('UPDATE MEAL'));
    await tester.tap(find.text('UPDATE MEAL'));
    await tester.pumpAndSettle();
    expect(submittedMeal!.items.first.physicalAmount, 100);
  });

  testWidgets('legacy measured quantity changes its nutrition basis', (
    tester,
  ) async {
    MealData? submittedMeal;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FoodInputForm(
              initialMeal: _meal(),
              onSave: (meal) async {
                submittedMeal = meal;
                return true;
              },
            ),
          ),
        ),
      ),
    );

    await _openFirstItem(tester);
    await tester.enterText(
      find.byKey(const ValueKey('meal-item-quantity-input')),
      '50',
    );
    await tester.pump();
    expect(_itemNutrition(tester, 0), contains('200kcal'));

    await tester.ensureVisible(find.text('UPDATE MEAL'));
    await tester.tap(find.text('UPDATE MEAL'));
    await tester.pumpAndSettle();
    expect(submittedMeal!.items.first.baseAmount, 50);
    expect(submittedMeal!.items.first.totalCalories, 200);
  });

  testWidgets('historical FOOD edit interaction renderer captures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MealData? submittedMeal;
    FoodEntrySources? submittedSources;
    await tester.pumpWidget(
      _subject(
        onSave: (meal, sources) async {
          submittedMeal = meal;
          submittedSources = sources;
          return true;
        },
      ),
    );
    await expectLater(
      find.byType(FoodInputForm),
      matchesGoldenFile('goldens/food_edit_recovery_before.png'),
    );

    await _openFirstItem(tester);
    await tester.enterText(
      find.byKey(const ValueKey('meal-item-quantity-input')),
      '2',
    );
    await tester.pump();
    await expectLater(
      find.byType(FoodInputForm),
      matchesGoldenFile('goldens/food_edit_recovery_quantity.png'),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('meal-item-delete-1')),
    );
    await tester.tap(find.byKey(const ValueKey('meal-item-delete-1')));
    await tester.pump();
    await expectLater(
      find.byType(FoodInputForm),
      matchesGoldenFile('goldens/food_edit_recovery_removed.png'),
    );

    await tester.ensureVisible(find.text('UPDATE MEAL'));
    await tester.tap(find.text('UPDATE MEAL'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FoodInputForm(
              initialMeal: submittedMeal,
              initialSources: submittedSources,
              onSave: (_) async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(FoodInputForm),
      matchesGoldenFile('goldens/food_edit_recovery_reopened.png'),
    );
  });

  group('DailyMealV2 persistence', () {
    late FakeIndexedDbDatabase database;
    late AppInitializationController controller;

    setUp(() {
      database = FakeIndexedDbDatabase();
      controller = AppInitializationController()..markReady();
      AppRepositoryRegistry.beginStartup(controller: controller);
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
      seedOperationState(database, '2026-11-24');
    });

    tearDown(AppRepositoryRegistry.resetForTesting);

    testWidgets(
      'historical V2 edit persists changed content and reopens that snapshot',
      (tester) async {
        final original = _dailyMealV2();
        await AppRepositoryRegistry.container.dailyMealsV2.create(original);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DailyMealV2EditPage(meal: original),
                    ),
                  ),
                  child: const Text('OPEN EDITOR'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('OPEN EDITOR'));
        await tester.pumpAndSettle();

        await _openFirstItem(tester);
        await tester.enterText(
          find.byKey(const ValueKey('meal-item-quantity-input')),
          '2',
        );
        await tester.pump();
        expect(_itemNutrition(tester, 0), contains('200kcal'));

        await tester.ensureVisible(
          find.byKey(const ValueKey('meal-item-delete-1')),
        );
        await tester.tap(find.byKey(const ValueKey('meal-item-delete-1')));
        await tester.pump();
        expect(find.text('MEAL ITEMS (1)'), findsOneWidget);

        await tester.ensureVisible(find.text('UPDATE MEAL'));
        await tester.tap(find.text('UPDATE MEAL'));
        await tester.pumpAndSettle();
        final readBack = await AppRepositoryRegistry.container.dailyMealsV2
            .readById(original.mealId);
        expect(find.text('MEAL UPDATED'), findsOneWidget);
        expect(readBack, isNotNull);
        expect(readBack!.mealId, original.mealId);
        expect(readBack.items, hasLength(1));
        expect(readBack.items.single.mealItemId, _firstItemId);
        expect(readBack.items.single.quantity.value, 200);
        expect(readBack.items.single.usageSetAmount, 100);
        expect(readBack.items.single.usageSetQuantity, 2);
        expect(readBack.items.single.nutritionConsumed.calories, 200);

        await tester.pumpWidget(
          MaterialApp(home: DailyMealV2EditPage(meal: readBack)),
        );
        await tester.pumpAndSettle();
        expect(find.text('MEAL ITEMS (1)'), findsOneWidget);
        expect(_itemNutrition(tester, 0), contains('200kcal'));
        expect(find.text('Second item'), findsNothing);
      },
    );

    testWidgets(
      'historical legacy edit preserves ID and persists quantity and removal',
      (tester) async {
        final original = _meal();
        await AppRepositoryRegistry.container.food.save(original);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FoodEditPage(meal: original, returnAfterSave: true),
                    ),
                  ),
                  child: const Text('OPEN LEGACY EDITOR'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('OPEN LEGACY EDITOR'));
        await tester.pumpAndSettle();

        await _openFirstItem(tester);
        await tester.enterText(
          find.byKey(const ValueKey('meal-item-quantity-input')),
          '50',
        );
        await tester.pump();
        expect(_itemNutrition(tester, 0), contains('200kcal'));
        await tester.ensureVisible(
          find.byKey(const ValueKey('meal-item-delete-1')),
        );
        await tester.tap(find.byKey(const ValueKey('meal-item-delete-1')));
        await tester.pump();

        await tester.ensureVisible(find.text('UPDATE MEAL'));
        await tester.tap(find.text('UPDATE MEAL'));
        await tester.pumpAndSettle();

        final records = await AppRepositoryRegistry.container.food.findAll();
        expect(records, hasLength(1));
        expect(records.single.id, original.id);
        expect(records.single.items, hasLength(1));
        expect(records.single.items.single.baseAmount, 50);
        expect(records.single.items.single.totalCalories, 200);
      },
    );
  });
}

Widget _subject({
  required Future<bool> Function(MealData, FoodEntrySources) onSave,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: FoodInputForm(
        initialMeal: _meal(),
        initialSources: _sources(),
        onSave: (_) async => false,
        onSaveWithSources: onSave,
      ),
    ),
  ),
);

Future<void> _openFirstItem(WidgetTester tester) async {
  final first = find.byKey(const ValueKey('meal-item-name-0'));
  await tester.ensureVisible(first);
  await tester.tap(first);
  await tester.pumpAndSettle();
}

String _itemNutrition(WidgetTester tester, int index) => tester
    .widget<Text>(find.byKey(ValueKey('meal-item-nutrition-$index')))
    .data!;

MealData _meal() => const MealData(
  id: 'historical-meal',
  date: '2026-11-24',
  mealType: 'Dinner',
  memo: 'preserve me',
  items: [
    FoodItem(
      name: 'First item',
      calories: 100,
      protein: 10,
      fat: 5,
      carbohydrate: 20,
      amount: 100,
      baseAmount: 100,
      baseUnit: FoodBaseUnit.g,
      amountMode: FoodAmountMode.physicalAmount,
    ),
    FoodItem(
      name: 'Second item',
      calories: 50,
      protein: 2,
      fat: 1,
      carbohydrate: 9,
      amount: 50,
      baseAmount: 100,
      baseUnit: FoodBaseUnit.g,
      amountMode: FoodAmountMode.physicalAmount,
    ),
  ],
);

FoodEntrySources _sources() => FoodEntrySources(
  catalogSources: const [null, null],
  recipeSources: const [null, null],
  quantityUnits: const [FoodQuantityUnit.gram, FoodQuantityUnit.gram],
  mealItemIds: const ['item-a', 'item-b'],
  usageSetAmounts: const [100, null],
  usageSetQuantities: const [1, null],
  quantitySemantics: const [FoodMealQuantitySemantics.multiplicativeV21, null],
);

const _mealId = '11111111-1111-4111-8111-111111111111';
const _firstItemId = '22222222-2222-4222-8222-222222222222';
const _secondItemId = '33333333-3333-4333-8333-333333333333';

DailyMealV2 _dailyMealV2() {
  final timestamp = DateTime.utc(2025, 11, 24, 12);
  DailyMealItemSnapshot item({
    required String id,
    required String name,
    required double amount,
    required double calories,
    required int sortOrder,
    bool multiplicative = false,
  }) => DailyMealItemSnapshot(
    mealItemId: id,
    nameSnapshot: name,
    quantity: FoodQuantityDefinition(
      value: amount,
      unit: FoodQuantityUnit.gram,
    ),
    nutritionBasisQuantity: FoodQuantityDefinition(
      value: 100,
      unit: FoodQuantityUnit.gram,
    ),
    usageSetAmount: multiplicative ? amount : null,
    usageSetQuantity: multiplicative ? 1 : null,
    quantitySemantics: multiplicative
        ? FoodMealQuantitySemantics.multiplicativeV21
        : null,
    nutritionPerBase: NutritionSnapshot(
      calories: calories,
      protein: 10,
      fat: 5,
      carbohydrate: 20,
    ),
    nutritionConsumed: NutritionSnapshot(
      calories: calories * amount / 100,
      protein: 10 * amount / 100,
      fat: 5 * amount / 100,
      carbohydrate: 20 * amount / 100,
    ),
    provenanceSnapshot: FoodDataProvenance(
      sourceType: FoodProvenanceSourceType.userInput,
      capturedAt: timestamp,
    ),
    nutritionStatusSnapshot: NutritionStatus.declared,
    sortOrder: sortOrder,
  );

  return DailyMealV2(
    mealId: _mealId,
    localDate: '2026-11-24',
    mealType: DailyMealTypeV2.dinner,
    items: [
      item(
        id: _firstItemId,
        name: 'First item',
        amount: 100,
        calories: 100,
        sortOrder: 0,
        multiplicative: true,
      ),
      item(
        id: _secondItemId,
        name: 'Second item',
        amount: 50,
        calories: 50,
        sortOrder: 1,
      ),
    ],
    memo: 'preserve me',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
