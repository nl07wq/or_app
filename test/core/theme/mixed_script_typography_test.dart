import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/mixed_script_text.dart';
import 'package:or_app/core/widgets/operation_text_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont('PressStart2P', 'assets/fonts/PressStart2P-Regular.ttf');
    await _loadFont('DotGothic16', 'assets/fonts/DotGothic16-Regular.ttf');
    await _loadFont('MPlus1Code', 'assets/fonts/MPLUS1Code[wght].ttf');
  });

  test('mixed-script rule splits only Japanese plus Latin content', () {
    expect(MixedScriptTypography.isMixed('SLEEP TIME 3時間42分'), isTrue);
    expect(MixedScriptTypography.isMixed('FOOT PAIN LV.2 /10'), isFalse);
    expect(MixedScriptTypography.isMixed('2,750mL'), isFalse);
    expect(MixedScriptTypography.isMixed('日本語の本文'), isFalse);

    const base = TextStyle(
      fontFamily: 'PressStart2P',
      fontFamilyFallback: ['DotGothic16'],
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.5,
    );
    final spans = MixedScriptTypography.spans('START 12:00 終了', base);
    final latin = spans.first.style!;
    final japanese = spans.last.style!;
    expect(latin.fontFamily, 'PressStart2P');
    expect(latin.fontSize, 18);
    expect(latin.letterSpacing, closeTo(-.4, .001));
    expect(latin.height, 1);
    expect(japanese.fontFamily, 'DotGothic16');
    expect(japanese.fontSize, 20);
    expect(japanese.height, 1);
    expect(MixedScriptTypography.strut(base).fontFamily, 'DotGothic16');
    expect(MixedScriptTypography.strut(base).forceStrutHeight, isTrue);
  });

  testWidgets('BASE CAMP correction improves measured glyph-top alignment', (
    tester,
  ) async {
    final before = await tester.runAsync(
      () => _rasterBounds(latinScale: 1, latinLetterSpacing: 0),
    );
    final after = await tester.runAsync(
      () => _rasterBounds(
        latinScale: MixedScriptTypography.baseCampLatinScale,
        latinLetterSpacing:
            28 * MixedScriptTypography.baseCampLatinLetterSpacingEm,
      ),
    );

    expect((before!.latin.top - before.japanese.top).abs(), 4);
    expect((after!.latin.top - after.japanese.top).abs(), lessThanOrEqualTo(1));
    expect(
      (after.latin.height - after.japanese.height).abs(),
      lessThanOrEqualTo(4),
    );
    expect(after.baseline, closeTo(before.baseline, .01));
  });

  testWidgets(
    'representative mixed text wraps without overflow at mobile widths',
    (tester) async {
      const samples = <String>[
        'SLEEP TIME 3時間42分',
        'START / END 12:00 / 18:00',
        '7:00〜9:00',
        '作戦BRIEFは07:00に開始し、12kmの行動後にREPORTを更新します。',
      ];
      for (final width in const [320.0, 375.0, 390.0]) {
        for (final sample in samples) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                textTheme: const TextTheme(
                  bodyMedium: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontFamilyFallback: ['DotGothic16'],
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.55,
                  ),
                ),
              ),
              home: Scaffold(
                body: SizedBox(
                  width: width,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: MixedScriptText(sample),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$width: $sample');
          final rendered = tester.widget<Text>(find.byType(Text));
          if (MixedScriptTypography.isMixed(sample)) {
            expect(rendered.textSpan, isA<TextSpan>());
            expect(rendered.strutStyle?.fontFamily, 'DotGothic16');
          }
          expect(
            tester.getSize(find.byType(Text)).width,
            lessThanOrEqualTo(width - 32),
          );
        }
      }
    },
  );

  testWidgets('STANDARD M PLUS mixed text keeps its original Text path', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'MPlus1Code'),
        home: const Scaffold(body: MixedScriptText('SLEEP TIME 3時間42分')),
      ),
    );
    final rendered = tester.widget<Text>(find.byType(Text));
    expect(rendered.data, 'SLEEP TIME 3時間42分');
    expect(rendered.textSpan, isNull);
  });

  testWidgets(
    'corrected spans keep semantics and SelectionArea participation',
    (tester) async {
      const value = '日本語BRIEFと06:30の行動REPORT';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            textTheme: const TextTheme(
              bodyMedium: TextStyle(
                fontFamily: 'PressStart2P',
                fontFamilyFallback: ['DotGothic16'],
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ),
          home: const Scaffold(
            body: SelectionArea(child: MixedScriptText(value)),
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan!.toPlainText(), value);
      final paragraph = tester.widget<RichText>(find.byType(RichText));
      expect(paragraph.selectionRegistrar, isNotNull);
      expect(find.text(value), findsOneWidget);
    },
  );

  testWidgets('form labels opt in only for BASE CAMP mixed strings', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    const label = 'START 07:00 開始';

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('base-camp-form'),
        theme: ThemeData(
          textTheme: const TextTheme(
            bodyMedium: TextStyle(
              fontFamily: 'PressStart2P',
              fontFamilyFallback: ['DotGothic16'],
              fontSize: 14,
            ),
          ),
        ),
        home: Scaffold(
          body: OperationTextField(controller: controller, label: label),
        ),
      ),
    );
    var field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.labelText, isNull);
    expect(field.decoration!.label, isA<MixedScriptText>());

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('standard-form'),
        theme: ThemeData(
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontFamily: 'MPlus1Code', fontSize: 14),
          ),
        ),
        home: Scaffold(
          body: OperationTextField(controller: controller, label: label),
        ),
      ),
    );
    field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.labelText, label);
    expect(field.decoration!.label, isNull);
  });
}

