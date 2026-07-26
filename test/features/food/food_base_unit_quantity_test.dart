import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/food/data/beta_meal_templates.dart';
import 'package:or_app/features/food/services/beta_meal_template_resolver.dart';
import 'package:or_app/features/food/widgets/food_input_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Food base unit and amount calculation', () {
    test(
      'calculates gram and milliliter quantities without early rounding',
      () {
        final chicken = _measuredItem(
          baseAmount: 100,
          amount: 250,
          calories: 165,
          protein: 31,
          fat: 3.6,
          carbohydrate: 0,
        );
        expect(chicken.multiplier, 2.5);
        expect(chicken.totalCalories, 412.5);
        expect(chicken.totalProtein, 77.5);
        expect(chicken.totalFat, 9);
        expect(chicken.totalCarbohydrate, 0);

        expect(_measuredItem(baseAmount: 100, amount: 100).multiplier, 1);
        expect(_measuredItem(baseAmount: 100, amount: 90).multiplier, 0.9);
        expect(_measuredItem(baseAmount: 1, amount: 250).multiplier, 250);
        expect(
          _measuredItem(
            baseAmount: 100,
            amount: 750,
            unit: FoodBaseUnit.ml,
          ).multiplier,
          7.5,
        );
        expect(
          _measuredItem(
            baseAmount: 1,
            amount: 750,
            unit: FoodBaseUnit.ml,
          ).multiplier,
          750,
        );
        expect(
          _measuredItem(baseAmount: 2.5, amount: 7.25).multiplier,
          closeTo(2.9, 1e-12),
        );
      },
    );

    test('keeps legacy serving quantity semantics', () {
      final legacy = FoodItem(
        name: 'Legacy',
        calories: 100,
        protein: 10,
        fat: 2,
        carbohydrate: 20,
        quantity: 3,
      );

      expect(legacy.hasMeasuredAmount, isFalse);
      expect(legacy.multiplier, 3);
      expect(legacy.totalCalories, 300);
      expect(legacy.totalProtein, 30);
      expect(legacy.toJson().containsKey('amount'), isFalse);
    });

    test('rejects invalid measurement and nutrition values', () {
      FoodItem create({
        double amount = 100,
        double baseAmount = 100,
        double calories = 100,
      }) {
        return FoodItem.fromJson({
          'name': 'Food',
          'calories': calories,
          'protein': 1,
          'fat': 1,
          'carbohydrate': 1,
          'quantity': 1,
          'amount': amount,
          'baseAmount': baseAmount,
          'baseUnit': 'g',
        });
      }

      expect(() => create(amount: 0), throwsFormatException);
      expect(() => create(amount: -1), throwsFormatException);
      expect(() => create(amount: double.nan), throwsFormatException);
      expect(() => create(amount: double.infinity), throwsFormatException);
      expect(() => create(baseAmount: 0), throwsFormatException);
      expect(() => create(baseAmount: -1), throwsFormatException);
      expect(() => create(baseAmount: double.nan), throwsFormatException);
      expect(() => create(baseAmount: double.infinity), throwsFormatException);
      expect(() => create(calories: -1), throwsFormatException);
      expect(() => create(calories: double.infinity), throwsFormatException);
      expect(
        () => FoodItem.fromJson({
          'name': 'Partial',
          'calories': 1,
          'protein': 1,
          'fat': 1,
          'carbohydrate': 1,
          'quantity': 1,
          'amount': 100,
        }),
        throwsFormatException,
      );
    });

    test('round trips new fields and decodes old JSON unchanged', () {
      final measured = _measuredItem(baseAmount: 100, amount: 250);
      final measuredJson = measured.toJson();
      expect(measuredJson['calculatedCalories'], 250);
      expect(measuredJson['calculatedProtein'], 25);
      expect(FoodItem.fromJson(measuredJson), measured);
      expect(
        () => FoodItem.fromJson({...measuredJson, 'calculatedCalories': 999}),
        throwsFormatException,
      );

      final oldJson = <String, dynamic>{
        'name': 'Legacy',
        'calories': 123,
        'protein': 4,
        'fat': 5,
        'carbohydrate': 6,
        'quantity': 2,
      };
      final old = FoodItem.fromJson(oldJson);
      expect(old.hasMeasuredAmount, isFalse);
      expect(old.totalCalories, 246);
      expect(old.toJson(), oldJson);
    });

    test('Meal totals combine independent measured and legacy items', () {
      final meal = MealData(
        date: '2026-07-27',
        mealType: 'Lunch',
        items: [
          _measuredItem(baseAmount: 100, amount: 250, calories: 165),
          FoodItem(
            name: 'Legacy',
            calories: 50,
            protein: 2,
            fat: 1,
            carbohydrate: 5,
            quantity: 2,
          ),
        ],
        memo: '',
        id: 'mixed',
      );

      expect(meal.calories, 512.5);
    });

    test('g beta templates retain base and amount snapshot fields', () {
      final dinner = betaMealTemplates.singleWhere(
        (template) => template.id == 'beta-dinner',
      );
      final resolution = BetaMealTemplateResolver.resolve(dinner);
      final rice = resolution.items.singleWhere((item) => item.name == '白米');

      expect(rice.baseAmount, 100);
      expect(rice.amount, 160);
      expect(rice.baseUnit, FoodBaseUnit.g);
      expect(rice.totalCalories, closeTo(249.6, 1e-12));
      expect(rice.name, isNot(contains('160')));
    });

    test('normalizes measured beta template nutrition to 100 units', () {
      final lunch = betaMealTemplates.singleWhere(
        (template) => template.id == 'beta-lunch',
      );
      final resolution = BetaMealTemplateResolver.resolve(lunch);
      final tenGramItem = resolution.items.singleWhere(
        (item) => item.amount == 10 && item.baseUnit == FoodBaseUnit.g,
      );

      expect(tenGramItem.baseAmount, 100);
      expect(tenGramItem.amount, 10);
      expect(tenGramItem.calories, closeTo(258, 1e-12));
      expect(tenGramItem.protein, closeTo(14, 1e-12));
      expect(tenGramItem.fat, closeTo(11, 1e-12));
      expect(tenGramItem.carbohydrate, closeTo(27, 1e-12));
      expect(tenGramItem.totalCalories, closeTo(25.8, 1e-12));
      expect(tenGramItem.totalProtein, closeTo(1.4, 1e-12));
      expect(tenGramItem.totalFat, closeTo(1.1, 1e-12));
      expect(tenGramItem.totalCarbohydrate, closeTo(2.7, 1e-12));
      expect(tenGramItem.quantity, 1);
    });
  });

  group('Food quantity entry UI', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('shows base controls and saves calculated snapshot', (
      tester,
    ) async {
      MealData? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(onSave: (meal) async => saved = meal),
            ),
          ),
        ),
      );

      expect(
        tester.widget<TextField>(_field('BASE AMOUNT')).controller!.text,
        '100',
      );
      expect(
        tester.widget<TextField>(_field('QUANTITY (g)')).controller!.text,
        '100',
      );

      await tester.enterText(_field('Food Name'), 'Chicken Breast');
      await tester.enterText(_field('BASE AMOUNT'), '100');
      await tester.enterText(_field('Calories'), '165');
      await tester.enterText(_field('Protein'), '31');
      await tester.enterText(_field('Fat'), '3.6');
      await tester.enterText(_field('Carbohydrate'), '0');
      await tester.pump();

      expect(find.text('NUTRITION PER 100g'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('QUANTITY (g)')).controller!.text,
        '100',
      );

      await tester.enterText(_field('QUANTITY (g)'), '250');
      await tester.pump();
      expect(find.text('250g'), findsOneWidget);
      expect(find.text('Calories : 413 kcal'), findsOneWidget);

      await tester.ensureVisible(find.text('Save Meal'));
      await tester.tap(find.text('Save Meal'));
      await tester.pump();

      expect(saved, isNotNull);
      final item = saved!.items.single;
      expect(item.amount, 250);
      expect(item.baseAmount, 100);
      expect(item.baseUnit, FoodBaseUnit.g);
      expect(item.totalCalories, 412.5);
    });

    testWidgets(
      'base amount changes rescale nutrition without changing quantity',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FoodInputForm(onSave: (_) async {}),
              ),
            ),
          ),
        );

        await tester.enterText(_field('Calories'), '258');
        await tester.enterText(_field('Protein'), '14');
        await tester.enterText(_field('Fat'), '11');
        await tester.enterText(_field('Carbohydrate'), '27');

        await tester.enterText(_field('BASE AMOUNT'), '10');
        await tester.pump();
        expect(_controllerText(tester, 'Calories'), '25.8');
        expect(_controllerText(tester, 'Protein'), '1.4');
        expect(_controllerText(tester, 'Fat'), '1.1');
        expect(_controllerText(tester, 'Carbohydrate'), '2.7');
        expect(_controllerText(tester, 'QUANTITY (g)'), '100');
        expect(find.text('NUTRITION PER 10g'), findsOneWidget);

        await tester.enterText(_field('BASE AMOUNT'), '100');
        await tester.pump();
        expect(
          double.parse(_controllerText(tester, 'Calories')),
          closeTo(258, 1e-9),
        );
        expect(
          double.parse(_controllerText(tester, 'Protein')),
          closeTo(14, 1e-9),
        );
        expect(_controllerText(tester, 'QUANTITY (g)'), '100');

        await tester.enterText(_field('BASE AMOUNT'), '1');
        await tester.pump();
        expect(
          double.parse(_controllerText(tester, 'Calories')),
          closeTo(2.58, 1e-12),
        );
        expect(
          double.parse(_controllerText(tester, 'Protein')),
          closeTo(0.14, 1e-12),
        );
        expect(_controllerText(tester, 'QUANTITY (g)'), '100');

        await tester.enterText(_field('BASE AMOUNT'), '100');
        await tester.pump();
        expect(
          double.parse(_controllerText(tester, 'Calories')),
          closeTo(258, 1e-9),
        );
        expect(
          double.parse(_controllerText(tester, 'Protein')),
          closeTo(14, 1e-9),
        );
        expect(double.parse(_controllerText(tester, 'Fat')), closeTo(11, 1e-9));
        expect(
          double.parse(_controllerText(tester, 'Carbohydrate')),
          closeTo(27, 1e-9),
        );
        expect(_controllerText(tester, 'QUANTITY (g)'), '100');
      },
    );

    testWidgets('rejects zero quantity and supports mL', (tester) async {
      MealData? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(onSave: (meal) async => saved = meal),
            ),
          ),
        ),
      );

      await tester.enterText(_field('Food Name'), 'Tea');
      await tester.enterText(_field('BASE AMOUNT'), '100');
      final unitDropdown = find.byType(DropdownButtonFormField<FoodBaseUnit>);
      await tester.ensureVisible(unitDropdown);
      await tester.tap(unitDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('mL').last);
      await tester.pump();
      expect(_controllerText(tester, 'BASE AMOUNT'), '100');
      expect(_controllerText(tester, 'QUANTITY (mL)'), '100');
      await tester.enterText(_field('Calories'), '0');
      await tester.enterText(_field('Protein'), '0');
      await tester.enterText(_field('Fat'), '0');
      await tester.enterText(_field('Carbohydrate'), '0');
      await tester.enterText(_field('QUANTITY (mL)'), '0');
      await tester.pump();

      expect(find.text('NUTRITION PER 100mL'), findsOneWidget);
      expect(find.text('Save Meal'), findsNothing);
      expect(saved, isNull);

      await tester.enterText(_field('QUANTITY (mL)'), '750');
      await tester.pump();
      await tester.ensureVisible(find.text('Save Meal'));
      await tester.tap(find.text('Save Meal'));
      await tester.pump();

      expect(saved!.items.single.amount, 750);
      expect(saved!.items.single.baseAmount, 100);
      expect(saved!.items.single.baseUnit, FoodBaseUnit.ml);
      expect(saved!.items.single.toJson()['baseUnit'], 'mL');
    });

    testWidgets('editing a legacy item preserves serving semantics', (
      tester,
    ) async {
      final legacyMeal = MealData(
        date: '2026-07-27',
        mealType: 'Dinner',
        items: [
          FoodItem(
            name: 'Legacy',
            calories: 100,
            protein: 1,
            fat: 2,
            carbohydrate: 3,
            quantity: 2,
          ),
        ],
        memo: '',
        id: 'legacy',
      );
      MealData? saved;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(
                initialMeal: legacyMeal,
                onSave: (meal) async => saved = meal,
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Legacy'));
      await tester.tap(find.text('Legacy'));
      await tester.pump();
      expect(
        tester.widget<TextField>(_field('BASE AMOUNT')).controller!.text,
        isEmpty,
      );

      await tester.ensureVisible(find.text('Update Food'));
      await tester.tap(find.text('Update Food'));
      await tester.ensureVisible(find.text('Update Meal'));
      await tester.tap(find.text('Update Meal'));
      await tester.pump();

      expect(saved!.items.single.hasMeasuredAmount, isFalse);
      expect(saved!.items.single.quantity, 2);
      expect(saved!.items.single.totalCalories, 200);
    });
  });
}

FoodItem _measuredItem({
  double baseAmount = 100,
  double amount = 100,
  FoodBaseUnit unit = FoodBaseUnit.g,
  double calories = 100,
  double protein = 10,
  double fat = 2,
  double carbohydrate = 20,
}) {
  return FoodItem(
    name: 'Measured',
    calories: calories,
    protein: protein,
    fat: fat,
    carbohydrate: carbohydrate,
    amount: amount,
    baseAmount: baseAmount,
    baseUnit: unit,
  );
}

Finder _field(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField with label $label',
  );
}

String _controllerText(WidgetTester tester, String label) {
  return tester.widget<TextField>(_field(label)).controller!.text;
}
