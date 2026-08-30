import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/repository/food_catalog_repository.dart';
import 'package:or_app/features/food/services/food_input_capture_gateway.dart';

void main() {
  testWidgets('package initially prefills basis and user override unlinks it', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(home: FoodCatalogEditorPage(repository: repository)),
    );

    await tester.enterText(_field('PACKAGE QUANTITY'), '500');
    final packageUnit = find
        .byType(DropdownButtonFormField<FoodQuantityUnit?>)
        .first;
    await tester.tap(packageUnit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('g').last);
    await tester.pump();
    expect(
      tester.widget<TextField>(_field('NUTRITION BASIS')).controller!.text,
      '500',
    );
    await tester.enterText(_field('NUTRITION BASIS'), '100');
    await tester.enterText(_field('PACKAGE QUANTITY'), '600');
    expect(
      tester.widget<TextField>(_field('NUTRITION BASIS')).controller!.text,
      '100',
    );
  });

  testWidgets('OCR previews before applying and never saves before SAVE', (
    tester,
  ) async {
    final repository = _Repository();
    final gateway = _Gateway(
      text: '100g当たり\nエネルギー 154kcal\nたんぱく質 1.9g\n脂質 5.5g\n炭水化物 24.2g\n内容量 35g',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogEditorPage(
          repository: repository,
          captureGateway: gateway,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('food-catalog-ocr')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAMERA'));
    await tester.pumpAndSettle();
    expect(find.text('OCR PREVIEW'), findsOneWidget);
    expect(repository.entries, isEmpty);
    await tester.tap(find.text('APPLY TO FORM'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_field('CALORIES')).controller!.text,
      '154',
    );
    expect(repository.entries, isEmpty);
  });

  testWidgets('OCR cancel leaves the form unchanged', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogEditorPage(
          repository: repository,
          captureGateway: _Gateway(text: '100g当たり\n熱量 42kcal'),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('food-catalog-ocr')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PHOTO LIBRARY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_field('CALORIES')).controller!.text, '');
  });

  testWidgets('barcode scan updates draft only', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogEditorPage(
          repository: repository,
          captureGateway: _Gateway(barcode: '4006381333931'),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('food-catalog-barcode-scan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAMERA'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_field('BARCODE / JAN')).controller!.text,
      '4006381333931',
    );
    expect(find.text('FORMAT  EAN13'), findsOneWidget);
    expect(repository.entries, isEmpty);
  });

  testWidgets('live barcode selection updates draft only after scanner use', (
    tester,
  ) async {
    final repository = _Repository();
    final gateway = _LiveGateway(
      barcode: const FoodBarcodeCandidate(
        value: '4901234567894',
        format: 'EAN-13',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogEditorPage(
          repository: repository,
          captureGateway: gateway,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('food-catalog-barcode-scan')));
    await tester.pumpAndSettle();

    expect(gateway.liveBarcodeCalls, 1);
    expect(
      tester.widget<TextField>(_field('BARCODE / JAN')).controller!.text,
      '4901234567894',
    );
    expect(repository.entries, isEmpty);
  });

  testWidgets('closing live barcode scanner preserves the draft', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogEditorPage(
          repository: repository,
          captureGateway: _LiveGateway(),
        ),
      ),
    );
    await tester.enterText(_field('BARCODE / JAN'), '4006381333931');
    await tester.tap(find.byKey(const ValueKey('food-catalog-barcode-scan')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(_field('BARCODE / JAN')).controller!.text,
      '4006381333931',
    );
    expect(repository.entries, isEmpty);
  });

  testWidgets('Food Database uses the aligned master capture order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FoodCatalogEditorPage(
          repository: _Repository(),
          captureGateway: _LiveGateway(),
        ),
      ),
    );

    final ordered = [
      _field('NAME'),
      _field('BRAND'),
      _field('BARCODE / JAN'),
      _field('PACKAGE QUANTITY'),
      _field('NUTRITION BASIS'),
      find.byKey(const ValueKey('food-catalog-ocr')),
      _field('CALORIES'),
      _field('FAT'),
      _field('MEMO'),
    ];
    for (var index = 1; index < ordered.length; index += 1) {
      expect(
        tester.getTopLeft(ordered[index]).dy,
        greaterThan(tester.getTopLeft(ordered[index - 1]).dy),
      );
    }
    expect(_field('PROTEIN'), findsOneWidget);
    expect(_field('CARBOHYDRATE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('food-catalog-barcode-scan')),
      findsOneWidget,
    );
  });
}

Finder _field(String label) => find.widgetWithText(TextField, label);

class _Gateway implements FoodInputCaptureGateway {
  _Gateway({this.text = '', this.barcode});
  final String text;
  final String? barcode;

  @override
  Future<String> recognizeJapaneseText(FoodCapturedImage image) async => text;

  @override
  Future<String?> scanBarcode(FoodCapturedImage image) async => barcode;

  @override
  Future<FoodCapturedImage?> selectImage(FoodImageSource source) async =>
      const FoodCapturedImage('data:image/png;base64,AA==');
}

class _LiveGateway implements FoodLiveCaptureGateway {
  _LiveGateway({this.barcode});

  final FoodBarcodeCandidate? barcode;
  int liveBarcodeCalls = 0;

  @override
  Future<FoodBarcodeCandidate?> scanBarcodeLive() async {
    liveBarcodeCalls += 1;
    return barcode;
  }

  @override
  Future<String?> recognizeNutritionLive(
    FoodNutritionLiveCandidate Function(String rawText) describeCandidate,
  ) async => null;

  @override
  Future<String> recognizeJapaneseText(FoodCapturedImage image) async => '';

  @override
  Future<String?> scanBarcode(FoodCapturedImage image) async => null;

  @override
  Future<FoodCapturedImage?> selectImage(FoodImageSource source) async => null;
}

class _Repository implements FoodCatalogRepository {
  final List<FoodCatalogEntry> entries = [];

  @override
  Future<void> archive(String foodId) async {}

  @override
  Future<void> create(FoodCatalogEntry entry) async => entries.add(entry);

  @override
  Future<List<FoodCatalogEntry>> list() async => List.unmodifiable(entries);

  @override
  Future<FoodCatalogEntry?> readById(String foodId) async => null;

  @override
  Future<void> update(FoodCatalogEntry entry) async {}
}
