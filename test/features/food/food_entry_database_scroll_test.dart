import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/widgets/food_input_form.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  testWidgets(
    'database selection reveals quantity confirmation and restores list offset on cancel',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await _installFoods(12);

      await tester.pumpWidget(_subject(scrollController));
      final databaseTab = find.byKey(
        const ValueKey('food-entry-tab-databaseFood'),
      );
      await tester.ensureVisible(databaseTab);
      await tester.tap(databaseTab);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('food-entry-inline-food-list')),
        findsOneWidget,
      );
      final expand = find.byKey(
        const ValueKey('food-entry-expand-databaseFood'),
      );
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();

      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final savedOffset = scrollController.offset;
      expect(savedOffset, greaterThan(0));

      await tester.tap(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(11)}')),
      );
      await tester.pumpAndSettle();

      final confirmation = find.byKey(
        const ValueKey('food-db-quantity-confirmation'),
      );
      expect(confirmation, findsOneWidget);
      expect(_isVisible(tester, confirmation), isTrue);
      expect(find.text('Meal Memo'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('food-db-cancel')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('food-entry-inline-food-list')),
        findsOneWidget,
      );
      expect(scrollController.offset, closeTo(savedOffset, 0.5));

      await tester.tap(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(11)}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('food-db-add')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('food-db-quantity-confirmation')),
        findsNothing,
      );
      expect(find.text('Food 11'), findsWidgets);
    },
  );

  testWidgets('top-list selection reveals the same quantity confirmation', (
    tester,
  ) async {
    await _installFoods(2);

    for (final width in [320.0, 390.0, 900.0]) {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_subject(scrollController, key: ValueKey(width)));
      final databaseTab = find.byKey(
        const ValueKey('food-entry-tab-databaseFood'),
      );
      await tester.ensureVisible(databaseTab);
      await tester.tap(databaseTab);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('food-entry-inline-food-list')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(ValueKey('food-entry-inline-food-${_foodId(0)}')),
      );
      await tester.pumpAndSettle();

      final confirmation = find.byKey(
        const ValueKey('food-db-quantity-confirmation'),
      );
      expect(confirmation, findsOneWidget);
      expect(_isVisible(tester, confirmation), isTrue);
    }
  });
}

Widget _subject(ScrollController scrollController, {Key? key}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      controller: scrollController,
      child: FoodInputForm(
        key: key,
        onSave: (_) async => true,
        scrollController: scrollController,
      ),
    ),
  ),
);

bool _isVisible(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  final viewport = tester.getRect(find.byType(Scrollable).first);
  return rect.top >= viewport.top && rect.bottom <= viewport.bottom;
}

Future<void> _installFoods(int count) async {
  final controller = AppInitializationController()..markReady();
  AppRepositoryRegistry.beginStartup(controller: controller);
  final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
  AppRepositoryRegistry.install(container);
  addTearDown(AppRepositoryRegistry.resetForTesting);
  final timestamp = DateTime.utc(2026, 9, 25);
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
