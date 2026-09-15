import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await container.foodCatalog.create(
      FoodCatalogEntry(
        foodId: _foodId(index),
        name: 'Food $index',
        category: FoodCatalogCategory.ingredient,
        baseQuantity: FoodQuantityDefinition(
          value: 100,
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
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }
}

String _foodId(int index) =>
    '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';
