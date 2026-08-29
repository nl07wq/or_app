import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/repository/food_catalog_repository.dart';

void main() {
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
    expect(find.text('NO FOOD FOUND'), findsOneWidget);
  });

  testWidgets('detail separates package and basis and renders PFC ring', (
    tester,
  ) async {
    final entry = _entry(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Protein Food',
      barcode: '04901234567890',
    );
    final repository = _MemoryCatalogRepository([entry]);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogDetailPage(entry: entry, repository: repository),
      ),
    );

    expect(find.text('PACKAGE SIZE'), findsOneWidget);
    expect(find.text('NUTRITION BASIS'), findsOneWidget);
    expect(find.text('PFC BALANCE'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('286 kcal'), findsOneWidget);
    expect(find.text('P 17%'), findsOneWidget);
    expect(find.text('F 60%'), findsOneWidget);
    expect(find.text('C 23%'), findsOneWidget);
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
    expect(saved.provenance.sourceType, FoodProvenanceSourceType.userInput);
    expect(saved.nutrition.calories, 154);
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
  }
}

FoodCatalogEntry _entry({
  required String id,
  required String name,
  String? brand,
  String? barcode,
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
