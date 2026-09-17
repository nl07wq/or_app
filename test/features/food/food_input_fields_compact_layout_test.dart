import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_spacing.dart';
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
    final stepperBounds = tester.getRect(
      find.byKey(const ValueKey('food-amount-stepper-column')),
    );
    expect(amountBounds.top, memoBounds.top);
    expect(amountBounds.bottom, memoBounds.bottom);
    expect(stepperBounds.top, amountBounds.top);
    expect(stepperBounds.bottom, amountBounds.bottom);
    expect(stepperBounds.width, FoodNumericStepper.width);
    expect(memoBounds.width, greaterThan(amountBounds.width));
    final incrementBounds = tester.getRect(
      find.byKey(const ValueKey('food-amount-increment')),
    );
    final decrementBounds = tester.getRect(
      find.byKey(const ValueKey('food-amount-decrement')),
    );
    expect(incrementBounds.top, greaterThanOrEqualTo(amountBounds.top));
    expect(decrementBounds.bottom, lessThanOrEqualTo(amountBounds.bottom));
    expect(incrementBounds.center.dy, lessThan(decrementBounds.center.dy));
    expect(find.text('栄養成分の基準量を設定'), findsOneWidget);
    expect(find.text('100gあたりの栄養成分'), findsOneWidget);
    expect(find.text('NUTRITION PER 100g'), findsNothing);
    expect(find.text('SET PACKAGE QUANTITY AND UNIT'), findsNothing);
    expect(tester.getSize(_field('NAME')).height, lessThan(56));
    final packageLabel = find.byKey(
      const ValueKey('food-entry-package-group-label'),
    );
    final baseLabel = find.byKey(const ValueKey('food-entry-base-group-label'));
    expect(
      tester.getCenter(packageLabel).dx,
      closeTo(_pairCenterX(tester, _field('表示量'), _packageUnit()), .5),
    );
    expect(
      tester.getCenter(baseLabel).dx,
      closeTo(_pairCenterX(tester, _field('登録基準量'), _baseUnit()), .5),
    );
    expect(
      tester.getRect(_packageUnit()).left - tester.getRect(_field('表示量')).right,
      closeTo(AppSpacing.xs, .01),
    );
    expect(
      tester.getRect(_baseUnit()).left - tester.getRect(_field('登録基準量')).right,
      closeTo(AppSpacing.xs, .01),
    );
    for (final field in [
      _field('表示量'),
      _packageUnit(),
      _field('登録基準量'),
      _baseUnit(),
    ]) {
      final widget = tester.widget(field);
      final decoration = switch (widget) {
        TextField() => widget.decoration,
        DropdownButtonFormField() => widget.decoration,
        _ => null,
      };
      expect(decoration?.border, isA<OutlineInputBorder>());
    }
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
    final twoLineStepper = tester.getRect(
      find.byKey(const ValueKey('food-amount-stepper-column')),
    );
    final twoLineAmount = tester.getRect(_amount());
    final twoLineMemo = tester.getRect(memo);
    expect(twoLineStepper.top, twoLineAmount.top);
    expect(twoLineStepper.bottom, twoLineAmount.bottom);
    expect(twoLineMemo.top, twoLineAmount.top);
    expect(twoLineMemo.bottom, twoLineAmount.bottom);

    await tester.enterText(memo, 'first line\nsecond line\nthird line');
    await tester.pump();
    expect(twoLineHeight, greaterThan(oneLineHeight));
    expect(tester.getSize(memo).height, twoLineHeight);
    expect(controllers.memo.text, contains('third line'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('900px retains the explicit three-part amount row', (
    tester,
  ) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    await tester.binding.setSurfaceSize(const Size(900, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_subject(controllers, width: 560));

    final amount = tester.getRect(_amount());
    final stepper = tester.getRect(
      find.byKey(const ValueKey('food-amount-stepper-column')),
    );
    final memo = tester.getRect(_field('MEMO'));
    expect(amount.top, stepper.top);
    expect(stepper.top, memo.top);
    expect(amount.bottom, stepper.bottom);
    expect(stepper.bottom, memo.bottom);
    expect(amount.center.dx, lessThan(memo.center.dx));
    expect(memo.width, greaterThan(amount.width));
  });

  testWidgets(
    '390px keeps every canonical unit clear of its selector chevron',
    (tester) async {
      for (final unit in FoodQuantityUnit.values) {
        final controllers = _Controllers();
        addTearDown(controllers.dispose);
        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pumpWidget(
          _subject(controllers, width: 320, packageUnit: unit, baseUnit: unit),
        );
        final label = _unitLabel(unit);
        for (final field in [_packageUnit(), _baseUnit()]) {
          final bounds = tester.getRect(field);
          final text = find.descendant(of: field, matching: find.text(label));
          expect(text, findsOneWidget);
          final chevron = find.descendant(
            of: field,
            matching: find.byIcon(Icons.arrow_drop_down),
          );
          expect(chevron, findsOneWidget);
          expect(
            tester.getRect(text).right,
            lessThan(tester.getRect(chevron).left),
          );
          expect(tester.getRect(text).left, greaterThan(bounds.left));
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

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

  testWidgets('category and manual validation text use compact Japanese UI', (
    tester,
  ) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(
      _subject(
        controllers,
        width: 320,
        recalculationBlockReason: 'NUTRITION BASIS MUST BE GREATER THAN ZERO',
      ),
    );

    final category = tester.widget<Text>(find.text('調理済み食品'));
    expect(category.style?.fontSize, 14);
    expect(find.text('登録基準量は0より大きい値を入力してください'), findsOneWidget);
    expect(
      find.text('NUTRITION BASIS MUST BE GREATER THAN ZERO'),
      findsNothing,
    );

    controllers.base.clear();
    await tester.pumpWidget(_subject(controllers, width: 320));
    expect(find.text('栄養成分'), findsOneWidget);
    expect(find.text('—gあたりの栄養成分'), findsNothing);
  });

  testWidgets('manual nutrition validation localizes all visible reasons', (
    tester,
  ) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(
      _subject(
        controllers,
        width: 320,
        recalculationBlockReason: 'ENTER AT LEAST ONE NUTRITION VALUE',
      ),
    );

    expect(find.text('栄養成分を1項目以上入力してください'), findsOneWidget);
    expect(find.text('ENTER AT LEAST ONE NUTRITION VALUE'), findsNothing);
  });
}

Widget _subject(
  _Controllers controllers, {
  required double width,
  FoodQuantityUnit baseUnit = FoodQuantityUnit.gram,
  FoodQuantityUnit packageUnit = FoodQuantityUnit.gram,
  String? recalculationBlockReason,
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
          packageUnit: packageUnit,
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
          recalculationBlockReason: recalculationBlockReason,
        ),
      ),
    ),
  ),
);

