import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/repositories/daily_log_confirmation_repository.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/food/data/beta_meal_templates.dart';
import 'package:or_app/features/food/food_edit_page.dart';
import 'package:or_app/features/food/food_entry_page.dart';
import 'package:or_app/features/food/food_history_page.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/food/models/persisted_food_record.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/services/beta_meal_template_resolver.dart';
import 'package:or_app/features/food/services/food_input_capture_gateway.dart';
import 'package:or_app/features/food/widgets/food_input_form.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

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

    test('uses explicit base multiplier without dividing by base amount', () {
      final one = _multiplierItem(baseAmount: 100, amount: 1);
      final twoPointFive = _multiplierItem(
        baseAmount: 100,
        amount: 2.5,
        calories: 165,
        protein: 31,
        fat: 3.6,
        carbohydrate: 0,
      );
      final pointOne = _multiplierItem(baseAmount: 100, amount: 0.1);
      final thousand = _multiplierItem(baseAmount: 1, amount: 1000);
      final milliliters = _multiplierItem(
        baseAmount: 100,
        amount: 7.5,
        unit: FoodBaseUnit.ml,
      );

      expect(one.multiplier, 1);
      expect(one.totalCalories, 100);
      expect(twoPointFive.multiplier, 2.5);
      expect(twoPointFive.totalCalories, 412.5);
      expect(twoPointFive.totalProtein, 77.5);
      expect(twoPointFive.totalFat, 9);
      expect(twoPointFive.physicalAmount, 250);
      expect(pointOne.totalCalories, 10);
      expect(pointOne.physicalAmount, 10);
      expect(thousand.totalCalories, 100000);
      expect(thousand.physicalAmount, 1000);
      expect(milliliters.totalCalories, 750);
      expect(milliliters.physicalAmount, 750);
    });

    test('missing amountMode keeps deployed physical amount behavior', () {
      final deployed = FoodItem.fromJson({
        'name': 'Deployed',
        'calories': 165,
        'protein': 31,
        'fat': 3.6,
        'carbohydrate': 0,
        'quantity': 1,
        'amount': 250,
        'baseAmount': 100,
        'baseUnit': 'g',
        'calculatedCalories': 412.5,
        'calculatedProtein': 77.5,
        'calculatedFat': 9,
        'calculatedCarbohydrate': 0,
      });

      expect(deployed.amountMode, isNull);
      expect(deployed.effectiveAmountMode, FoodAmountMode.physicalAmount);
      expect(deployed.multiplier, 2.5);
      expect(deployed.physicalAmount, 250);
      expect(deployed.toJson().containsKey('amountMode'), isFalse);
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

    test('round trips amount mode and decodes old JSON unchanged', () {
      final measured = _measuredItem(baseAmount: 100, amount: 250);
      final measuredJson = measured.toJson();
      expect(measuredJson['calculatedCalories'], 250);
      expect(measuredJson['calculatedProtein'], 25);
      expect(FoodItem.fromJson(measuredJson), measured);
      expect(
        () => FoodItem.fromJson({...measuredJson, 'calculatedCalories': 999}),
        throwsFormatException,
      );

      final multiplier = _multiplierItem(baseAmount: 100, amount: 2.5);
      final multiplierJson = multiplier.toJson();
      expect(multiplierJson['amountMode'], 'baseMultiplier');
      expect(multiplierJson['calculatedCalories'], 250);
      expect(FoodItem.fromJson(multiplierJson), multiplier);

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

    test('Meal totals combine multiplier, physical, and legacy items', () {
      final meal = MealData(
        date: '2026-07-27',
        mealType: 'Lunch',
        items: [
          _multiplierItem(baseAmount: 100, amount: 2.5, calories: 100),
          _measuredItem(baseAmount: 100, amount: 50, calories: 100),
          const FoodItem(
            name: 'Legacy',
            calories: 100,
            protein: 0,
            fat: 0,
            carbohydrate: 0,
            quantity: 2,
          ),
        ],
        memo: '',
        id: 'all-contracts',
      );

      expect(meal.calories, 500);
    });

    test('g beta templates retain base and amount snapshot fields', () {
      final dinner = betaMealTemplates.singleWhere(
        (template) => template.id == 'beta-dinner',
      );
      final resolution = BetaMealTemplateResolver.resolve(dinner);
      final rice = resolution.items.singleWhere((item) => item.name == '白米');

      expect(rice.baseAmount, 100);
      expect(rice.amount, 1.6);
      expect(rice.baseUnit, FoodBaseUnit.g);
      expect(rice.amountMode, FoodAmountMode.baseMultiplier);
      expect(rice.physicalAmount, 160);
      expect(rice.totalCalories, closeTo(249.6, 1e-12));
      expect(rice.name, isNot(contains('160')));
    });

    test('normalizes measured beta template nutrition to 100 units', () {
      final lunch = betaMealTemplates.singleWhere(
        (template) => template.id == 'beta-lunch',
      );
      final resolution = BetaMealTemplateResolver.resolve(lunch);
      final tenGramItem = resolution.items.singleWhere(
        (item) => item.amount == 0.1 && item.baseUnit == FoodBaseUnit.g,
      );
      final dinner = betaMealTemplates.singleWhere(
        (template) => template.id == 'beta-dinner',
      );
      final twoHundredGramItem = BetaMealTemplateResolver.resolve(dinner).items
          .singleWhere(
            (item) => item.amount == 2 && item.baseUnit == FoodBaseUnit.g,
          );

      expect(tenGramItem.baseAmount, 100);
      expect(tenGramItem.amount, 0.1);
      expect(tenGramItem.amountMode, FoodAmountMode.baseMultiplier);
      expect(tenGramItem.physicalAmount, 10);
      expect(tenGramItem.calories, closeTo(258, 1e-12));
      expect(tenGramItem.protein, closeTo(14, 1e-12));
      expect(tenGramItem.fat, closeTo(11, 1e-12));
      expect(tenGramItem.carbohydrate, closeTo(27, 1e-12));
      expect(tenGramItem.totalCalories, closeTo(25.8, 1e-12));
      expect(tenGramItem.totalProtein, closeTo(1.4, 1e-12));
      expect(tenGramItem.totalFat, closeTo(1.1, 1e-12));
      expect(tenGramItem.totalCarbohydrate, closeTo(2.7, 1e-12));
      expect(tenGramItem.quantity, 1);
      expect(twoHundredGramItem.physicalAmount, 200);
      expect(twoHundredGramItem.amountMode, FoodAmountMode.baseMultiplier);
    });
  });

  group('Food quantity entry UI', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('blocks repeated save submissions while save is pending', (
      tester,
    ) async {
      final completion = Completer<bool>();
      var saveCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(
                onSave: (_) {
                  saveCount++;
                  return completion.future;
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(_field('Food Name'), 'Pending Meal');
      await tester.enterText(_field('Calories'), '100');
      await tester.enterText(_field('Protein'), '10');
      await tester.enterText(_field('Fat'), '5');
      await tester.enterText(_field('Carbohydrate'), '20');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('SAVE MEAL'),
          matching: find.byType(ElevatedButton),
        ),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      expect(saveCount, 1);

      completion.complete(true);
      await tester.pump();
    });

    testWidgets('food entry exposes aligned master fields and OCR apply flow', (
      tester,
    ) async {
      var saveCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(
                captureGateway: _NutritionGateway(),
                onSave: (_) async {
                  saveCount++;
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      for (final label in [
        'NAME',
        'BRAND',
        'CATEGORY',
        'BARCODE / JAN',
        'PACKAGE QUANTITY',
        'PACKAGE UNIT',
        'NUTRITION BASIS',
        'BASE UNIT',
        'CALORIES',
        'PROTEIN',
        'FAT',
        'CARBOHYDRATE',
        'MEMO',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.byKey(const ValueKey('food-entry-ocr')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('food-entry-ocr')));
      await tester.tap(find.byKey(const ValueKey('food-entry-ocr')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NUTRITION'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAMERA'));
      await tester.pumpAndSettle();
      expect(find.text('REVIEW NUTRITION'), findsOneWidget);
      expect(_controllerText(tester, 'Calories'), isEmpty);
      expect(saveCount, 0);

      await tester.tap(find.text('APPLY TO FORM'));
      await tester.pumpAndSettle();
      expect(_controllerText(tester, 'NUTRITION BASIS'), '100');
      expect(_controllerText(tester, 'Calories'), '154');
      expect(_controllerText(tester, 'Protein'), '1.9');
      expect(_controllerText(tester, 'Fat'), '5.5');
      expect(_controllerText(tester, 'Carbohydrate'), '24.2');
      expect(saveCount, 0);
    });

    testWidgets('package prefills basis until manual basis override', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(onSave: (_) async => true),
            ),
          ),
        ),
      );

      await tester.enterText(_field('PACKAGE QUANTITY'), '500');
      final packageUnit = find.byType(
        DropdownButtonFormField<FoodQuantityUnit?>,
      );
      await tester.ensureVisible(packageUnit);
      await tester.tap(packageUnit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('g').last);
      await tester.pump();
      expect(_controllerText(tester, 'NUTRITION BASIS'), '500');

      await tester.enterText(_field('NUTRITION BASIS'), '100');
      await tester.enterText(_field('PACKAGE QUANTITY'), '600');
      await tester.pump();
      expect(_controllerText(tester, 'NUTRITION BASIS'), '100');
    });

    testWidgets('catalog selection prefills aligned master fields', (
      tester,
    ) async {
      final database = FakeIndexedDbDatabase();
      final controller = AppInitializationController()..markReady();
      AppRepositoryRegistry.beginStartup(controller: controller);
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
      addTearDown(AppRepositoryRegistry.resetForTesting);
      final entry = _catalogEntry();
      await AppRepositoryRegistry.container.foodCatalog.create(entry);
      var dailySaveCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(
                onSave: (_) async {
                  dailySaveCount++;
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('food-catalog-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.name));
      await tester.pumpAndSettle();

      expect(_controllerText(tester, 'Food Name'), entry.name);
      expect(_controllerText(tester, 'BRAND'), entry.brand);
      expect(_controllerText(tester, 'BARCODE / JAN'), entry.barcodeValue);
      expect(_controllerText(tester, 'PACKAGE QUANTITY'), '500');
      expect(_controllerText(tester, 'NUTRITION BASIS'), '100');
      expect(_controllerText(tester, 'Calories'), '154');
      expect(_controllerText(tester, 'Protein'), '1.9');
      expect(_controllerText(tester, 'MEMO'), entry.memo);

      await tester.enterText(_field('BRAND'), 'UPDATED BRAND');
      await tester.ensureVisible(
        find.byKey(const ValueKey('food-save-to-catalog')),
      );
      await tester.tap(find.byKey(const ValueKey('food-save-to-catalog')));
      await tester.pumpAndSettle();
      expect(find.text('EDIT FOOD'), findsOneWidget);
      expect(_controllerText(tester, 'BRAND'), 'UPDATED BRAND');
      await tester.ensureVisible(find.text('SAVE'));
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      final updated = await AppRepositoryRegistry.container.foodCatalog
          .readById(entry.foodId);
      expect(updated!.brand, 'UPDATED BRAND');
      expect(dailySaveCount, 0);
    });

    testWidgets('shows base controls and saves calculated snapshot', (
      tester,
    ) async {
      MealData? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(
                onSave: (meal) async {
                  saved = meal;
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      expect(
        tester.widget<TextField>(_field('NUTRITION BASIS')).controller!.text,
        '100',
      );
      expect(tester.widget<TextField>(_field('AMOUNT')).controller!.text, '1');

      await tester.enterText(_field('Food Name'), 'Chicken Breast');
      await tester.enterText(_field('NUTRITION BASIS'), '100');
      await tester.enterText(_field('Calories'), '165');
      await tester.enterText(_field('Protein'), '31');
      await tester.enterText(_field('Fat'), '3.6');
      await tester.enterText(_field('Carbohydrate'), '0');
      await tester.pump();

      expect(find.text('NUTRITION PER 100g'), findsOneWidget);
      expect(tester.widget<TextField>(_field('AMOUNT')).controller!.text, '1');
      expect(find.text('1 AMOUNT = 100g'), findsOneWidget);
      expect(find.text('実使用量: 100g'), findsOneWidget);

      await tester.enterText(_field('AMOUNT'), '2.5');
      await tester.pump();
      expect(find.text('実使用量: 250g'), findsOneWidget);
      expect(find.text('AMOUNT 2.5'), findsOneWidget);
      expect(find.text('Calories : 413 kcal'), findsOneWidget);
      expect(find.text('ADD FOOD'), findsOneWidget);
      expect(find.text('Add Another Food'), findsNothing);
      expect(find.text('+ ADD FOOD'), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

      await tester.ensureVisible(find.text('SAVE MEAL'));
      await tester.tap(find.text('SAVE MEAL'));
      await tester.pump();

      expect(saved, isNotNull);
      final item = saved!.items.single;
      expect(item.amount, 2.5);
      expect(item.baseAmount, 100);
      expect(item.baseUnit, FoodBaseUnit.g);
      expect(item.amountMode, FoodAmountMode.baseMultiplier);
      expect(item.physicalAmount, 250);
      expect(item.totalCalories, 412.5);
    });

    testWidgets(
      'base amount changes rescale nutrition without changing quantity',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FoodInputForm(onSave: (_) async => true),
              ),
            ),
          ),
        );

        await tester.enterText(_field('Food Name'), 'Base Food');
        await tester.enterText(_field('Calories'), '258');
        await tester.enterText(_field('Protein'), '14');
        await tester.enterText(_field('Fat'), '11');
        await tester.enterText(_field('Carbohydrate'), '27');

        await tester.enterText(_field('NUTRITION BASIS'), '10');
        await tester.pump();
        expect(_controllerText(tester, 'Calories'), '26');
        expect(_controllerText(tester, 'Protein'), '1.4');
        expect(_controllerText(tester, 'Fat'), '1.1');
        expect(_controllerText(tester, 'Carbohydrate'), '2.7');
        expect(_controllerText(tester, 'AMOUNT'), '1');
        expect(find.text('NUTRITION PER 10g'), findsOneWidget);
        expect(find.text('1 AMOUNT = 10g'), findsOneWidget);
        expect(find.text('実使用量: 10g'), findsOneWidget);
        expect(find.text('Calories : 26 kcal'), findsOneWidget);

        await tester.enterText(_field('NUTRITION BASIS'), '100');
        await tester.pump();
        expect(
          double.parse(_controllerText(tester, 'Calories')),
          closeTo(258, 1e-9),
        );
        expect(
          double.parse(_controllerText(tester, 'Protein')),
          closeTo(14, 1e-9),
        );
        expect(_controllerText(tester, 'AMOUNT'), '1');
        expect(find.text('Calories : 258 kcal'), findsOneWidget);

        await tester.enterText(_field('NUTRITION BASIS'), '1');
        await tester.pump();
        expect(_controllerText(tester, 'Calories'), '3');
        expect(_controllerText(tester, 'Protein'), '0.1');
        expect(_controllerText(tester, 'AMOUNT'), '1');

        await tester.enterText(_field('NUTRITION BASIS'), '100');
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
        expect(_controllerText(tester, 'AMOUNT'), '1');
      },
    );

    testWidgets(
      'nutrition fields round for humans while save keeps raw precision',
      (tester) async {
        final rawItem = FoodItem(
          name: 'Raw Basis',
          calories: 264.5,
          protein: 4.3,
          fat: 0.5,
          carbohydrate: 60.5,
          amount: 1,
          baseAmount: 170,
          baseUnit: FoodBaseUnit.g,
          amountMode: FoodAmountMode.baseMultiplier,
        );
        MealData? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FoodInputForm(
                  initialMeal: MealData(
                    id: 'raw-precision',
                    date: '2026-08-30',
                    mealType: 'Dinner',
                    items: [rawItem],
                    memo: '',
                  ),
                  onSave: (meal) async {
                    saved = meal;
                    return true;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.ensureVisible(find.text('Raw Basis'));
        await tester.tap(find.text('Raw Basis'));
        await tester.pump();
        await tester.enterText(_field('NUTRITION BASIS'), '100');
        await tester.pump();

        expect(_controllerText(tester, 'Calories'), '156');
        expect(_controllerText(tester, 'Protein'), '2.5');
        expect(_controllerText(tester, 'Fat'), '0.3');
        expect(_controllerText(tester, 'Carbohydrate'), '35.6');
        expect(find.textContaining('2.529411'), findsNothing);

        await tester.enterText(_field('Protein'), '2.7');
        await tester.ensureVisible(find.text('Update Food'));
        await tester.tap(find.text('Update Food'));
        await tester.ensureVisible(find.text('UPDATE MEAL'));
        await tester.tap(find.text('UPDATE MEAL'));
        await tester.pump();

        final savedItem = saved!.items.single;
        expect(savedItem.calories, closeTo(264.5 * 100 / 170, 1e-12));
        expect(savedItem.protein, 2.7);
        expect(savedItem.fat, closeTo(0.5 * 100 / 170, 1e-12));
        expect(savedItem.carbohydrate, closeTo(60.5 * 100 / 170, 1e-12));
      },
    );

    testWidgets('rejects zero quantity and supports mL', (tester) async {
      MealData? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(
                onSave: (meal) async {
                  saved = meal;
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(_field('Food Name'), 'Tea');
      await tester.enterText(_field('NUTRITION BASIS'), '100');
      final unitDropdown = find.byType(DropdownButtonFormField<FoodBaseUnit>);
      await tester.ensureVisible(unitDropdown);
      await tester.tap(unitDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('mL').last);
      await tester.pump();
      expect(_controllerText(tester, 'NUTRITION BASIS'), '100');
      expect(_controllerText(tester, 'AMOUNT'), '1');
      await tester.enterText(_field('Calories'), '0');
      await tester.enterText(_field('Protein'), '0');
      await tester.enterText(_field('Fat'), '0');
      await tester.enterText(_field('Carbohydrate'), '0');
      await tester.enterText(_field('AMOUNT'), '0');
      await tester.pump();

      expect(find.text('NUTRITION PER 100mL'), findsOneWidget);
      expect(find.text('SAVE MEAL'), findsNothing);
      expect(saved, isNull);

      await tester.enterText(_field('AMOUNT'), '7.5');
      await tester.pump();
      expect(find.text('1 AMOUNT = 100mL'), findsOneWidget);
      expect(find.text('実使用量: 750mL'), findsOneWidget);
      await tester.ensureVisible(find.text('SAVE MEAL'));
      await tester.tap(find.text('SAVE MEAL'));
      await tester.pump();

      expect(saved!.items.single.amount, 7.5);
      expect(saved!.items.single.baseAmount, 100);
      expect(saved!.items.single.baseUnit, FoodBaseUnit.ml);
      expect(saved!.items.single.amountMode, FoodAmountMode.baseMultiplier);
      expect(saved!.items.single.physicalAmount, 750);
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
                onSave: (meal) async {
                  saved = meal;
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Legacy'));
      await tester.tap(find.text('Legacy'));
      await tester.pump();
      expect(
        tester.widget<TextField>(_field('NUTRITION BASIS')).controller!.text,
        isEmpty,
      );

      await tester.ensureVisible(find.text('Update Food'));
      await tester.tap(find.text('Update Food'));
      await tester.ensureVisible(find.text('UPDATE MEAL'));
      await tester.tap(find.text('UPDATE MEAL'));
      await tester.pump();

      expect(saved!.items.single.hasMeasuredAmount, isFalse);
      expect(saved!.items.single.quantity, 2);
      expect(saved!.items.single.totalCalories, 200);
    });

    testWidgets('editing a deployed measured item preserves physical mode', (
      tester,
    ) async {
      final physicalMeal = MealData(
        date: '2026-07-27',
        mealType: 'Dinner',
        items: [_measuredItem(baseAmount: 100, amount: 10, calories: 258)],
        memo: '',
        id: 'physical',
      );
      MealData? saved;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(
                initialMeal: physicalMeal,
                onSave: (meal) async {
                  saved = meal;
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Measured'));
      await tester.tap(find.text('Measured'));
      await tester.pump();
      expect(_controllerText(tester, 'QUANTITY (g)'), '10');
      expect(find.text('1 AMOUNT = 100g'), findsNothing);
      expect(find.textContaining('実使用量:'), findsNothing);

      await tester.ensureVisible(find.text('Update Food'));
      await tester.tap(find.text('Update Food'));
      await tester.ensureVisible(find.text('UPDATE MEAL'));
      await tester.tap(find.text('UPDATE MEAL'));
      await tester.pump();

      final item = saved!.items.single;
      expect(item.amountMode, isNull);
      expect(item.effectiveAmountMode, FoodAmountMode.physicalAmount);
      expect(item.amount, 10);
      expect(item.totalCalories, 25.8);
      expect(item.toJson().containsKey('amountMode'), isFalse);
    });

    testWidgets('food entry has no overflow at target widths', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0, 900.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FoodInputForm(
                  key: ValueKey(width),
                  onSave: (_) async => true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    });
  });

  group('Food history amount contracts', () {
    late FakeIndexedDbDatabase database;

    setUp(() {
      database = FakeIndexedDbDatabase();
      final controller = AppInitializationController()..markReady();
      AppRepositoryRegistry.beginStartup(controller: controller);
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    });

    tearDown(AppRepositoryRegistry.resetForTesting);

    testWidgets('distinguishes physical and multiplier records', (
      tester,
    ) async {
      final timestamp = DateTime.utc(2026, 7, 27);
      final meal = MealData(
        date: '2026-07-27',
        mealType: 'Lunch',
        items: [
          _measuredItem(baseAmount: 100, amount: 10),
          _multiplierItem(baseAmount: 100, amount: 0.1),
        ],
        memo: '',
        id: 'history-contracts',
      );
      final envelope = PersistedFoodRecord(
        id: 'food:history-contracts',
        localDate: '2026-07-27',
        createdAt: timestamp,
        updatedAt: timestamp,
        data: meal,
      ).toRecord();
      database.seed(
        IndexedDbStoreNames.foodRecords,
        envelope['id']! as String,
        envelope,
      );

      await tester.pumpWidget(const MaterialApp(home: FoodHistoryPage()));
      await tester.pumpAndSettle();

      expect(find.text('Measured  10g'), findsOneWidget);
      expect(find.text('Measured  AMOUNT 0.1 (10g)'), findsOneWidget);
    });
  });

  group('Food post-save navigation', () {
    late FakeIndexedDbDatabase database;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      appInitializationController.markReady();
      database = FakeIndexedDbDatabase();
      final now = DateTime.now();
      final localDate =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      seedOperationState(database, localDate);
      AppRepositoryRegistry.beginStartup(
        controller: appInitializationController,
      );
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    });

    tearDown(AppRepositoryRegistry.resetForTesting);

    testWidgets('Operation Date gate hides FOOD form until resolved', (
      tester,
    ) async {
      final operationState = Completer<OperationState>();
      await tester.pumpWidget(
        MaterialApp(
          home: FoodEntryPage(
            operationDateService: operationDateServiceFromFuture(
              operationState.future,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FoodInputForm), findsNothing);

      operationState.complete(operationStateForTest('2026-07-31'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(FoodInputForm), findsOneWidget);
    });

    testWidgets('Operation Date failure shows only FOOD error', (tester) async {
      final operationState = Completer<OperationState>();
      await tester.pumpWidget(
        MaterialApp(
          home: FoodEntryPage(
            operationDateService: operationDateServiceFromFuture(
              operationState.future,
            ),
          ),
        ),
      );
      await tester.pump();
      operationState.completeError(StateError('missing operation state'));
      await tester.pumpAndSettle();

      expect(find.text('Operation Dateを取得できませんでした。'), findsOneWidget);
      expect(find.byType(FoodInputForm), findsNothing);
      expect(find.text('SAVE MEAL'), findsNothing);
    });

    testWidgets('SAVE MEAL returns once to the FOOD module after success', (
      tester,
    ) async {
      final observer = _CountingNavigatorObserver();
      await _pumpFoodModule(tester, observer: observer);
      await tester.tap(find.text('FOOD ENTRY'));
      await tester.pumpAndSettle();

      await _enterNavigationMeal(tester);
      await tester.ensureVisible(find.text('SAVE MEAL'));
      await tester.tap(find.text('SAVE MEAL'));
      await tester.pumpAndSettle();

      _expectFoodModule();
      expect(find.text('MEALを保存しました'), findsOneWidget);
      expect(find.byType(FoodEntryPage), findsNothing);
      expect(observer.popCount, 1);
    });

    testWidgets('UPDATE MEAL returns once to the FOOD module after success', (
      tester,
    ) async {
      final observer = _CountingNavigatorObserver();
      final navigatorKey = GlobalKey<NavigatorState>();
      final meal = _existingNavigationMeal();
      await AppRepositoryRegistry.container.food.save(meal);
      await _pumpFoodModule(
        tester,
        observer: observer,
        navigatorKey: navigatorKey,
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => FoodEditPage(meal: meal)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('UPDATE MEAL'));
      await tester.tap(find.text('UPDATE MEAL'));
      await tester.pumpAndSettle();

      _expectFoodModule();
      expect(find.text('MEALを更新しました'), findsOneWidget);
      expect(find.byType(FoodEditPage), findsNothing);
      expect(observer.popCount, 1);
    });

    testWidgets('validation failure keeps the FOOD input page', (tester) async {
      await _pumpFoodModule(tester);
      await tester.tap(find.text('FOOD ENTRY'));
      await tester.pumpAndSettle();

      expect(find.text('SAVE MEAL'), findsNothing);
      expect(find.byType(FoodEntryPage), findsOneWidget);
      expect(find.text('REPORT SYNC'), findsNothing);
    });

    testWidgets('save failure keeps the FOOD input and its values', (
      tester,
    ) async {
      final now = DateTime.now();
      await DailyLogConfirmationRepository.save(
        DailyLogConfirmation(
          date: DateTime(now.year, now.month, now.day),
          confirmedAt: now,
          morning: null,
          food: null,
          activity: null,
          training: null,
        ),
      );
      await _pumpFoodModule(tester);
      await tester.tap(find.text('FOOD ENTRY'));
      await tester.pumpAndSettle();

      await _enterNavigationMeal(tester);
      await tester.ensureVisible(find.text('SAVE MEAL'));
      await tester.tap(find.text('SAVE MEAL'));
      await tester.pumpAndSettle();

      expect(find.byType(FoodEntryPage), findsOneWidget);
      expect(find.text('REPORT SYNC'), findsNothing);
      expect(find.textContaining('この日のログは確定済みです'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('Food Name')).controller?.text,
        'Navigation Meal',
      );
    });
  });
}

Future<void> _pumpFoodModule(
  WidgetTester tester, {
  NavigatorObserver? observer,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      initialRoute: AppRoutes.food,
      routes: {AppRoutes.food: (_) => const FoodPage()},
      navigatorObservers: [?observer],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterNavigationMeal(WidgetTester tester) async {
  await tester.enterText(_field('Food Name'), 'Navigation Meal');
  await tester.enterText(_field('Calories'), '100');
  await tester.enterText(_field('Protein'), '10');
  await tester.enterText(_field('Fat'), '5');
  await tester.enterText(_field('Carbohydrate'), '20');
  await tester.pump();
}

void _expectFoodModule() {
  expect(find.text('REPORT SYNC'), findsOneWidget);
  expect(find.text('MANUAL ENTRY'), findsOneWidget);
  expect(find.text('RECORD'), findsWidgets);
}

MealData _existingNavigationMeal() {
  final now = DateTime.now();
  final date =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  return MealData(
    id: 'food-navigation-edit',
    date: date,
    mealType: 'Dinner',
    items: [
      FoodItem(
        name: 'Existing Meal',
        calories: 100,
        protein: 10,
        fat: 5,
        carbohydrate: 20,
      ),
    ],
    memo: '',
  );
}

class _CountingNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}

class _NutritionGateway implements FoodInputCaptureGateway {
  @override
  Future<String> recognizeJapaneseText(
    FoodCapturedImage image, {
    FoodTextOcrMode mode = FoodTextOcrMode.package,
  }) async => '100gあたり\nエネルギー 154kcal\nたんぱく質 1.9g\n脂質 5.5g\n炭水化物 24.2g';

  @override
  Future<String?> scanBarcode(FoodCapturedImage image) async => null;

  @override
  Future<FoodCapturedImage?> selectImage(FoodImageSource source) async =>
      const FoodCapturedImage('data:image/png;base64,AA==');
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

FoodCatalogEntry _catalogEntry() {
  final timestamp = DateTime.utc(2026, 8, 1);
  return FoodCatalogEntry(
    foodId: '11111111-1111-4111-8111-111111111111',
    name: 'Catalog Aligned Food',
    category: FoodCatalogCategory.packagedFood,
    brand: 'OR FOODS',
    barcodeValue: '4901234567894',
    barcodeFormat: FoodBarcodeFormat.ean13,
    packageQuantity: 500,
    packageUnit: FoodQuantityUnit.gram,
    baseQuantity: FoodQuantityDefinition(
      value: 100,
      unit: FoodQuantityUnit.gram,
    ),
    nutrition: NutritionSnapshot(
      calories: 154,
      protein: 1.9,
      fat: 5.5,
      carbohydrate: 24.2,
    ),
    nutritionStatus: NutritionStatus.declared,
    provenance: FoodDataProvenance(
      sourceType: FoodProvenanceSourceType.userInput,
      capturedAt: timestamp,
    ),
    isArchived: false,
    memo: 'Catalog memo',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

FoodItem _multiplierItem({
  double baseAmount = 100,
  double amount = 1,
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
    amountMode: FoodAmountMode.baseMultiplier,
  );
}

Finder _field(String label) {
  final alignedLabel = switch (label) {
    'Food Name' => 'NAME',
    'Calories' => 'CALORIES',
    'Protein' => 'PROTEIN',
    'Fat' => 'FAT',
    'Carbohydrate' => 'CARBOHYDRATE',
    _ => label,
  };
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == alignedLabel,
    description: 'TextField with label $alignedLabel',
  );
}

String _controllerText(WidgetTester tester, String label) {
  return tester.widget<TextField>(_field(label)).controller!.text;
}
