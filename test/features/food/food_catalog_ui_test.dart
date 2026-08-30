import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/repository/food_catalog_repository.dart';

void main() {
  testWidgets('food database uses Japanese human-facing description', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FoodPage()));

    expect(find.text('食品・商品情報と栄養データを登録し、\n食事記録で再利用できます。'), findsOneWidget);
    expect(
      find.text('Reusable food, package, and nutrition reference data.'),
      findsNothing,
    );
  });

  testWidgets('catalog category is presented in Japanese without enum names', (
    tester,
  ) async {
    final repository = _MemoryCatalogRepository(const []);
    await tester.pumpWidget(
      MaterialApp(home: FoodCatalogEditorPage(repository: repository)),
    );

    expect(find.text('市販・包装食品'), findsOneWidget);
    expect(find.text('PACKAGEDFOOD'), findsNothing);
    expect(find.text('BARCODE FORMAT'), findsNothing);

    await tester.tap(find.text('市販・包装食品'));
    await tester.pumpAndSettle();
    for (final label in ['食材', '調理済み食品', '市販・包装食品', '飲料']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('searches name brand and barcode and excludes archived entries', (
    tester,
  ) async {
    final repository = _MemoryCatalogRepository([
      _entry(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Rice',
        brand: 'OR Foods',
        barcode: '04901234567890',
      ),
      _entry(
        id: '22222222-2222-4222-8222-222222222222',
        name: 'Archived',
        archived: true,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: FoodCatalogPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Archived'), findsNothing);
    for (final query in ['rice', 'or foods', '0490123']) {
      await tester.enterText(
        find.byKey(const ValueKey('food-catalog-search')),
        query,
      );
      await tester.pump();
      expect(find.text('Rice'), findsOneWidget);
    }
    await tester.enterText(
      find.byKey(const ValueKey('food-catalog-search')),
      'missing',
    );
    await tester.pump();
    expect(find.text('食品が見つかりません'), findsOneWidget);
  });

  testWidgets('detail separates package and basis and renders PFC ring', (
    tester,
  ) async {
    final entry = _entry(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Protein Food',
      brand: 'Test Brand',
      barcode: '04901234567890',
      memo: 'Test memo',
      nutrition: NutritionSnapshot(
        calories: 285.6,
        protein: 12.2,
        fat: 19.3,
        carbohydrate: 16.2,
      ),
    );
    final repository = _MemoryCatalogRepository([entry]);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogDetailPage(entry: entry, repository: repository),
      ),
    );

    expect(find.text('PACKAGE SIZE'), findsOneWidget);
    expect(find.text('NUTRITION BASIS'), findsOneWidget);
    expect(find.text('市販・包装食品'), findsOneWidget);
    for (final label in [
      'CATEGORY',
      'NUTRITION BASIS',
      'PACKAGE SIZE',
      'BRAND',
      'BARCODE / JAN',
      'MEMO',
    ]) {
      expect(tester.widget<Text>(find.text(label)).style?.color, isNotNull);
    }
    expect(
      tester.widget<Text>(find.text('市販・包装食品')).style?.fontWeight,
      FontWeight.w600,
    );
    expect(find.text('PFC BALANCE'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('286'), findsOneWidget);
    expect(find.text('kcal'), findsOneWidget);
    expect(find.text('PROTEIN'), findsOneWidget);
    expect(find.text('FAT'), findsOneWidget);
    expect(find.text('CARBOHYDRATE'), findsOneWidget);
    expect(find.text('12.2 g'), findsOneWidget);
    expect(find.text('19.3 g'), findsOneWidget);
    expect(find.text('16.2 g'), findsOneWidget);
    expect(find.text('17%'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('23%'), findsOneWidget);
    expect(foodDetailPfcRingWidth, 12);
    expect(
      tester.widget<Text>(find.text('PROTEIN')).style?.color,
      foodDetailProteinColor,
    );
    expect(
      tester.widget<Text>(find.text('19.3 g')).style?.color,
      foodDetailFatColor,
    );
    expect(
      tester.widget<Text>(find.text('23%')).style?.color,
      foodDetailCarbohydrateColor,
    );
    final carbohydrate = tester.getRect(find.text('CARBOHYDRATE'));
    final carbohydrateGrams = tester.getRect(find.text('16.2 g'));
    final carbohydratePercent = tester.getRect(find.text('23%'));
    expect(carbohydrate.right, lessThanOrEqualTo(carbohydrateGrams.left));
    expect(
      carbohydrateGrams.right,
      lessThanOrEqualTo(carbohydratePercent.left),
    );
    final donut = tester.getRect(
      find.byKey(const ValueKey('food-detail-pfc-donut')),
    );
    final protein = tester.getRect(
      find.byKey(const ValueKey('food-detail-pfc-PROTEIN')),
    );
    expect(protein.left, greaterThan(donut.right));
    expect(entry.nutrition.calories, 285.6);
    final informationCard = find.byKey(
      const ValueKey('food-detail-information-card'),
    );
    for (final label in ['CALORIES', 'PROTEIN', 'FAT', 'CARBOHYDRATE']) {
      expect(
        find.descendant(of: informationCard, matching: find.text(label)),
        findsNothing,
      );
    }
  });

  testWidgets('PFC detail stays horizontal without overflow at target widths', (
    tester,
  ) async {
    final entry = _entry(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Responsive Food',
    );
    for (final width in [320.0, 390.0, 900.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: FoodCatalogDetailPage(
            entry: entry,
            repository: _MemoryCatalogRepository([entry]),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('food-detail-pfc-horizontal')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('missing or zero PFC does not render a chart', (tester) async {
    for (final nutrition in [
      NutritionSnapshot(calories: 100),
      NutritionSnapshot(calories: 0, protein: 0, fat: 0, carbohydrate: 0),
    ]) {
      final entry = _entry(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'No Chart Food',
        nutrition: nutrition,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FoodCatalogDetailPage(
            entry: entry,
            repository: _MemoryCatalogRepository([entry]),
          ),
        ),
      );
      expect(find.text('PFC BALANCE'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('archive copy matches non-destructive repository behavior', (
    tester,
  ) async {
    final entry = _entry(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Archive Food',
    );
    final repository = _MemoryCatalogRepository([entry]);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogDetailPage(entry: entry, repository: repository),
      ),
    );

    await tester.tap(find.text('アーカイブ'));
    await tester.pumpAndSettle();
    expect(find.text('この食品をアーカイブしますか？'), findsOneWidget);
    expect(find.textContaining('通常の利用対象から外れます'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect((await repository.readById(entry.foodId))!.isArchived, isFalse);

    await tester.tap(find.text('アーカイブ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('アーカイブ').last);
    await tester.pumpAndSettle();
    final archived = await repository.readById(entry.foodId);
    expect(archived?.isArchived, isTrue);
    expect(archived?.foodId, entry.foodId);
    expect(archived?.nutrition.toJson(), entry.nutrition.toJson());
    expect(await repository.list(), isEmpty);
  });

  testWidgets('direct entry saves v2 with userInput provenance', (
    tester,
  ) async {
    final repository = _MemoryCatalogRepository(const []);
    await tester.pumpWidget(
      MaterialApp(home: FoodCatalogEditorPage(repository: repository)),
    );
    await tester.enterText(find.widgetWithText(TextField, 'NAME'), 'New Food');
    await tester.enterText(
      find.widgetWithText(TextField, 'BARCODE / JAN'),
      '0012345678905',
    );
    await tester.enterText(find.widgetWithText(TextField, 'CALORIES'), '154');
    await tester.enterText(find.widgetWithText(TextField, 'PROTEIN'), '1.9');
    await tester.enterText(find.widgetWithText(TextField, 'FAT'), '5.5');
    await tester.enterText(
      find.widgetWithText(TextField, 'CARBOHYDRATE'),
      '24.2',
    );
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final saved = (await repository.list()).single;
    expect(saved.recordVersion, 2);
    expect(saved.barcodeValue, '0012345678905');
    expect(saved.barcodeFormat, FoodBarcodeFormat.ean13);
    expect(saved.provenance.sourceType, FoodProvenanceSourceType.userInput);
    expect(saved.nutrition.calories, 154);
  });

  testWidgets('catalog editor rounds presentation and preserves raw values', (
    tester,
  ) async {
    final entry = _entry(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Raw Food',
      nutrition: NutritionSnapshot(
        calories: 155.5882352941,
        protein: 2.5294117647,
        fat: 0.2941176471,
        carbohydrate: 35.5882352941,
      ),
    );
    final repository = _MemoryCatalogRepository([entry]);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogEditorPage(
          repository: repository,
          initialEntry: entry,
        ),
      ),
    );

    expect(_fieldText(tester, 'CALORIES'), '156');
    expect(_fieldText(tester, 'PROTEIN'), '2.5');
    expect(_fieldText(tester, 'FAT'), '0.3');
    expect(_fieldText(tester, 'CARBOHYDRATE'), '35.6');
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final saved = await repository.readById(entry.foodId);
    expect(saved!.nutrition.calories, entry.nutrition.calories);
    expect(saved.nutrition.protein, entry.nutrition.protein);
    expect(saved.nutrition.fat, entry.nutrition.fat);
    expect(saved.nutrition.carbohydrate, entry.nutrition.carbohydrate);
  });

  testWidgets('catalog review updates selected identity from aligned draft', (
    tester,
  ) async {
    final original = _entry(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Original Food',
      barcode: '04901234567890',
    );
    final repository = _MemoryCatalogRepository([original]);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogEditorPage(
          repository: repository,
          initialEntry: original,
          draft: FoodCatalogDraft(
            name: 'Reviewed Food',
            brand: 'Reviewed Brand',
            category: FoodCatalogCategory.preparedFood,
            barcodeValue: '04901234567890',
            packageQuantity: 500,
            packageUnit: FoodQuantityUnit.gram,
            baseQuantity: FoodQuantityDefinition(
              value: 100,
              unit: FoodQuantityUnit.gram,
            ),
            nutrition: NutritionSnapshot(
              calories: 200,
              protein: 10,
              fat: 5,
              carbohydrate: 20,
            ),
            memo: 'Reviewed memo',
          ),
        ),
      ),
    );

    expect(_fieldText(tester, 'NAME'), 'Reviewed Food');
    expect(_fieldText(tester, 'BRAND'), 'Reviewed Brand');
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final entries = await repository.list();
    expect(entries, hasLength(1));
    expect(entries.single.foodId, original.foodId);
    expect(entries.single.name, 'Reviewed Food');
    expect(entries.single.brand, 'Reviewed Brand');
  });

  for (final testCase in [
    (barcode: '4006381333931', format: FoodBarcodeFormat.ean13),
    (barcode: '96385074', format: FoodBarcodeFormat.ean8),
    (barcode: '036000291452', format: FoodBarcodeFormat.upc),
    (barcode: '4006381333932', format: FoodBarcodeFormat.unknown),
    (barcode: 'not-a-barcode', format: FoodBarcodeFormat.unknown),
  ]) {
    testWidgets(
      'barcode ${testCase.barcode} is saved as ${testCase.format.name}',
      (tester) async {
        final repository = _MemoryCatalogRepository(const []);
        await tester.pumpWidget(
          MaterialApp(home: FoodCatalogEditorPage(repository: repository)),
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'NAME'),
          'Barcode Food',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'BARCODE / JAN'),
          testCase.barcode,
        );
        await tester.ensureVisible(find.text('SAVE'));
        await tester.tap(find.text('SAVE'));
        await tester.pumpAndSettle();

        final saved = (await repository.list()).single;
        expect(saved.barcodeValue, testCase.barcode);
        expect(saved.barcodeFormat, testCase.format);
      },
    );
  }

  testWidgets('catalog draft preserves master metadata until user saves', (
    tester,
  ) async {
    final repository = _MemoryCatalogRepository(const []);
    final draft = FoodCatalogDraft(
      name: 'Draft Food',
      category: FoodCatalogCategory.beverage,
      brand: 'Draft Brand',
      barcodeValue: '4006381333931',
      barcodeFormat: FoodBarcodeFormat.ean13,
      packageQuantity: 500,
      packageUnit: FoodQuantityUnit.milliliter,
      baseQuantity: FoodQuantityDefinition(
        value: 100,
        unit: FoodQuantityUnit.milliliter,
      ),
      nutrition: NutritionSnapshot(
        calories: 42,
        protein: 1.2,
        fat: 0.3,
        carbohydrate: 9.4,
      ),
      memo: 'Draft memo',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogEditorPage(repository: repository, draft: draft),
      ),
    );

    expect(await repository.list(), isEmpty);
    expect(_fieldText(tester, 'NAME'), 'Draft Food');
    expect(_fieldText(tester, 'BRAND'), 'Draft Brand');
    expect(_fieldText(tester, 'BARCODE / JAN'), '4006381333931');
    expect(_fieldText(tester, 'PACKAGE QUANTITY'), '500');
    expect(find.text('飲料'), findsOneWidget);

    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final saved = (await repository.list()).single;
    expect(saved.brand, 'Draft Brand');
    expect(saved.category, FoodCatalogCategory.beverage);
    expect(saved.barcodeValue, '4006381333931');
    expect(saved.barcodeFormat, FoodBarcodeFormat.ean13);
    expect(saved.packageQuantity, 500);
    expect(saved.packageUnit, FoodQuantityUnit.milliliter);
  });

  testWidgets('cancel and invalid name do not create a catalog record', (
    tester,
  ) async {
    final repository = _MemoryCatalogRepository(const []);
    await tester.pumpWidget(
      MaterialApp(home: FoodCatalogEditorPage(repository: repository)),
    );
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pump();
    expect(find.text('ENTER VALID FOOD AND QUANTITY VALUES'), findsOneWidget);
    expect(await repository.list(), isEmpty);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(await repository.list(), isEmpty);
  });

  testWidgets('duplicate barcode reports existing food without overwrite', (
    tester,
  ) async {
    final original = _entry(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Original',
      barcode: '04901234567890',
    );
    final repository = _MemoryCatalogRepository([original]);
    await tester.pumpWidget(
      MaterialApp(home: FoodCatalogEditorPage(repository: repository)),
    );
    await tester.enterText(find.widgetWithText(TextField, 'NAME'), 'Duplicate');
    await tester.enterText(
      find.widgetWithText(TextField, 'BARCODE / JAN'),
      '04901234567890',
    );
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pump();

    expect(find.textContaining('EXISTING FOOD FOUND'), findsOneWidget);
    expect(await repository.list(), hasLength(1));
    expect((await repository.list()).single.name, 'Original');
  });

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('food page has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: FoodPage()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('catalog has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _MemoryCatalogRepository([
        _entry(
          id: '11111111-1111-4111-8111-111111111111',
          name: 'Responsive Food',
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(home: FoodCatalogPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('catalog editor has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: FoodCatalogEditorPage(
            repository: _MemoryCatalogRepository(const []),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

String _fieldText(WidgetTester tester, String label) => tester
    .widget<TextField>(find.widgetWithText(TextField, label))
    .controller!
    .text;

FoodCatalogEntry _entry({
  required String id,
  required String name,
  String? brand,
  String? barcode,
  String? memo,
  bool archived = false,
  NutritionSnapshot? nutrition,
}) {
  final timestamp = DateTime.utc(2026, 8, 29);
  return FoodCatalogEntry(
    foodId: id,
    name: name,
    category: FoodCatalogCategory.packagedFood,
    brand: brand,
    baseQuantity: FoodQuantityDefinition(
      value: 100,
      unit: FoodQuantityUnit.gram,
    ),
    nutrition:
        nutrition ??
        NutritionSnapshot(
          calories: 286,
          protein: 12.2,
          fat: 19.3,
          carbohydrate: 16.2,
        ),
    nutritionStatus: NutritionStatus.declared,
    provenance: FoodDataProvenance(
      sourceType: FoodProvenanceSourceType.userInput,
      capturedAt: timestamp,
    ),
    isArchived: archived,
    barcodeValue: barcode,
    barcodeFormat: barcode == null ? null : FoodBarcodeFormat.ean13,
    memo: memo,
    packageQuantity: 500,
    packageUnit: FoodQuantityUnit.gram,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _MemoryCatalogRepository implements FoodCatalogRepository {
  _MemoryCatalogRepository(Iterable<FoodCatalogEntry> entries)
    : _entries = {for (final entry in entries) entry.foodId: entry};

  final Map<String, FoodCatalogEntry> _entries;

  @override
  Future<void> archive(String foodId) async {
    final entry = _entries[foodId]!;
    _entries[foodId] = FoodCatalogEntry.fromJson({
      ...entry.toJson(),
      'isArchived': true,
    });
  }

  @override
  Future<void> create(FoodCatalogEntry entry) async =>
      _entries[entry.foodId] = entry;

  @override
  Future<List<FoodCatalogEntry>> list() async => _entries.values
      .where((entry) => !entry.isArchived)
      .toList(growable: false);

  @override
  Future<FoodCatalogEntry?> readById(String foodId) async => _entries[foodId];

  @override
  Future<void> update(FoodCatalogEntry entry) async =>
      _entries[entry.foodId] = entry;
}
