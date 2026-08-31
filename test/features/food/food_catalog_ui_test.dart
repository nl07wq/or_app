import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/repository/food_catalog_repository.dart';
import 'package:or_app/features/food/widgets/food_pfc_balance_card.dart';
import 'package:or_app/features/food/widgets/food_thumbnail.dart';

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

  testWidgets('catalog list uses selected thumbnail and null fallback', (
    tester,
  ) async {
    final repository = _MemoryCatalogRepository([
      _entry(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Meat Food',
        category: FoodCatalogCategory.ingredient,
        visualKey: FoodVisualKey.meat,
        nutrition: NutritionSnapshot(
          calories: 33,
          protein: 1,
          fat: 0.1,
          carbohydrate: 8.4,
        ),
      ),
      _entry(id: '22222222-2222-4222-8222-222222222222', name: 'Unset Food'),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: FoodCatalogPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('food-thumbnail-meat')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('food-thumbnail-fallback')),
      findsOneWidget,
    );
    expect(find.text('食材  100g'), findsOneWidget);
    expect(find.text('33kcal  P 1g  F 0.1g  C 8.4g'), findsOneWidget);
    expect(find.text('286kcal  P 12.2g  F 19.3g  C 16.2g'), findsOneWidget);
    expect(find.text('市販・包装食品  100g'), findsOneWidget);
    final primaryName = tester.widget<Text>(find.text('Meat Food'));
    final metadata = tester.widget<Text>(find.text('食材  100g'));
    expect(primaryName.style?.fontWeight, FontWeight.w700);
    expect(primaryName.style?.fontSize, greaterThan(metadata.style!.fontSize!));
    expect(metadata.style?.fontSize, 14);
  });

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets(
      'food nutrition metadata wraps without overflow at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _MemoryCatalogRepository([
          _entry(
            id: '11111111-1111-4111-8111-111111111111',
            name: '非常に長い市販・包装食品名でも読めるテスト食品',
            visualKey: FoodVisualKey.protein,
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(home: FoodCatalogPage(repository: repository)),
        );
        await tester.pumpAndSettle();

        final metadata = find.text('市販・包装食品  100g');
        expect(metadata, findsOneWidget);
        expect(find.text('286kcal  P 12.2g  F 19.3g  C 16.2g'), findsOneWidget);
        if (width == 390) {
          expect(tester.getSize(metadata).height, lessThan(20));
        }
        expect(
          find.byKey(const ValueKey('food-thumbnail-protein')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('thumbnail selector exposes exact options and persists edits', (
    tester,
  ) async {
    final original = _entry(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Visual Food',
    );
    final repository = _MemoryCatalogRepository([original]);

    Future<void> pumpEditor(FoodCatalogEntry entry) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-food-editor'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => FoodCatalogEditorPage(
                    repository: repository,
                    initialEntry: entry,
                  ),
                ),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-food-editor')));
      await tester.pumpAndSettle();
    }

    await pumpEditor(original);
    expect(find.text('NOT SET'), findsOneWidget);
    final change = find.byKey(const ValueKey('food-catalog-thumbnail-change'));
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    expect(find.text('SELECT THUMBNAIL'), findsOneWidget);
    expect(
      tester
          .widget<GridView>(find.byType(GridView))
          .childrenDelegate
          .estimatedChildCount,
      12,
    );
    final expectedChoiceKeys = {
      'food-thumbnail-choice-not-set',
      for (final key in FoodVisualKey.values)
        'food-thumbnail-choice-${key.stableId}',
    };
    final seenChoiceKeys = <String>{};
    for (var page = 0; page < 5; page++) {
      for (final inkWell in tester.widgetList<InkWell>(find.byType(InkWell))) {
        final value = switch (inkWell.key) {
          ValueKey<String>(value: final value) => value,
          _ => null,
        };
        if (value != null && value.startsWith('food-thumbnail-choice-')) {
          seenChoiceKeys.add(value);
        }
      }
      if (seenChoiceKeys.containsAll(expectedChoiceKeys)) break;
      await tester.drag(find.byType(GridView), const Offset(0, -250));
      await tester.pumpAndSettle();
    }
    expect(seenChoiceKeys, containsAll(expectedChoiceKeys));
    await tester.drag(find.byType(GridView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('food-thumbnail-choice-meat')));
    await tester.pumpAndSettle();
    expect(find.text('MEAT'), findsOneWidget);
    expect(find.text('市販・包装食品'), findsOneWidget);
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    var saved = (await repository.list()).single;
    expect(saved.visualKey, FoodVisualKey.meat);
    expect(saved.category, FoodCatalogCategory.packagedFood);

    await pumpEditor(saved);
    final category = find.byType(DropdownButtonFormField<FoodCatalogCategory>);
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('飲料').last);
    await tester.pump();
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('food-thumbnail-choice-fish')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    saved = (await repository.list()).single;
    expect(saved.visualKey, FoodVisualKey.fish);
    expect(saved.category, FoodCatalogCategory.beverage);

    await pumpEditor(saved);
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('food-thumbnail-choice-not-set')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    saved = (await repository.list()).single;
    expect(saved.visualKey, isNull);
    expect(saved.category, FoodCatalogCategory.beverage);
  });

  testWidgets('thumbnail selector remains usable at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
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
    final change = find.byKey(const ValueKey('food-catalog-thumbnail-change'));
    await tester.ensureVisible(change);
    expect(
      find.byKey(const ValueKey('food-catalog-thumbnail-layout-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('food-catalog-attributes-stacked')),
      findsOneWidget,
    );
    final heading = tester.widget<Text>(
      find.byKey(const ValueKey('food-catalog-thumbnail-label')),
    );
    expect(heading.maxLines, 1);
    expect(heading.softWrap, isFalse);
    expect(heading.overflow, isNot(TextOverflow.ellipsis));
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('food-catalog-thumbnail-value')),
          )
          .data,
      'NOT SET',
    );
    await tester.tap(change);
    await tester.pumpAndSettle();
    expect(find.text('SELECT THUMBNAIL'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('food-thumbnail-choice-meat')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('food-thumbnail-choice-meat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('food-thumbnail-meat')), findsOneWidget);
    expect(find.text('MEAT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final visualKey in <FoodVisualKey?>[
    null,
    FoodVisualKey.meat,
    FoodVisualKey.condiment,
    FoodVisualKey.protein,
  ]) {
    testWidgets('selected thumbnail preview stays readable at 320px for '
        '${visualKey?.stableId ?? 'not-set'}', (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: FoodCatalogEditorPage(
            repository: _MemoryCatalogRepository(const []),
            initialEntry: _entry(
              id: '11111111-1111-4111-8111-111111111111',
              name: 'Responsive Food With A Very Long Neighboring Name',
              brand: 'Responsive Brand With Long Neighboring Content',
              visualKey: visualKey,
            ),
          ),
        ),
      );
      final field = find.byKey(const ValueKey('food-catalog-thumbnail-field'));
      await tester.ensureVisible(field);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('food-catalog-thumbnail-layout-compact')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('food-catalog-thumbnail-label')))
            .height,
        lessThan(30),
      );
      expect(
        find.byKey(
          ValueKey(
            visualKey == null
                ? 'food-thumbnail-fallback'
                : 'food-thumbnail-${visualKey.stableId}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('food-catalog-thumbnail-value')),
            )
            .data,
        visualKey == null ? 'NOT SET' : foodVisualKeyLabel(visualKey),
      );
      final change = find.byKey(
        const ValueKey('food-catalog-thumbnail-change'),
      );
      expect(tester.getSize(change).width, greaterThanOrEqualTo(64));
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(find.text('SELECT THUMBNAIL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('food attributes stack readably at ${width.toInt()}px', (
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
            initialEntry: _entry(
              id: '11111111-1111-4111-8111-111111111111',
              name: 'Responsive Food',
              visualKey: FoodVisualKey.meat,
            ),
          ),
        ),
      );
      final field = find.byKey(const ValueKey('food-catalog-thumbnail-field'));
      await tester.ensureVisible(field);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('food-catalog-attributes-stacked')),
        findsOneWidget,
      );
      expect(find.text('市販・包装食品'), findsOneWidget);
      expect(find.text('THUMBNAIL'), findsOneWidget);
      expect(find.byKey(const ValueKey('food-thumbnail-meat')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [900.0, 1280.0]) {
    testWidgets('food attributes remain paired at ${width.toInt()}px', (
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
            initialEntry: _entry(
              id: '11111111-1111-4111-8111-111111111111',
              name: 'Responsive Food',
              visualKey: FoodVisualKey.meat,
            ),
          ),
        ),
      );
      final field = find.byKey(const ValueKey('food-catalog-thumbnail-field'));
      await tester.ensureVisible(field);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('food-catalog-attributes-paired')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('food-catalog-thumbnail-layout-dense')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('food-catalog-attributes-stacked')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('food-thumbnail-meat')), findsOneWidget);
      expect(find.text('市販・包装食品'), findsOneWidget);
      expect(find.text('THUMBNAIL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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

  testWidgets('delete removes only the catalog entry after confirmation', (
    tester,
  ) async {
    final entry = _entry(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Delete Food',
    );
    final repository = _MemoryCatalogRepository([entry]);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogDetailPage(entry: entry, repository: repository),
      ),
    );

    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    expect(find.text('この食品を削除しますか？'), findsOneWidget);
    expect(find.textContaining('過去に保存済みの食事記録は変更されません'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(await repository.readById(entry.foodId), isNotNull);

    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(await repository.readById(entry.foodId), isNull);
    expect(await repository.list(), isEmpty);
  });

  testWidgets('delete confirmation has no overflow at target widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      final entry = _entry(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Delete Food',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FoodCatalogDetailPage(
            entry: entry,
            repository: _MemoryCatalogRepository([entry]),
          ),
        ),
      );
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
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
      visualKey: FoodVisualKey.protein,
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
    expect(entries.single.visualKey, FoodVisualKey.protein);
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
          name: 'Responsive Food With A Long Display Name',
          visualKey: FoodVisualKey.fruit,
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
  FoodVisualKey? visualKey,
  FoodCatalogCategory category = FoodCatalogCategory.packagedFood,
}) {
  final timestamp = DateTime.utc(2026, 8, 29);
  return FoodCatalogEntry(
    foodId: id,
    name: name,
    category: category,
    visualKey: visualKey,
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
  Future<void> delete(String foodId) async => _entries.remove(foodId);

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
