import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_theme.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/widgets/food_input_fields.dart';

void main() {
  testWidgets('390px compact form groups related fields into dense rows', (
    tester,
  ) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_subject(controllers, width: 320));

    expect(tester.getSize(_field('NAME')).width, 320);
    expect(_centerY(tester, _field('BRAND')), _centerY(tester, _category()));
    expect(
      _centerY(tester, _field('BARCODE / JAN')),
      _centerY(tester, _scan()),
    );
    expect(_centerY(tester, _field('表示量')), _centerY(tester, _packageUnit()));
    expect(_centerY(tester, _field('表示量')), _centerY(tester, _field('登録基準量')));
    expect(_centerY(tester, _field('表示量')), _centerY(tester, _baseUnit()));
    expect(
      _centerY(tester, _field('CALORIES')),
      _centerY(tester, _field('PROTEIN')),
    );
    expect(
      _centerY(tester, _field('FAT')),
      _centerY(tester, _field('CARBOHYDRATE')),
    );
    final amountBounds = tester.getRect(_amount());
    final memoBounds = tester.getRect(_field('MEMO'));
    expect(amountBounds.top, memoBounds.top);
    expect(amountBounds.bottom, memoBounds.bottom);
    expect(find.text('栄養成分の基準量を設定'), findsOneWidget);
    expect(find.text('100gあたりの栄養成分'), findsOneWidget);
    expect(find.text('NUTRITION PER 100g'), findsNothing);
    expect(find.text('SET PACKAGE QUANTITY AND UNIT'), findsNothing);
    expect(tester.getSize(_field('NAME')).height, lessThan(56));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320px falls back safely without compressing quantity semantics',
    (tester) async {
      final controllers = _Controllers();
      addTearDown(controllers.dispose);
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_subject(controllers, width: 250));

      expect(
        _top(tester, _field('BRAND')),
        lessThan(_top(tester, _category())),
      );
      expect(
        _top(tester, _field('表示量')),
        lessThan(_top(tester, _field('登録基準量'))),
      );
      expect(_top(tester, _amount()), lessThan(_top(tester, _field('MEMO'))));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Memo grows from one line to two visible lines and then caps', (
    tester,
  ) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(_subject(controllers, width: 320));
    final memo = _field('MEMO');
    final oneLineHeight = tester.getSize(memo).height;

    await tester.enterText(memo, 'first line\nsecond line');
    await tester.pump();
    final twoLineHeight = tester.getSize(memo).height;

    await tester.enterText(memo, 'first line\nsecond line\nthird line');
    await tester.pump();
    expect(twoLineHeight, greaterThan(oneLineHeight));
    expect(tester.getSize(memo).height, twoLineHeight);
    expect(controllers.memo.text, contains('third line'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dynamic conversion label preserves its target basis', (
    tester,
  ) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(_subject(controllers, width: 320));
    expect(find.text('100gあたりに換算'), findsOneWidget);
    expect(find.text('100gあたりの栄養成分'), findsOneWidget);

    controllers.base.text = '50';
    await tester.pumpWidget(_subject(controllers, width: 320));
    expect(find.text('50gあたりに換算'), findsOneWidget);
    expect(find.text('50gあたりの栄養成分'), findsOneWidget);

    await tester.pumpWidget(
      _subject(controllers, width: 320, baseUnit: FoodQuantityUnit.milliliter),
    );
    controllers.base.text = '250';
    await tester.pumpWidget(
      _subject(controllers, width: 320, baseUnit: FoodQuantityUnit.milliliter),
    );
    expect(find.text('250mLあたりに換算'), findsOneWidget);
    expect(find.text('250mLあたりの栄養成分'), findsOneWidget);
  });
}

Widget _subject(
  _Controllers controllers, {
  required double width,
  FoodQuantityUnit baseUnit = FoodQuantityUnit.gram,
}) => MaterialApp(
  theme: StandardTheme.theme,
  home: Scaffold(
    body: SingleChildScrollView(
      child: SizedBox(
        width: width,
        child: FoodInputFields(
          foodNameController: controllers.name,
          brandController: controllers.brand,
          barcodeController: controllers.barcode,
          packageQuantityController: controllers.packageQuantity,
          calorieController: controllers.calories,
          proteinController: controllers.protein,
          fatController: controllers.fat,
          carbohydrateController: controllers.carbohydrate,
          baseAmountController: controllers.base,
          amountController: controllers.amount,
          foodMemoController: controllers.memo,
          category: FoodCatalogCategory.preparedFood,
          packageUnit: FoodQuantityUnit.gram,
          baseUnit: baseUnit,
          onChanged: (_) {},
          onBaseAmountChanged: (_) {},
          onBaseUnitChanged: (_) {},
          onCategoryChanged: (_) {},
          onPackageQuantityChanged: (_) {},
          onPackageUnitChanged: (_) {},
          onCaloriesChanged: () {},
          onProteinChanged: () {},
          onFatChanged: () {},
          onCarbohydrateChanged: () {},
          onRecalculateNutrition: () {},
        ),
      ),
    ),
  ),
);

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
  description: 'TextField with label $label',
);

Finder _category() =>
    find.byKey(const ValueKey('food-entry-category-preparedFood'));
Finder _scan() => find.byKey(const ValueKey('food-entry-barcode-scan'));
Finder _packageUnit() =>
    find.byKey(const ValueKey('food-entry-package-unit-gram'));
Finder _baseUnit() => find.byKey(const ValueKey('food-entry-base-unit-gram'));
Finder _amount() => find.byKey(const ValueKey('food-amount-input'));
double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;
double _centerY(WidgetTester tester, Finder finder) =>
    tester.getCenter(finder).dy;

class _Controllers {
  final name = TextEditingController();
  final brand = TextEditingController();
  final barcode = TextEditingController();
  final packageQuantity = TextEditingController(text: '150');
  final calories = TextEditingController();
  final protein = TextEditingController();
  final fat = TextEditingController();
  final carbohydrate = TextEditingController();
  final base = TextEditingController(text: '100');
  final amount = TextEditingController(text: '1');
  final memo = TextEditingController();

  void dispose() {
    for (final controller in [
      name,
      brand,
      barcode,
      packageQuantity,
      calories,
      protein,
      fat,
      carbohydrate,
      base,
      amount,
      memo,
    ]) {
      controller.dispose();
    }
  }
}
