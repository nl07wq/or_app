import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/meal_type.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/food/widgets/food_input_form.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  Widget subject() => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: FoodInputForm(onSave: (_) async => true),
      ),
    ),
  );

  Finder modeTab(String mode) => find.byKey(ValueKey('food-entry-tab-$mode'));

  Future<void> swipeMode(WidgetTester tester, double deltaX) async {
    final surface = find.byKey(
      const ValueKey('food-entry-input-mode-page-surface'),
    );
    final origin = tester.getTopLeft(surface) + const Offset(20, 20);
    await tester.flingFrom(origin, Offset(deltaX, 0), 1200);
    await tester.pumpAndSettle();
  }

  void expectActiveMode(WidgetTester tester, String mode) {
    final label = tester.widget<Text>(
      find.descendant(of: modeTab(mode), matching: find.text(_modeLabel(mode))),
    );
    expect(label.style?.fontWeight, FontWeight.bold);
  }

  testWidgets('compact selectors and input modes show only active content', (
    tester,
  ) async {
    await tester.pumpWidget(subject());

    expect(
      find.byKey(const ValueKey('food-entry-type-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('food-meal-type-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('food-entry-input-mode-tabs')),
      findsOneWidget,
    );
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('ENTRY TYPE'), findsOneWidget);
    expect(find.text('MEAL TYPE'), findsOneWidget);

    for (final label in ['MANUAL', 'FOOD', 'RECIPE', 'MEAL']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.byKey(const ValueKey('food-entry-tab-databaseFood')));
    await tester.pump();
    expect(find.text('SELECT FOOD FROM DATABASE'), findsNothing);
    expect(find.text('NAME'), findsNothing);
  });

  testWidgets('selector symbols use the app primary color and mode emphasis', (
    tester,
  ) async {
    await tester.pumpWidget(subject());

    final primary = Theme.of(
      tester.element(find.byKey(const ValueKey('food-entry-type-selector'))),
    ).colorScheme.primary;
    final mealIcon = tester.widget<Icon>(
      find
          .descendant(
            of: find.byKey(const ValueKey('food-entry-type-selector')),
            matching: find.byIcon(Icons.restaurant),
          )
          .first,
    );
    expect(mealIcon.color, primary);

    await tester.tap(find.byKey(const ValueKey('food-entry-tab-databaseFood')));
    await tester.pump();
    final foodText = tester.widget<Text>(find.text('FOOD').first);
    expect(foodText.style?.color, primary);
    expect(foodText.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('mode body restores the complete no-wrap swipe sequence', (
    tester,
  ) async {
    await _installFoods(1);
    await tester.pumpWidget(subject());
    expectActiveMode(tester, 'manual');

    await swipeMode(tester, -300);
    expectActiveMode(tester, 'databaseFood');
    expect(
      find.byKey(const ValueKey('food-entry-search-databaseFood')),
      findsOneWidget,
    );
    await swipeMode(tester, -300);
    expectActiveMode(tester, 'databaseRecipe');
    expect(
      find.byKey(const ValueKey('food-entry-search-databaseRecipe')),
      findsOneWidget,
    );
    await swipeMode(tester, -300);
    expectActiveMode(tester, 'databaseMeal');
    expect(
      find.byKey(const ValueKey('food-entry-search-databaseMeal')),
      findsOneWidget,
    );
    await swipeMode(tester, -300);
    expectActiveMode(tester, 'databaseMeal');

    await swipeMode(tester, 300);
    expectActiveMode(tester, 'databaseRecipe');
    await swipeMode(tester, 300);
    expectActiveMode(tester, 'databaseFood');
    await swipeMode(tester, 300);
    expectActiveMode(tester, 'manual');
    await swipeMode(tester, 300);
    expectActiveMode(tester, 'manual');
  });

  testWidgets('tab taps and body swipes share one selected mode', (
    tester,
  ) async {
    await _installFoods(1);
    await tester.pumpWidget(subject());

    await tester.tap(modeTab('databaseRecipe'));
    await tester.pumpAndSettle();
    expectActiveMode(tester, 'databaseRecipe');
    expect(
      find.byKey(const ValueKey('food-entry-search-databaseRecipe')),
      findsOneWidget,
    );

    await swipeMode(tester, 300);
    expectActiveMode(tester, 'databaseFood');
    await tester.tap(modeTab('databaseMeal'));
    await tester.pumpAndSettle();
    expectActiveMode(tester, 'databaseMeal');
  });

  testWidgets('search state survives body swipe navigation', (tester) async {
    await _installFoods(10);
    await tester.pumpWidget(subject());
    await tester.tap(modeTab('databaseFood'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('food-entry-search-databaseFood'));
    await tester.enterText(search, 'Food 9');
    await tester.pump();
    expectActiveMode(tester, 'databaseFood');

    await swipeMode(tester, -300);
    expectActiveMode(tester, 'databaseRecipe');
    await swipeMode(tester, 300);
    expectActiveMode(tester, 'databaseFood');
    expect(tester.widget<TextField>(search).controller!.text, 'Food 9');
    expect(
      find.byKey(ValueKey('food-entry-inline-food-${_foodId(9)}')),
      findsOneWidget,
    );
  });

  testWidgets(
    'discovery search keeps one focused field through live result updates',
    (tester) async {
      await _installFoods(2);
      await tester.pumpWidget(subject());
      await tester.tap(modeTab('databaseFood'));
      await tester.pumpAndSettle();
      final search = find.byKey(
        const ValueKey('food-entry-search-databaseFood'),
      );
      await tester.tap(search);
      for (final text in [
        'c',
        'ch',
        'chi',
        'chic',
        'chicken',
        '12345',
        'さ',
        'ささ',
        'ささみ',
      ]) {
        await tester.enterText(search, text);
        await tester.pump();
        expect(tester.widget<TextField>(search).controller!.text, text);
        expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
      }
    },
  );

  testWidgets('discovery rows use catalog thumbnails with icon fallback', (
    tester,
  ) async {
    await _installFood(
      index: 0,
      baseAmount: 100,
      visualKey: FoodVisualKey.meat,
    );
    await _createFood(
      AppRepositoryRegistry.container,
      index: 1,
      timestamp: DateTime.utc(2026, 9, 15),
    );
    await tester.pumpWidget(subject());
    await tester.tap(modeTab('databaseFood'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('food-thumbnail-meat')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('food-thumbnail-fallback')),
      findsOneWidget,
    );
  });

  testWidgets('vertical discovery scrolling keeps the current mode active', (
    tester,
  ) async {
    await _installFoods(10);
    await tester.pumpWidget(subject());
    await tester.tap(modeTab('databaseFood'));
    await tester.pumpAndSettle();
    final expand = find.byKey(const ValueKey('food-entry-expand-databaseFood'));
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();

    final surface = find.byKey(
      const ValueKey('food-entry-input-mode-page-surface'),
    );
    await tester.dragFrom(
      tester.getTopLeft(surface) + const Offset(20, 20),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();

    expectActiveMode(tester, 'databaseFood');
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending Food quantity confirmation blocks mode changes', (
    tester,
  ) async {
    await _installFoods(1);
    await tester.pumpWidget(subject());
    await tester.tap(modeTab('databaseFood'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('food-entry-inline-food-${_foodId(0)}')),
    );
    await tester.pumpAndSettle();

    await swipeMode(tester, -300);
    expectActiveMode(tester, 'databaseFood');
    expect(
      find.byKey(const ValueKey('food-db-quantity-confirmation')),
      findsOneWidget,
    );
    expect(tester.widget<InkWell>(modeTab('databaseRecipe')).onTap, isNull);
  });

  testWidgets('selectors use a smaller aligned selected value treatment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject());

    final entrySelector = find.byKey(
      const ValueKey('food-entry-type-selector'),
    );
    final mealSelector = find.byKey(const ValueKey('food-meal-type-selector'));
    final mealValue = tester.widget<Text>(
      find.descendant(of: entrySelector, matching: find.text('MEAL')).first,
    );
    final breakfastValue = tester.widget<Text>(
      find.descendant(of: mealSelector, matching: find.text('朝食')).first,
    );
    final icon = tester.widget<Icon>(
      find
          .descendant(
            of: entrySelector,
            matching: find.byIcon(Icons.restaurant),
          )
          .first,
    );

    expect(mealValue.style?.fontSize, 14);
    expect(breakfastValue.style?.fontSize, 14);
    expect(icon.size, 16);
    expect(tester.getRect(entrySelector).height, lessThan(48));
    expect(tester.getRect(mealSelector).height, lessThan(48));
  });

  testWidgets(
    'database search uses the full master list and supports collapse',
    (tester) async {
      await _installFoods(10);
      await tester.pumpWidget(subject());
      await tester.tap(
        find.byKey(const ValueKey('food-entry-tab-databaseFood')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Food 0'), findsOneWidget);
      expect(find.text('Food 4'), findsOneWidget);
      expect(find.text('Food 5'), findsNothing);
      expect(find.text('さらに表示'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('food-entry-search-databaseFood')),
        'Food 9',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(9)}')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('food-entry-clear-search-databaseFood')),
      );
      await tester.pumpAndSettle();
      final expand = find.byKey(
        const ValueKey('food-entry-expand-databaseFood'),
      );
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(9)}')),
        findsOneWidget,
      );
      expect(find.text('折りたたむ'), findsOneWidget);

      final collapse = find.byKey(
        const ValueKey('food-entry-collapse-databaseFood'),
      );
      await tester.ensureVisible(collapse);
      await tester.tap(collapse);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(9)}')),
        findsNothing,
      );
    },
  );

  testWidgets('successful Food add clears search and restores compact list', (
    tester,
  ) async {
    await _installFoods(6);
    await tester.pumpWidget(subject());
    await tester.tap(find.byKey(const ValueKey('food-entry-tab-databaseFood')));
    await tester.pumpAndSettle();
    final expand = find.byKey(const ValueKey('food-entry-expand-databaseFood'));
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('food-entry-search-databaseFood')),
      'Food 5',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('food-entry-inline-food-${_foodId(5)}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('food-db-add')));
    await tester.pumpAndSettle();

    final search = tester.widget<TextField>(
      find.byKey(const ValueKey('food-entry-search-databaseFood')),
    );
    expect(search.controller!.text, isEmpty);
    expect(
      find.byKey(ValueKey('food-entry-inline-food-${_foodId(5)}')),
      findsNothing,
    );
    expect(find.text('さらに表示'), findsOneWidget);
  });

  testWidgets(
    'FOOD quantity shares the compact MANUAL amount stepper geometry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _installFoods(1);
      await tester.pumpWidget(subject());

      final manualField = find.byKey(const ValueKey('food-amount-input'));
      final manualIncrement = find.byKey(
        const ValueKey('food-amount-increment'),
      );
      final manualDecrement = find.byKey(
        const ValueKey('food-amount-decrement'),
      );
      final manualGap =
          tester.getRect(manualIncrement).left -
          tester.getRect(manualField).right;
      final manualIncrementSize = tester.getSize(manualIncrement);
      final manualDecrementSize = tester.getSize(manualDecrement);

      await tester.tap(
        find.byKey(const ValueKey('food-entry-tab-databaseFood')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(0)}')),
      );
      await tester.pumpAndSettle();

      final quantity = find.byKey(const ValueKey('food-db-pending-quantity'));
      final increment = find.byKey(
        const ValueKey('food-db-quantity-increment'),
      );
      final decrement = find.byKey(
        const ValueKey('food-db-quantity-decrement'),
      );
      final quantityRect = tester.getRect(quantity);
      final incrementRect = tester.getRect(increment);
      final decrementRect = tester.getRect(decrement);

      expect(incrementRect.left, greaterThan(quantityRect.right));
      expect(decrementRect.left, greaterThan(quantityRect.right));
      expect(incrementRect.left, moreOrLessEquals(decrementRect.left));
      expect(incrementRect.top, lessThan(decrementRect.top));
      expect(
        incrementRect.left - quantityRect.right,
        moreOrLessEquals(manualGap),
      );
      expect(tester.getSize(increment), manualIncrementSize);
      expect(tester.getSize(decrement), manualDecrementSize);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FOOD quantity preserves decimal typing and current step actions',
    (tester) async {
      await _installFoods(1);
      await tester.pumpWidget(subject());
      await tester.tap(
        find.byKey(const ValueKey('food-entry-tab-databaseFood')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(0)}')),
      );
      await tester.pumpAndSettle();

      final quantity = find.byKey(const ValueKey('food-db-pending-quantity'));
      TextField quantityInput() => tester.widget<TextField>(
        find.descendant(of: quantity, matching: find.byType(TextField)),
      );

      expect(quantityInput().controller!.text, '1');
      await tester.tap(
        find.byKey(const ValueKey('food-db-quantity-increment')),
      );
      await tester.pump();
      expect(quantityInput().controller!.text, '2');
      await tester.tap(
        find.byKey(const ValueKey('food-db-quantity-decrement')),
      );
      await tester.pump();
      expect(quantityInput().controller!.text, '1');
      await tester.enterText(quantity, '2.25');
      await tester.pump();
      expect(quantityInput().controller!.text, '2.25');
    },
  );

  testWidgets(
    'registered Food item edits synchronize used amount and quantity',
    (tester) async {
      await _installFoods(1);
      await tester.pumpWidget(subject());
      await tester.tap(modeTab('databaseFood'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(0)}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('food-db-add')));
      await tester.pumpAndSettle();

      final item = find.byKey(const ValueKey('meal-item-name-0'));
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();

      final usedAmount = find.byKey(
        const ValueKey('meal-item-used-amount-input'),
      );
      final quantity = find.byKey(const ValueKey('meal-item-quantity-input'));
      await tester.enterText(usedAmount, '130');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: quantity, matching: find.byType(TextField)),
            )
            .controller!
            .text,
        '1.3',
      );
      expect(find.textContaining('100g × 1.3 = 130g'), findsOneWidget);

      await tester.enterText(quantity, '1.5');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: usedAmount, matching: find.byType(TextField)),
            )
            .controller!
            .text,
        '150',
      );
      expect(find.textContaining('150kcal'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('meal-item-edit-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('food-meal-item-editor')), findsNothing);
      expect(find.textContaining('100kcal'), findsOneWidget);
    },
  );

  testWidgets(
    'Food package quantity and nutrition basis remain distinct in edit',
    (tester) async {
      await _installFood(index: 0, baseAmount: 100, packageAmount: 350);
      await tester.pumpWidget(subject());
      await tester.tap(modeTab('databaseFood'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(0)}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('food-db-add')));
      await tester.pumpAndSettle();
      final item = find.byKey(const ValueKey('meal-item-name-0'));
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();

      final quantity = find.byKey(const ValueKey('meal-item-quantity-input'));
      await tester.enterText(quantity, '0.5');
      await tester.pump();
      expect(find.textContaining('350g × 0.5 = 175g'), findsOneWidget);
      expect(find.textContaining('175kcal'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('meal-item-edit-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('175kcal'), findsOneWidget);
    },
  );

  testWidgets('meal item edit locks mode swipe without discarding its draft', (
    tester,
  ) async {
    await _installFoods(1);
    await tester.pumpWidget(subject());
    await tester.tap(modeTab('databaseFood'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('food-entry-inline-food-${_foodId(0)}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('food-db-add')));
    await tester.pumpAndSettle();
    final item = find.byKey(const ValueKey('meal-item-name-0'));
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();

    await swipeMode(tester, -300);
    expectActiveMode(tester, 'databaseFood');
    expect(find.byKey(const ValueKey('food-meal-item-editor')), findsOneWidget);
  });

  testWidgets('water disables meal type and hides database modes', (
    tester,
  ) async {
    await tester.pumpWidget(subject());

    await tester.tap(find.byKey(const ValueKey('food-entry-type-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WATER').last);
    await tester.pump();

    final selector = tester.widget<DropdownButtonFormField>(
      find.byKey(const ValueKey('food-meal-type-selector')),
    );
    expect(selector.onChanged, isNull);
    expect(
      find.byKey(const ValueKey('food-entry-input-mode-tabs')),
      findsNothing,
    );
    expect(find.text('Water Volume (ml)'), findsOneWidget);
  });

  testWidgets('water keeps the prior meal selection for return to meal mode', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    final mealSelector = find.byKey(const ValueKey('food-meal-type-selector'));
    await tester.tap(mealSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('昼食').last);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('food-entry-type-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WATER').last);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('food-entry-type-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MEAL').last);
    await tester.pump();

    expect(
      tester
          .widget<DropdownButtonFormField<MealType>>(mealSelector)
          .initialValue,
      MealType.lunch,
    );
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('compact Food Entry does not overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _installFoods(6);
      await tester.pumpWidget(subject());
      await tester.tap(
        find.byKey(const ValueKey('food-entry-tab-databaseFood')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(0)}')),
      );
      await tester.pumpAndSettle();
      final quantity = find.byKey(const ValueKey('food-db-pending-quantity'));
      final increment = find.byKey(
        const ValueKey('food-db-quantity-increment'),
      );
      final decrement = find.byKey(
        const ValueKey('food-db-quantity-decrement'),
      );
      expect(
        tester.getRect(increment).left,
        greaterThan(tester.getRect(quantity).right),
      );
      expect(
        tester.getRect(decrement).left,
        greaterThan(tester.getRect(quantity).right),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _installFoods(int count) async {
  final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
  AppRepositoryRegistry.install(container);
  addTearDown(AppRepositoryRegistry.resetForTesting);
  final timestamp = DateTime.utc(2026, 9, 15);
  for (var index = 0; index < count; index++) {
    await _createFood(container, index: index, timestamp: timestamp);
  }
}

Future<void> _installFood({
  required int index,
  required double baseAmount,
  double? packageAmount,
  FoodVisualKey? visualKey,
}) async {
  final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
  AppRepositoryRegistry.install(container);
  addTearDown(AppRepositoryRegistry.resetForTesting);
  await _createFood(
    container,
    index: index,
    timestamp: DateTime.utc(2026, 9, 15),
    baseAmount: baseAmount,
    packageAmount: packageAmount,
    visualKey: visualKey,
  );
}

Future<void> _createFood(
  AppRepositoryContainer container, {
  required int index,
  required DateTime timestamp,
  double baseAmount = 100,
  double? packageAmount,
  FoodVisualKey? visualKey,
}) => container.foodCatalog.create(
  FoodCatalogEntry(
    foodId: _foodId(index),
    name: 'Food $index',
    category: FoodCatalogCategory.ingredient,
    baseQuantity: FoodQuantityDefinition(
      value: baseAmount,
      unit: FoodQuantityUnit.gram,
    ),
    nutrition: NutritionSnapshot(
      calories: 100,
      protein: 10,
      fat: 5,
      carbohydrate: 20,
    ),
    nutritionStatus: NutritionStatus.declared,
    provenance: FoodDataProvenance(
      sourceType: FoodProvenanceSourceType.userInput,
      capturedAt: timestamp,
    ),
    isArchived: false,
    packageQuantity: packageAmount,
    packageUnit: packageAmount == null ? null : FoodQuantityUnit.gram,
    visualKey: visualKey,
    createdAt: timestamp,
    updatedAt: timestamp,
  ),
);

String _foodId(int index) =>
    '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';

String _modeLabel(String mode) => switch (mode) {
  'manual' => 'MANUAL',
  'databaseFood' => 'FOOD',
  'databaseRecipe' => 'RECIPE',
  'databaseMeal' => 'MEAL',
  _ => throw ArgumentError.value(mode, 'mode'),
};
