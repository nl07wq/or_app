import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/theme/app_theme.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/repository/food_catalog_repository.dart';
import 'package:or_app/features/food/widgets/food_input_fields.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';

void main() {
  tearDown(() {
    DeviceSettingsController.instance.update(
      DeviceSettingsController.instance.value.copyWith(
        baseCampLcdNegative: false,
      ),
    );
  });

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final presentation in [
      'standard',
      'base-camp-light',
      'base-camp-inv',
    ]) {
      testWidgets(
        'ADD FOOD UNIT is single-line at ${width.toInt()}px $presentation',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final baseCamp = presentation != 'standard';
          DeviceSettingsController.instance.update(
            DeviceSettingsController.instance.value.copyWith(
              baseCampLcdNegative: presentation == 'base-camp-inv',
            ),
          );

          await tester.pumpWidget(
            _editorHarness(
              repository: _MemoryCatalogRepository(),
              baseCamp: baseCamp,
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));

          final value = find.byKey(
            const ValueKey('food-entry-package-unit-value'),
          );
          final module = find.byKey(
            const ValueKey('food-entry-package-quantity-module'),
          );
          await tester.ensureVisible(module);
          await tester.pump();

          final selected = tester.widget<Text>(value);
          expect(selected.data, 'NOT SET');
          expect(selected.maxLines, 1);
          expect(selected.softWrap, isFalse);
          expect(selected.overflow, isNot(TextOverflow.ellipsis));
          final valueBounds = tester.getRect(value);
          final moduleBounds = tester.getRect(module);
          expect(valueBounds.left, greaterThanOrEqualTo(moduleBounds.left));
          expect(valueBounds.right, lessThanOrEqualTo(moduleBounds.right));
          expect(valueBounds.top, greaterThanOrEqualTo(moduleBounds.top));
          expect(valueBounds.bottom, lessThanOrEqualTo(moduleBounds.bottom));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'MANUAL ENTRY UNIT is single-line at ${width.toInt()}px $presentation',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controllers = _ManualControllers();
          addTearDown(controllers.dispose);
          final baseCamp = presentation != 'standard';
          DeviceSettingsController.instance.update(
            DeviceSettingsController.instance.value.copyWith(
              baseCampLcdNegative: presentation == 'base-camp-inv',
            ),
          );

          await tester.pumpWidget(
            _manualHarness(
              controllers: controllers,
              width: width - 32,
              baseCamp: baseCamp,
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));

          final value = find.byKey(
            const ValueKey('food-entry-package-unit-value'),
          );
          final module = find.byKey(
            const ValueKey('food-entry-package-quantity-module'),
          );
          await tester.ensureVisible(module);
          await tester.pump();
          final selected = tester.widget<Text>(value);
          expect(selected.data, 'NOT SET');
          expect(selected.maxLines, 1);
          expect(selected.softWrap, isFalse);
          expect(
            tester.getRect(module).contains(tester.getRect(value).topLeft),
            isTrue,
          );
          expect(
            tester.getRect(module).contains(tester.getRect(value).bottomRight),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('ADD FOOD dropdown stays expanded, selectable and independent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _editorHarness(repository: _MemoryCatalogRepository()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final package = find.byKey(
      const ValueKey('food-catalog-package-unit-none'),
    );
    _expectAllUnitOptions(tester, package);
    await tester.ensureVisible(package);
    await _selectUnit(tester, package, 'serving');
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('food-entry-package-unit-value')),
          )
          .data,
      'serving',
    );

    final basis = find.byKey(const ValueKey('food-catalog-base-unit-serving'));
    _expectAllUnitOptions(tester, basis, allowNull: false);
    await _selectUnit(tester, basis, 'pack');
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('food-entry-package-unit-value')),
          )
          .data,
      'serving',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('food-entry-base-unit-value')),
          )
          .data,
      'pack',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('package and basis UNIT values survive save and reopen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemoryCatalogRepository();
    await tester.pumpWidget(_editorHarness(repository: repository));
    await tester.pump(const Duration(milliseconds: 100));

    await _enter(tester, _fieldWithLabel('NAME'), 'Saved Food');
    await _enter(
      tester,
      find.byKey(const ValueKey('food-catalog-package-quantity')),
      '6',
    );
    for (final (label, value) in [
      ('CALORIES', '120'),
      ('PROTEIN', '10'),
      ('FAT', '4'),
      ('CARBOHYDRATE', '12'),
    ]) {
      await _enter(tester, _fieldWithLabel(label), value);
    }

    final package = find.byKey(
      const ValueKey('food-catalog-package-unit-none'),
    );
    await tester.ensureVisible(package);
    await _selectUnit(tester, package, 'serving');
    final basis = find.byKey(const ValueKey('food-catalog-base-unit-serving'));
    await _selectUnit(tester, basis, 'pack');

    final save = find.text('SAVE');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 400));

    final saved = (await repository.list()).single;
    expect(saved.packageUnit, FoodQuantityUnit.serving);
    expect(saved.baseQuantity.unit, FoodQuantityUnit.pack);

    await tester.pumpWidget(
      _editorHarness(repository: repository, initialEntry: saved),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('food-entry-package-unit-value')),
          )
          .data,
      'serving',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('food-entry-base-unit-value')),
          )
          .data,
      'pack',
    );
  });
}

