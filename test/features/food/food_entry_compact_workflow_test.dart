import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_input_form.dart';

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

    for (final label in ['MANUAL', 'FOOD', 'RECIPE', 'MEAL']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(
      find.byKey(const ValueKey('food-entry-tab-databaseFood')),
    );
    await tester.pump();
    expect(find.text('SELECT FOOD FROM DATABASE'), findsNothing);
    expect(find.text('NAME'), findsNothing);
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

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('compact Food Entry does not overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(subject());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
