import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/widgets/food_input_form.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  testWidgets(
    'SAVE TO DATABASE binds the current manual item to its saved master',
    (tester) async {
      final controller = AppInitializationController()..markReady();
      AppRepositoryRegistry.beginStartup(controller: controller);
      AppRepositoryRegistry.install(
        AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase()),
      );
      addTearDown(AppRepositoryRegistry.resetForTesting);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(onSave: (_) async => true),
            ),
          ),
        ),
      );

      expect(find.text('表示量'), findsOneWidget);
      expect(find.text('登録基準量'), findsOneWidget);
      expect(find.text('ADD FOOD ITEM'), findsOneWidget);
      expect(find.text('PACKAGE QUANTITY'), findsNothing);
      expect(find.text('NUTRITION BASIS'), findsNothing);
      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('BRAND'), findsOneWidget);
      expect(find.text('CATEGORY'), findsOneWidget);

      await tester.enterText(_field('NAME'), 'Promotion Chicken');
      await tester.enterText(_field('表示量'), '150');
      await tester.enterText(_field('登録基準量'), '100');
      await tester.enterText(_field('CALORIES'), '300');
      await tester.enterText(_field('PROTEIN'), '10');
      await tester.enterText(_field('FAT'), '5');
      await tester.enterText(_field('CARBOHYDRATE'), '20');
      await tester.enterText(_usedAmountField(), '75');

      final packageUnit = find.byType(
        DropdownButtonFormField<FoodQuantityUnit?>,
      );
      await tester.ensureVisible(packageUnit);
      await tester.tap(packageUnit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('g').last);
      await tester.pump();

      await tester.enterText(_field('登録基準量'), '100');
      await tester.pump();
      expect(find.text('100gあたりに換算'), findsOneWidget);

      final recalculate = find.byKey(
        const ValueKey('food-entry-recalculate-nutrition'),
      );
      await tester.ensureVisible(recalculate);
      await tester.tap(recalculate);
      await tester.pump();

      await tester.ensureVisible(find.text('SAVE TO DATABASE'));
      await tester.tap(find.text('SAVE TO DATABASE'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('SAVE'));
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(find.text('SAVE TO DATABASE'), findsNothing);
      expect(
        find.byKey(const ValueKey('food-catalog-selection')),
        findsOneWidget,
      );
    },
  );
}

Finder _field(String label) => switch (label) {
  '表示量' => find.byKey(const ValueKey('food-entry-package-quantity')),
  '登録基準量' => find.byKey(const ValueKey('food-entry-base-quantity')),
  _ => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField with label $label',
  ),
};

Finder _usedAmountField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.decoration?.labelText?.startsWith('実使用量 (') ?? false),
  description: 'TextField with used amount label',
);
