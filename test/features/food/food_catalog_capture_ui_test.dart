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
