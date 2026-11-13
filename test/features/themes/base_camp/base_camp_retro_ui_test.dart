import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/widgets/history_data_vault_background.dart';
import 'package:or_app/features/body_history/widgets/history_feature_scaffold.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';
import 'package:or_app/features/food/widgets/food_feature_chrome.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_theme.dart';

void main() {
  test('bundled pixel font retains its SIL OFL license', () {
    final font = File('assets/fonts/PressStart2P-Regular.ttf');
    final license = File('assets/fonts/licenses/OFL-PressStart2P.txt');
    final japaneseFont = File('assets/fonts/DotGothic16-Regular.ttf');
    final japaneseLicense = File('assets/fonts/licenses/OFL-DotGothic16.txt');

    expect(font.existsSync(), isTrue);
    expect(font.lengthSync(), 118204);
    expect(license.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
    expect(license.readAsStringSync(), contains('Version 1.1'));
    expect(japaneseFont.existsSync(), isTrue);
    expect(japaneseFont.lengthSync(), 2069236);
    expect(
      japaneseLicense.readAsStringSync(),
      contains('SIL OPEN FONT LICENSE'),
    );
    expect(japaneseLicense.readAsStringSync(), contains('Version 1.1'));
  });

  testWidgets('BASE CAMP applies pixel typography with Japanese fallback', (
    tester,
  ) async {
    for (final screen in const <BaseCampScreen>[
      BaseCampScreen.morning,
      BaseCampScreen.activity,
      BaseCampScreen.food,
      BaseCampScreen.training,
      BaseCampScreen.commandCenter,
      BaseCampScreen.dataCenterHistory,
    ]) {
      ThemeData? observed;
      await tester.pumpWidget(
        MaterialApp(
          home: BaseCampScreenEntry(
            screen: screen,
            child: Builder(
              builder: (context) {
                observed = Theme.of(context);
                return const Scaffold(body: Text('COMMAND 作戦記録 123'));
              },
            ),
          ),
        ),
      );

      expect(
        observed!.textTheme.bodyMedium!.fontFamily,
        baseCampPixelFontFamily,
      );
      expect(
        observed!.textTheme.bodyMedium!.fontFamilyFallback,
        contains(baseCampJapaneseFontFallback),
      );
      expect(observed!.textTheme.bodyMedium!.fontWeight, FontWeight.w700);
      expect(tester.takeException(), isNull, reason: screen.name);
    }
  });

  testWidgets('DotGothic16 w700 produces heavier Japanese raster output', (
    tester,
  ) async {
    final fontBytes = File(
      'assets/fonts/DotGothic16-Regular.ttf',
    ).readAsBytesSync();
    final loader = FontLoader(baseCampJapaneseFontFallback)
      ..addFont(Future.value(ByteData.sublistView(fontBytes)));
    await loader.load();

    Future<Uint8List> raster(FontWeight weight) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
      final builder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                fontFamily: baseCampJapaneseFontFallback,
                fontSize: 32,
                fontWeight: weight,
                height: 1.2,
              ),
            )
            ..pushStyle(
              ui.TextStyle(
                color: Colors.black,
                fontFamily: baseCampJapaneseFontFallback,
                fontSize: 32,
                fontWeight: weight,
              ),
            )
            ..addText('作戦記録漢字');
      final paragraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 240));
      canvas.drawParagraph(paragraph, Offset.zero);
      final picture = recorder.endRecording();
      final image = await picture.toImage(240, 48);
      picture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }

    int inkCoverage(Uint8List bytes) {
      var coverage = 0;
      for (var index = 0; index < bytes.length; index += 4) {
        coverage += 255 - bytes[index];
      }
      return coverage;
    }

    final rasters = await tester.runAsync(
      () async => (
        regular: await raster(FontWeight.w400),
        bold: await raster(FontWeight.w700),
      ),
    );
    final regularCoverage = inkCoverage(rasters!.regular);
    final boldCoverage = inkCoverage(rasters.bold);
    expect(boldCoverage, greaterThan(regularCoverage));
  });

  testWidgets('STANDARD typography is not replaced', (tester) async {
    ThemeData? observed;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'MPlus1Code'),
        home: Builder(
          builder: (context) {
            observed = Theme.of(context);
            return const Scaffold(body: Text('STANDARD'));
          },
        ),
      ),
    );

    expect(observed!.textTheme.bodyMedium!.fontFamily, isNot('PressStart2P'));
  });

  testWidgets('FOOD ambient is removed only from BASE CAMP lower pages', (
    tester,
  ) async {
    Widget page() => FoodFeatureScaffold(
      appBar: AppBar(title: const Text('FOOD RECORD')),
      body: const SizedBox.expand(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampScreenEntry(screen: BaseCampScreen.food, child: page()),
      ),
    );
    expect(find.byType(FoodAmbientComparison), findsNothing);

    await tester.pumpWidget(MaterialApp(home: page()));
    await tester.pump();
    expect(find.byType(FoodAmbientComparison), findsOneWidget);
  });

  testWidgets('history ambient ticker is absent only from BASE CAMP', (
    tester,
  ) async {
    HistoryFeatureScaffold.debugDisableAmbientAnimation = true;
    addTearDown(
      () => HistoryFeatureScaffold.debugDisableAmbientAnimation = false,
    );
    const page = HistoryFeatureScaffold(
      title: 'ACTIVITY HISTORY',
      body: SizedBox.expand(),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: BaseCampScreenEntry(
          screen: BaseCampScreen.commandCenter,
          child: page,
        ),
      ),
    );
    expect(find.byType(HistoryDataVaultBackground), findsNothing);
    expect(find.text('ACTIVITY HISTORY'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: page));
    expect(find.byType(HistoryDataVaultBackground), findsOneWidget);
  });
}
