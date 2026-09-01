import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/services/food_input_capture_gateway.dart';
import 'package:or_app/features/food/services/food_live_capture_presenter.dart';
import 'package:or_app/features/food/widgets/food_input_form.dart';

void main() {
  test('live presenter distinguishes no detection, partial, and complete', () {
    expect(describeNutritionCandidate('').state, 'scanning');
    expect(describeNutritionCandidate('栄養成分表示').state, 'insufficient');
    expect(describeNutritionCandidate('エネルギー 9.3kcal').state, 'partial');
    final candidate = describeNutritionCandidate(
      '1食（2.0g）あたり\nエネルギー 9.3kcal\n'
      'たんぱく質 0.65g\n脂質 0.51g\n炭水化物 0.54g',
    );
    expect(candidate.state, 'detected');
    expect(candidate.fields['CALORIES'], '9.3 kcal');
    expect(candidate.fields['PROTEIN'], '0.65 g');
    expect(candidate.fields['FAT'], '0.51 g');
    expect(candidate.fields['CARBOHYDRATE'], '0.54 g');
    expect(candidate.fields['BASIS'], '2 g');
  });

  test('live session retains latest parser-valid fields without averaging', () {
    final session = FoodNutritionCandidateSession();
    session.describe('100g当たり\nエネルギー 9.3kcal');
    session.describe('たんぱく質 0.65g');
    session.describe('たんぱく質 0.69g\n脂質 0.51g\n炭水化物 0.54g');

    expect(session.draft.basisQuantity, 100);
    expect(session.draft.calories, 9.3);
    expect(session.draft.protein, 0.69);
    expect(session.draft.fat, 0.51);
    expect(session.draft.carbohydrate, 0.54);
    expect(session.draft.protein, isNot(0.67));
    expect(session.lastRawText, contains('0.69g'));
    expect(session.candidateSources['CALORIES'], 'session');
    expect(session.candidateSources['PROTEIN'], 'parser');
  });

  test('real-label fields accumulate across live frames without inference', () {
    final session = FoodNutritionCandidateSession();
    session.describe('栄養成分表示：1袋38g当たり');
    session.describe('エ ネ ル ギ ー …… 201 kcal');
    session.describe('た ん ぱ く 質 …… 2.3 g');
    session.describe('脂 質 …… 12.4 g');
    final candidate = session.describe('炭 水 化 物 …… 21.5 g');

    expect(session.draft.basisQuantity, 38);
    expect(session.draft.calories, 201);
    expect(session.draft.protein, 2.3);
    expect(session.draft.fat, 12.4);
    expect(session.draft.carbohydrate, 21.5);
    expect(candidate.state, 'detected');
    expect(session.draft.protein, isNot(2.15));
  });

  test('structured anchor result has priority and preserves conflict', () {
    final session = FoodNutritionCandidateSession();
    session.describe('脂質 10.8g');
    final candidate = session.describe('[[OR_STRUCTURED_NUTRITION]]\n脂質 10.6g');
    session.describe('脂質 10.9g');

    expect(session.draft.fat, 10.6);
    expect(session.conflicts, contains('FAT'));
    expect(candidate.fields['REVIEW CONFLICT'], 'FAT');
    expect(session.candidateSources['FAT'], 'structured');
    expect(session.draft.fat, isNot(10.7));
  });

  test('matching structured and parser evidence does not conflict', () {
    final session = FoodNutritionCandidateSession();
    session.describe('熱量 345kcal\n脂質 10.6g');
    session.describe('[[OR_STRUCTURED_NUTRITION]]\nエネルギー 345kcal\n脂質 10.6g');

    expect(session.draft.calories, 345);
    expect(session.draft.fat, 10.6);
    expect(session.conflicts, isEmpty);
    expect(session.candidateSources['CALORIES'], 'structured');
    expect(session.candidateSources['FAT'], 'structured');
  });

  test('structured recovery decisions remain advisory and observable', () {
    final session = FoodNutritionCandidateSession();
    session.describe(
      '[[OR_STRUCTURED_NUTRITION]]\nエネルギー 188kcal\n'
      '[[OR_OCR_DECISIONS]]\n'
      '{"energy":{"value":188,"unit":"kcal","confidence":"HIGH",'
      '"source":"RECOVERED_OCR","reviewRequired":false,'
      '"conflict":false,"decision":"AUTO_FILL_ALLOWED"},'
      '"carbohydrate":{"value":null,"unit":null,'
      '"confidence":"MEDIUM","source":null,"reviewRequired":true,'
      '"conflict":true,"decision":"REVIEW_REQUIRED"}}',
    );

    expect(session.draft.calories, 188);
    expect(session.fieldDecisions['ENERGY']?['confidence'], 'HIGH');
    expect(
      session.fieldDecisions['CARBOHYDRATE']?['decision'],
      'REVIEW_REQUIRED',
    );
    expect(session.conflicts, contains('CARBOHYDRATE'));
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
    expect(find.text('SCAN NUTRITION LABEL'), findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('STANDARD OCR'));
    await tester.pumpAndSettle();

    expect(gateway.liveNutritionCalls, 1);
    expect(gateway.lastScanMode, FoodOcrScanMode.standard);
    expect(gateway.lastDescription?.state, 'detected');
    expect(find.text('REVIEW NUTRITION'), findsOneWidget);
    expect(find.text('SCAN MODE  STANDARD OCR'), findsOneWidget);
    expect(saveCalls, 0);
    await tester.tap(find.text('APPLY TO FORM'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_field('CALORIES')).controller!.text,
      '154',
    );
    expect(saveCalls, 0);
  });

  testWidgets('RESCAN retains the selected scan mode', (tester) async {
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
              onSave: (_) async => true,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const ValueKey('food-entry-ocr')));
    await tester.tap(find.byKey(const ValueKey('food-entry-ocr')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NUTRITION LABEL READER'));
    await tester.pumpAndSettle();
    expect(find.text('SCAN MODE  NUTRITION LABEL READER'), findsOneWidget);

    await tester.tap(find.text('RESCAN'));
    await tester.pumpAndSettle();

    expect(gateway.liveNutritionCalls, 2);
    expect(gateway.lastScanMode, FoodOcrScanMode.nutritionLabelReader);
    expect(find.text('SCAN MODE  NUTRITION LABEL READER'), findsOneWidget);
  });

  testWidgets('multi-pass nutrition fields merge without averaging', (
    tester,
  ) async {
    final gateway = _LiveGateway(
      nutritionRawText:
          '1個当たり\n脂質 10.6g\u001e'
          'エネルギー 201kcal\nたんぱく質 2.3g\n炭水化物 21.5g',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FoodInputForm(
              captureGateway: gateway,
              onSave: (_) async => true,
            ),
          ),
        ),
      ),
    );

    final action = find.byKey(const ValueKey('food-entry-ocr'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('STANDARD OCR'));
    await tester.pumpAndSettle();

    expect(gateway.lastScanMode, FoodOcrScanMode.standard);
    expect(find.text('NUTRITION BASIS  1 piece'), findsOneWidget);
    expect(find.text('CALORIES  201 kcal'), findsOneWidget);
    expect(find.text('PROTEIN  2.3 g'), findsOneWidget);
    expect(find.text('FAT  10.6 g'), findsOneWidget);
    expect(find.text('CARBOHYDRATE  21.5 g'), findsOneWidget);
  });

  testWidgets('photo review exposes structured OCR conflicts', (tester) async {
    final gateway = _LiveGateway(
      nutritionRawText:
          '脂質 10.8g\u001e'
          '[[OR_STRUCTURED_NUTRITION]]\n脂質 10.6g',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FoodInputForm(
              captureGateway: gateway,
              onSave: (_) async => true,
            ),
          ),
        ),
      ),
    );

    final action = find.byKey(const ValueKey('food-entry-ocr'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('STANDARD OCR'));
    await tester.pumpAndSettle();

    expect(find.text('FAT  10.6 g'), findsOneWidget);
    expect(find.text('REVIEW CONFLICT  FAT'), findsOneWidget);
  });

  testWidgets('Food Entry hides package OCR and opens nutrition directly', (
    tester,
  ) async {
    var saveCalls = 0;
    final gateway = _LiveGateway(
      nutritionRawText:
          'OR FOODS\nザクザクポテト\n明太子味\n内容量 70g\n'
          '東京都千代田区1-2-3',
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
    expect(find.text('PACKAGE'), findsNothing);
    expect(find.text('NUTRITION'), findsNothing);
    expect(find.text('SELECT SCAN MODE'), findsOneWidget);
    expect(find.text('STANDARD OCR'), findsOneWidget);
    expect(find.text('NUTRITION LABEL READER'), findsOneWidget);
    expect(find.text('PADDLE PoC'), findsNothing);
    expect(find.text('LIVE SCAN'), findsNothing);
    expect(tester.widget<TextField>(_field('NAME')).controller!.text, isEmpty);
    expect(saveCalls, 0);
  });

  for (final scanMode in [
    ('STANDARD OCR', FoodOcrScanMode.standard),
    ('NUTRITION LABEL READER', FoodOcrScanMode.nutritionLabelReader),
  ]) {
    testWidgets('${scanMode.$1} uses the same nutrition scanner contract', (
      tester,
    ) async {
      var saveCalls = 0;
      final gateway = _LiveGateway(nutritionRawText: _realLabelRawText);
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
      await tester.tap(find.text(scanMode.$1));
      await tester.pumpAndSettle();

      expect(gateway.lastScanMode, scanMode.$2);
      expect(find.text('SCAN MODE  ${scanMode.$1}'), findsOneWidget);
      expect(find.text('NUTRITION BASIS  38 g'), findsOneWidget);
      expect(find.text('CALORIES  201 kcal'), findsOneWidget);
      expect(find.text('PROTEIN  2.3 g'), findsOneWidget);
      expect(find.text('FAT  12.4 g'), findsOneWidget);
      expect(find.text('CARBOHYDRATE  21.5 g'), findsOneWidget);
      expect(saveCalls, 0);

      await tester.tap(find.text('APPLY TO FORM'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_field('NUTRITION BASIS')).controller!.text,
        '38',
      );
      expect(
        tester.widget<TextField>(_field('CALORIES')).controller!.text,
        '201',
      );
      expect(
        tester.widget<TextField>(_field('PROTEIN')).controller!.text,
        '2.3',
      );
      expect(tester.widget<TextField>(_field('FAT')).controller!.text, '12.4');
      expect(
        tester.widget<TextField>(_field('CARBOHYDRATE')).controller!.text,
        '21.5',
      );
      expect(saveCalls, 0);
    });
  }

  testWidgets('nutrition review never exposes package master fields', (
    tester,
  ) async {
    var saveCalls = 0;
    final gateway = _LiveGateway(
      nutritionRawText: '100g当たり\n熱量 154kcal\n脂質 5.5g',
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
    await tester.tap(find.text('STANDARD OCR'));
    await tester.pumpAndSettle();

    expect(find.text('REVIEW NUTRITION'), findsOneWidget);
    expect(find.textContaining('NAME CANDIDATES'), findsNothing);
    expect(find.textContaining('BRAND CANDIDATES'), findsNothing);
    expect(find.text('PACKAGE'), findsNothing);
    expect(tester.widget<TextField>(_field('NAME')).controller!.text, isEmpty);
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

  testWidgets('nutrition scanner and review do not overflow', (tester) async {
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
                captureGateway: _LiveGateway(
                  nutritionRawText:
                      '商品名：テスト食品\nブランド：OR FOODS\n内容量 170g\n'
                      '100g当たり\n熱量 154kcal\nたんぱく質 1.9g\n'
                      '脂質 5.5g\n炭水化物 24.2g',
                ),
                onSave: (_) async => true,
              ),
            ),
          ),
        ),
      );
      final action = find.byKey(const ValueKey('food-entry-ocr'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('SELECT SCAN MODE'), findsOneWidget);
      expect(find.text('STANDARD OCR'), findsOneWidget);
      expect(find.text('NUTRITION LABEL READER'), findsOneWidget);
      expect(find.text('PADDLE PoC'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'scanner width $width');
      await tester.tap(find.text('STANDARD OCR'));
      await tester.pumpAndSettle();
      expect(find.text('REVIEW NUTRITION'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'nutrition width $width');
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('structured conflict review does not overflow', (tester) async {
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
                captureGateway: _LiveGateway(
                  nutritionRawText:
                      '脂質 10.8g\u001e'
                      '[[OR_STRUCTURED_NUTRITION]]\n脂質 10.6g',
                ),
                onSave: (_) async => true,
              ),
            ),
          ),
        ),
      );
      final action = find.byKey(const ValueKey('food-entry-ocr'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.text('STANDARD OCR'));
      await tester.pumpAndSettle();
      expect(find.text('REVIEW CONFLICT  FAT'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'conflict width $width');
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'temporary OCR diagnostics compares one still image responsively',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0, 900.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        var saveCalls = 0;
        final gateway = _DiagnosticGateway();
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

        await tester.ensureVisible(
          find.byKey(const ValueKey('food-entry-ocr')),
        );
        await tester.tap(find.byKey(const ValueKey('food-entry-ocr')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('nutrition-ocr-diagnostics')),
          findsOne,
        );
        await tester.tap(
          find.byKey(const ValueKey('nutrition-ocr-diagnostics')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('PHOTO LIBRARY'));
        await tester.pumpAndSettle();

        expect(gateway.diagnosticCalls, 1);
        expect(gateway.selectedSources, [FoodImageSource.gallery]);
        expect(find.textContaining('OCR PIPELINE DIAGNOSTICS'), findsOneWidget);
        expect(find.byKey(const ValueKey('view-standard-ocr-input')), findsOne);
        expect(
          find.byKey(const ValueKey('view-nutrition-ocr-input')),
          findsOne,
        );
        expect(find.byKey(const ValueKey('copy-ocr-diagnostics')), findsOne);
        expect(saveCalls, 0);
        expect(
          tester.takeException(),
          isNull,
          reason: 'diagnostics width $width',
        );
        await tester.tap(find.byKey(const ValueKey('view-standard-ocr-input')));
        await tester.pumpAndSettle();
        expect(find.text('STANDARD OCR INPUT'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'CLOSE'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('view-nutrition-ocr-input')),
        );
        await tester.pumpAndSettle();
        expect(find.text('NUTRITION OCR INPUT'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'CLOSE'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'CLOSE'));
        await tester.pumpAndSettle();
      }
    },
  );

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
      find.byKey(const ValueKey('food-entry-ocr')),
      _field('NAME'),
      _field('BRAND'),
      find.byKey(const ValueKey('food-entry-category-preparedFood')),
      _field('BARCODE / JAN'),
      _field('PACKAGE QUANTITY'),
      _field('NUTRITION BASIS'),
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

const _realLabelRawText = '''
栄 養 成 分 表 示：1袋38g当たり
エ ネ ル ギ ー …… 201 kcal
た ん ぱ く 質 …… 2.3 g
脂 質 …… 12.4 g
炭 水 化 物 …… 21.5 g
－ 糖 質 …… 18.5 g
－ 食 物 繊 維 …… 3.0 g
食 塩 相 当 量 …… 0.4 g
''';

class _LiveGateway implements FoodLiveCaptureGateway {
  _LiveGateway({this.barcode, this.nutritionRawText});

  final FoodBarcodeCandidate? barcode;
  final String? nutritionRawText;
  int liveBarcodeCalls = 0;
  int liveNutritionCalls = 0;
  final selectedSources = <FoodImageSource>[];
  FoodOcrLiveCandidate? lastDescription;
  FoodTextOcrMode? lastOcrMode;
  FoodOcrScanMode? lastScanMode;

  @override
  Future<FoodBarcodeCandidate?> scanBarcodeLive() async {
    liveBarcodeCalls += 1;
    return barcode;
  }

  @override
  Future<String?> recognizeTextLive({
    required String title,
    required String instruction,
    required FoodOcrLiveCandidate Function(String rawText) describeCandidate,
    FoodOcrEngine engine = FoodOcrEngine.tesseract,
    FoodOcrScanMode scanMode = FoodOcrScanMode.nutritionLabelReader,
  }) async {
    liveNutritionCalls += 1;
    lastScanMode = scanMode;
    final rawText = nutritionRawText;
    if (rawText != null) lastDescription = describeCandidate(rawText);
    return rawText;
  }

  @override
  Future<String> recognizeJapaneseText(
    FoodCapturedImage image, {
    FoodTextOcrMode mode = FoodTextOcrMode.package,
    FoodOcrEngine engine = FoodOcrEngine.tesseract,
    FoodOcrScanMode scanMode = FoodOcrScanMode.nutritionLabelReader,
  }) async {
    lastOcrMode = mode;
    lastScanMode = scanMode;
    return nutritionRawText ?? '';
  }

  @override
  Future<String?> scanBarcode(FoodCapturedImage image) async => barcode?.value;

  @override
  Future<FoodCapturedImage?> selectImage(FoodImageSource source) async {
    selectedSources.add(source);
    return const FoodCapturedImage('data:image/png;base64,AA==');
  }
}

class _DiagnosticGateway extends _LiveGateway
    implements FoodOcrDiagnosticGateway {
  int diagnosticCalls = 0;

  @override
  Future<Map<String, dynamic>> diagnoseNutritionImage(
    FoodCapturedImage image, {
    required FoodImageSource source,
  }) async {
    diagnosticCalls += 1;
    final branch = <String, dynamic>{
      'scanMode': 'STANDARD OCR',
      'engineId': 'tesseract',
      'sourceDimensions': {'width': 1200, 'height': 800},
      'orientation': {'exif': 1, 'appliedByDecoder': true},
      'cropApplied': true,
      'cropRect': {'x': 48, 'y': 80, 'width': 1104, 'height': 640},
      'resizeApplied': false,
      'ocrDimensions': {'width': 1104, 'height': 640},
      'rotationCorrection': 'NOT REQUIRED',
      'perspectiveCorrection': 'NOT APPLIED',
      'inputPreviewDataUrl':
          'data:image/png;base64,'
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLZAAAAAElFTkSuQmCC',
      'passes': const [],
      'words': const [],
      'detectedLabels': const [],
      'numericCandidates': const [],
      'structuredCandidates': const [],
      'selectedMappings': const {},
      'parserDiagnostics': const [],
      'finalResult': const {},
      'formBinding': const {'status': 'NOT EXECUTED'},
      'summary': const {},
      'bottleneckClassification': 'UNKNOWN',
    };
    return {
      'diagnosticVersion': 1,
      'generatedAt': '2026-09-01T00:00:00Z',
      'sourceType': 'photoLibrary',
      'persistence': 'none',
      'standard': branch,
      'nutritionLabelReader': {...branch, 'scanMode': 'NUTRITION LABEL READER'},
      'comparison': const {'sameRawOcr': true},
      'rootCauseClassification': const {'primary': 'UNKNOWN'},
    };
  }
}