Widget _editorHarness({
  required FoodCatalogRepository repository,
  FoodCatalogEntry? initialEntry,
  bool baseCamp = false,
}) {
  final editor = FoodCatalogEditorPage(
    repository: repository,
    initialEntry: initialEntry,
  );
  return MaterialApp(
    theme: StandardTheme.theme,
    home: baseCamp
        ? BaseCampScreenEntry(screen: BaseCampScreen.food, child: editor)
        : editor,
  );
}

Widget _manualHarness({
  required _ManualControllers controllers,
  required double width,
  required bool baseCamp,
}) {
  final scaffold = Scaffold(
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
          packageUnit: null,
          baseUnit: FoodQuantityUnit.gram,
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
        ),
      ),
    ),
  );
  return MaterialApp(
    theme: StandardTheme.theme,
    home: baseCamp
        ? BaseCampScreenEntry(screen: BaseCampScreen.food, child: scaffold)
        : scaffold,
  );
}

Finder _fieldWithLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
  description: 'TextField with label $label',
);

Future<void> _enter(WidgetTester tester, Finder finder, String value) async {
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

void _expectAllUnitOptions(
  WidgetTester tester,
  Finder dropdown, {
  bool allowNull = true,
}) {
  final button = tester.widget<DropdownButton<FoodQuantityUnit?>>(dropdown);
  final labels = button.items!
      .map((item) => (item.child as Text).data)
      .toList(growable: false);
  expect(labels, [
    if (allowNull) 'NOT SET',
    'g',
    'mL',
    'piece',
    'pack',
    'serving',
  ]);
}

Future<void> _selectUnit(
  WidgetTester tester,
  Finder dropdown,
  String label,
) async {
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pump(const Duration(milliseconds: 300));

  final option = find.text(label);
  for (var attempt = 0; attempt < 5 && option.evaluate().isEmpty; attempt++) {
    final visibleMenuItem = find.text(attempt.isEven ? 'mL' : 'piece');
    expect(visibleMenuItem, findsWidgets);
    await tester.drag(visibleMenuItem.last, const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(option, findsWidgets);
  await tester.tap(option.last);
  await tester.pump(const Duration(milliseconds: 300));
}

class _MemoryCatalogRepository implements FoodCatalogRepository {
  final List<FoodCatalogEntry> _entries = [];

  @override
  Future<void> archive(String foodId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> create(FoodCatalogEntry entry) async => _entries.add(entry);

  @override
  Future<void> delete(String foodId) async {
    _entries.removeWhere((entry) => entry.foodId == foodId);
  }

  @override
  Future<List<FoodCatalogEntry>> list() async => List.unmodifiable(_entries);

  @override
  Future<FoodCatalogEntry?> readById(String foodId) async {
    for (final entry in _entries) {
      if (entry.foodId == foodId) return entry;
    }
    return null;
  }

  @override
  Future<void> update(FoodCatalogEntry entry) async {
    final index = _entries.indexWhere((value) => value.foodId == entry.foodId);
    _entries[index] = entry;
  }
}

class _ManualControllers {
  final name = TextEditingController();
  final brand = TextEditingController();
  final barcode = TextEditingController();
  final packageQuantity = TextEditingController(text: '1');
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
