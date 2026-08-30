import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/services/food_input_capture_gateway.dart';
import 'package:or_app/features/food/services/food_live_capture_presenter.dart';
import 'package:or_app/features/food/widgets/food_input_form.dart';

void main() {
  test('live presenter distinguishes no detection, partial, and complete', () {
    expect(describeNutritionCandidate('').state, 'scanning');
    expect(describeNutritionCandidate('エネルギー 9.3kcal').state, 'partial');
    final candidate = describeNutritionCandidate(
      '1食（2.0g）あたり\nエネルギー 9.3kcal\n'
      'たんぱく質 0.65g\n脂質 0.51g\n炭水化物 0.54g',
    );
    expect(candidate.state, 'detected');
    expect(candidate.calories, '9.3 kcal');
    expect(candidate.protein, '0.65 g');
    expect(candidate.fat, '0.51 g');
    expect(candidate.carbohydrate, '0.54 g');
    expect(candidate.basis, '2 g');
  });

  testWidgets(
    'Food Entry exposes live barcode scan and applies only its result',
    (tester) async {
      var saveCalls = 0;
      final gateway = _LiveGateway(
        barcode: const FoodBarcodeCandidate(
          value: '4006381333931',
          format: 'EAN-13',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(
                captureGateway: gateway,
                onSave: (data) async {
                  saveCalls += 1;
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      final action = find.byKey(const ValueKey('food-entry-barcode-scan'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(gateway.liveBarcodeCalls, 1);
      expect(
        tester.widget<TextField>(_field('BARCODE / JAN')).controller!.text,
        '4006381333931',
      );
      expect(saveCalls, 0);
    },
  );

  testWidgets('Food Entry live barcode cancel preserves manual draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FoodInputForm(
              captureGateway: _LiveGateway(),
              onSave: (_) async => true,
            ),
          ),
        ),
      ),
    );
    final field = _field('BARCODE / JAN');
    await tester.ensureVisible(field);
    await tester.enterText(field, '4901234567894');
    final action = find.byKey(const ValueKey('food-entry-barcode-scan'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).controller!.text, '4901234567894');
  });

  testWidgets('live nutrition result reuses preview and apply boundary', (
    tester,
  ) async {
    var saveCalls = 0;
    final gateway = _LiveGateway(
      nutritionRawText:
          '100g当たり\n熱量 154kcal\nたんぱく質 1.9g\n'
          '脂質 5.5g\n炭水化物 24.2g',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FoodInputForm(
              captureGateway: gateway,
              onSave: (_) async {
                saveCalls += 1;
                return true;
              },
            ),
          ),
        ),
      ),
    );
    final action = find.byKey(const ValueKey('food-entry-ocr'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('LIVE SCAN'));
    await tester.pumpAndSettle();

    expect(gateway.liveNutritionCalls, 1);
    expect(gateway.lastDescription?.state, 'detected');
    expect(find.text('OCR PREVIEW'), findsOneWidget);
    expect(saveCalls, 0);
    await tester.tap(find.text('APPLY TO FORM'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_field('CALORIES')).controller!.text,
      '154',
    );
    expect(saveCalls, 0);
  });

  testWidgets('capture actions do not overflow at supported widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodInputForm(
                captureGateway: _LiveGateway(),
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

  testWidgets('Food Entry keeps aligned master fields before daily amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FoodInputForm(
              captureGateway: _LiveGateway(),
              onSave: (_) async => true,
            ),
          ),
        ),
      ),
    );

    final ordered = [
      _field('NAME'),
      _field('BRAND'),
      find.byKey(const ValueKey('food-entry-category-preparedFood')),
      _field('BARCODE / JAN'),
      _field('PACKAGE QUANTITY'),
      _field('NUTRITION BASIS'),
      find.byKey(const ValueKey('food-entry-ocr')),
      _field('CALORIES'),
      _field('FAT'),
      _field('MEMO'),
      _field('AMOUNT'),
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
      find.byKey(const ValueKey('food-entry-barcode-scan')),
      findsOneWidget,
    );
  });
}

Finder _field(String label) => find.widgetWithText(TextField, label);

class _LiveGateway implements FoodLiveCaptureGateway {
  _LiveGateway({this.barcode, this.nutritionRawText});

  final FoodBarcodeCandidate? barcode;
  final String? nutritionRawText;
  int liveBarcodeCalls = 0;
  int liveNutritionCalls = 0;
  FoodNutritionLiveCandidate? lastDescription;

  @override
  Future<FoodBarcodeCandidate?> scanBarcodeLive() async {
    liveBarcodeCalls += 1;
    return barcode;
  }

  @override
  Future<String?> recognizeNutritionLive(
    FoodNutritionLiveCandidate Function(String rawText) describeCandidate,
  ) async {
    liveNutritionCalls += 1;
    final rawText = nutritionRawText;
    if (rawText != null) lastDescription = describeCandidate(rawText);
    return rawText;
  }

  @override
  Future<String> recognizeJapaneseText(FoodCapturedImage image) async =>
      nutritionRawText ?? '';

  @override
  Future<String?> scanBarcode(FoodCapturedImage image) async => barcode?.value;

  @override
  Future<FoodCapturedImage?> selectImage(FoodImageSource source) async =>
      const FoodCapturedImage('data:image/png;base64,AA==');
}
