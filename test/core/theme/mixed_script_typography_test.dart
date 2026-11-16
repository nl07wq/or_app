import 'dart:io';
import 'dart:math' as math;
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
    await _loadFont('MPlus1Code', 'assets/fonts/MPLUS1Code-wght.ttf');
  });

  test('mixed-script rule splits only Japanese plus Latin content', () {
    expect(MixedScriptTypography.isMixed('SLEEP TIME 3時間42分'), isTrue);
    expect(MixedScriptTypography.isMixed('FOOT PAIN LV.2 /10'), isFalse);
    expect(MixedScriptTypography.isMixed('2,750mL'), isFalse);
    expect(MixedScriptTypography.isMixed('日本語の本文'), isFalse);

    const base = TextStyle(
      fontFamily: 'PressStart2P',
      fontFamilyFallback: ['DotGothic16'],
      color: Colors.black,
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
    expect(latin.color, Colors.transparent);
    expect(latin.shadows, hasLength(1));
    expect(MixedScriptTypography.baseCampLatinBaselineOffset, 1.5);
    expect(
      latin.shadows!.single.offset,
      const Offset(0, MixedScriptTypography.baseCampLatinBaselineOffset),
    );
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

  test('V1.2 moves existing shadows with the zero-blur Latin proxy', () {
    const style = TextStyle(
      color: Colors.black,
      fontFamily: 'PressStart2P',
      fontSize: 20,
      shadows: <Shadow>[
        Shadow(color: Colors.green, offset: Offset(2, 3), blurRadius: 4),
      ],
    );
    final latin = MixedScriptTypography.spans('睡眠4:19', style).last.style!;
    expect(latin.shadows, hasLength(2));
    expect(latin.shadows!.first.offset, const Offset(2, 4.5));
    expect(latin.shadows!.first.blurRadius, 4);
    expect(latin.shadows!.last.offset, const Offset(0, 1.5));
    expect(latin.shadows!.last.blurRadius, 0);
  });

  testWidgets('V1.2 moves Latin ink .5dp below V1.1 and 1.5dp below V1', (
    tester,
  ) async {
    for (final sample in const <String>[
      '睡眠時間：4:19',
      '睡眠スコア：66',
      '足底筋膜炎：LV.3',
      '勤務：7:00〜18:00',
      '睡眠4:19と睡眠スコア66',
    ]) {
      final v1 = await tester.runAsync(() => _rasterMixedValue(sample));
      final v11 = await tester.runAsync(
        () => _rasterMixedValue(sample, baselineOffset: 1),
      );
      final v12 = await tester.runAsync(
        () => _rasterMixedValue(
          sample,
          baselineOffset: MixedScriptTypography.baseCampLatinBaselineOffset,
        ),
      );

      expect(
        v12!.latin.centerY - v11!.latin.centerY,
        closeTo(.5, .06),
        reason: sample,
      );
      expect(
        v12.latin.centerY - v1!.latin.centerY,
        closeTo(1.5, .06),
        reason: sample,
      );
      expect(v12.latin.left, v11.latin.left, reason: sample);
      expect(v12.latin.right, v11.latin.right, reason: sample);
      expect(v12.japanese.top, v11.japanese.top, reason: sample);
      expect(v12.japanese.bottom, v11.japanese.bottom, reason: sample);
      expect(v12.japanese.centerY, v11.japanese.centerY, reason: sample);
      expect(v12.baseline, closeTo(v11.baseline, .01), reason: sample);
      expect(v12.baseline, closeTo(v1.baseline, .01), reason: sample);
    }
  });

  testWidgets(
    'representative mixed text wraps without overflow at mobile widths',
    (tester) async {
      const samples = <String>[
        '睡眠時間：4:19',
        '睡眠スコア：66',
        '足底筋膜炎：LV.3',
        '勤務：7:00〜18:00',
        '睡眠4:19と睡眠スコア66',
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

  test('V1.2 preserves V1 paragraph metrics at mobile widths', () {
    const style = TextStyle(
      color: Colors.black,
      fontFamily: 'PressStart2P',
      fontFamilyFallback: ['DotGothic16'],
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.55,
    );
    const samples = <String>[
      '睡眠時間：4:19',
      '睡眠スコア：66',
      '足底筋膜炎：LV.3',
      '勤務：7:00〜18:00',
      '睡眠4:19と睡眠スコア66',
    ];
    for (final width in const [288.0, 343.0, 358.0]) {
      for (final sample in samples) {
        final v12Spans = MixedScriptTypography.spans(sample, style);
        final v1Spans = <TextSpan>[
          for (final span in v12Spans)
            TextSpan(
              text: span.text,
              style: span.style!.fontFamily == MixedScriptTypography.latinFamily
                  ? span.style!.copyWith(
                      color: style.color,
                      shadows: const <Shadow>[],
                    )
                  : span.style,
            ),
        ];
        final v1 = _layoutSpans(v1Spans, style, width);
        final v12 = _layoutSpans(v12Spans, style, width);
        expect(v12.size, v1.size, reason: '$width: $sample');
        expect(v12.didExceedMaxLines, isFalse, reason: '$width: $sample');
        final v1Lines = v1.computeLineMetrics();
        final v12Lines = v12.computeLineMetrics();
        expect(v12Lines.length, v1Lines.length, reason: '$width: $sample');
        for (var index = 0; index < v1Lines.length; index++) {
          expect(
            v12Lines[index].baseline,
            closeTo(v1Lines[index].baseline, .001),
            reason: '$width: $sample line $index',
          );
          expect(
            v12Lines[index].height,
            closeTo(v1Lines[index].height, .001),
            reason: '$width: $sample line $index',
          );
        }
      }
    }
  });

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

TextPainter _layoutSpans(List<TextSpan> spans, TextStyle style, double width) =>
    TextPainter(
      text: TextSpan(children: spans),
      strutStyle: MixedScriptTypography.strut(style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);

Future<_RasterBounds> _rasterMixedValue(
  String value, {
  double baselineOffset = 0,
}) async {
  const width = 360.0;
  const height = 100;
  const pixelRatio = 4.0;
  const style = TextStyle(
    color: Color(0xffff0000),
    fontFamily: 'PressStart2P',
    fontFamilyFallback: ['DotGothic16'],
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.5,
  );
  final spans = <TextSpan>[
    for (final span in MixedScriptTypography.spans(value, style))
      TextSpan(
        text: span.text,
        style: span.style!.fontFamily == MixedScriptTypography.japaneseFamily
            ? span.style!.copyWith(color: const Color(0xff0000ff))
            : baselineOffset == 0
            ? span.style!.copyWith(
                color: const Color(0xffff0000),
                shadows: const <Shadow>[],
              )
            : span.style!.copyWith(
                color: Colors.transparent,
                shadows: <Shadow>[
                  Shadow(
                    color: const Color(0xffff0000),
                    offset: Offset(0, baselineOffset),
                  ),
                ],
              ),
      ),
  ];
  final painter = _layoutSpans(spans, style, width);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xffffffff), ui.BlendMode.src)
    ..scale(pixelRatio);
  painter.paint(canvas, ui.Offset.zero);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (width * pixelRatio).toInt(),
    (height * pixelRatio).toInt(),
  );
  final bounds = await _readRasterBounds(
    image,
    width: (width * pixelRatio).toInt(),
    height: (height * pixelRatio).toInt(),
    baseline: painter.computeLineMetrics().first.baseline,
    pixelRatio: pixelRatio,
  );
  image.dispose();
  picture.dispose();
  return bounds;
}

Future<_RasterBounds> _rasterBounds({
  required double latinScale,
  required double latinLetterSpacing,
  double latinBaselineOffset = 0,
}) async {
  const width = 360.0;
  const height = 80;
  const fontSize = 28.0;
  final builder =
      ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: fontSize, height: 1.5))
        ..pushStyle(
          ui.TextStyle(
            color: latinBaselineOffset == 0
                ? const ui.Color(0xffff0000)
                : const ui.Color(0x00000000),
            fontFamily: 'PressStart2P',
            fontSize: fontSize * latinScale,
            fontWeight: ui.FontWeight.w700,
            height: 1,
            letterSpacing: latinLetterSpacing,
            shadows: latinBaselineOffset == 0
                ? null
                : <ui.Shadow>[
                    ui.Shadow(
                      color: const ui.Color(0xffff0000),
                      offset: ui.Offset(0, latinBaselineOffset),
                    ),
                  ],
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
  final bounds = await _readRasterBounds(
    image,
    width: width.toInt(),
    height: height,
    baseline: paragraph.computeLineMetrics().single.baseline,
  );
  image.dispose();
  picture.dispose();

  return bounds;
}

Future<_RasterBounds> _readRasterBounds(
  ui.Image image, {
  required int width,
  required int height,
  required double baseline,
  double pixelRatio = 1,
}) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();

  final latin = _InkBounds(pixelRatio: pixelRatio);
  final japanese = _InkBounds(pixelRatio: pixelRatio);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      final red = bytes[offset];
      final green = bytes[offset + 1];
      final blue = bytes[offset + 2];
      if (red > blue + 20 && red > green + 20) {
        latin.include(x, y, (red - math.max(green, blue)) / 255);
      }
      if (blue > red + 20 && blue > green + 20) {
        japanese.include(x, y, (blue - math.max(red, green)) / 255);
      }
    }
  }
  return _RasterBounds(latin: latin, japanese: japanese, baseline: baseline);
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
  _InkBounds({this.pixelRatio = 1});

  final double pixelRatio;
  int left = 1 << 30;
  int top = 1 << 30;
  int right = -1;
  int bottom = -1;
  double _mass = 0;
  double _weightedY = 0;

  int get height => bottom - top + 1;
  double get centerY => _weightedY / _mass / pixelRatio;

  void include(int x, int y, [double weight = 1]) {
    if (x < left) left = x;
    if (x > right) right = x;
    if (y < top) top = y;
    if (y > bottom) bottom = y;
    _mass += weight;
    _weightedY += y * weight;
  }
}