Finder _field(String label) => switch (label) {
  '表示量' => find.byKey(const ValueKey('food-entry-package-quantity')),
  '登録基準量' => find.byKey(const ValueKey('food-entry-base-quantity')),
  _ => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField with label $label',
  ),
};

Finder _category() =>
    find.byKey(const ValueKey('food-entry-category-preparedFood'));
Finder _scan() => find.byKey(const ValueKey('food-entry-barcode-scan'));
Finder _packageUnit() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey &&
      (widget.key! as ValueKey).value.toString().startsWith(
        'food-entry-package-unit-',
      ),
);
Finder _baseUnit() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey &&
      (widget.key! as ValueKey).value.toString().startsWith(
        'food-entry-base-unit-',
      ),
);
String _unitLabel(FoodQuantityUnit unit) => switch (unit) {
  FoodQuantityUnit.gram => 'g',
  FoodQuantityUnit.milliliter => 'mL',
  FoodQuantityUnit.piece => 'piece',
  FoodQuantityUnit.pack => 'pack',
  FoodQuantityUnit.serving => 'serving',
};
Finder _amount() => find.byKey(const ValueKey('food-amount-input'));
double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;
double _centerY(WidgetTester tester, Finder finder) =>
    tester.getCenter(finder).dy;

double _pairCenterX(WidgetTester tester, Finder first, Finder second) {
  final firstBounds = tester.getRect(first);
  final secondBounds = tester.getRect(second);
  return (firstBounds.left + secondBounds.right) / 2;
}

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