Future<void> _loadFont(String family, String asset) async {
  final bytes = File(asset).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<_RasterBounds> _rasterBounds({
  required double latinScale,
  required double latinLetterSpacing,
}) async {
  const width = 360.0;
  const height = 80;
  const fontSize = 28.0;
  final builder =
      ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: fontSize, height: 1.5))
        ..pushStyle(
          ui.TextStyle(
            color: const ui.Color(0xffff0000),
            fontFamily: 'PressStart2P',
            fontSize: fontSize * latinScale,
            fontWeight: ui.FontWeight.w700,
            height: 1,
            letterSpacing: latinLetterSpacing,
          ),
        )
        ..addText('SLEEP3')
        ..pop()
        ..pushStyle(
          ui.TextStyle(
            color: const ui.Color(0xff0000ff),
            fontFamily: 'DotGothic16',
            fontSize: fontSize,
            fontWeight: ui.FontWeight.w700,
          ),
        )
        ..addText('時間42分');
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: width));
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xffffffff), ui.BlendMode.src)
    ..drawParagraph(paragraph, ui.Offset.zero);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  image.dispose();
  picture.dispose();

  final latin = _InkBounds();
  final japanese = _InkBounds();
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width.toInt() + x) * 4;
      final red = bytes[offset];
      final green = bytes[offset + 1];
      final blue = bytes[offset + 2];
      if (red > blue + 20 && red > green + 20) latin.include(x, y);
      if (blue > red + 20 && blue > green + 20) japanese.include(x, y);
    }
  }
  return _RasterBounds(
    latin: latin,
    japanese: japanese,
    baseline: paragraph.computeLineMetrics().single.baseline,
  );
}

class _RasterBounds {
  const _RasterBounds({
    required this.latin,
    required this.japanese,
    required this.baseline,
  });

  final _InkBounds latin;
  final _InkBounds japanese;
  final double baseline;
}

class _InkBounds {
  int left = 1 << 30;
  int top = 1 << 30;
  int right = -1;
  int bottom = -1;

  int get height => bottom - top + 1;

  void include(int x, int y) {
    if (x < left) left = x;
    if (x > right) right = x;
    if (y < top) top = y;
    if (y > bottom) bottom = y;
  }
}
