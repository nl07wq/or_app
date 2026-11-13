import 'dart:io';

import 'package:flutter/material.dart';
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
      expect(tester.takeException(), isNull, reason: screen.name);
    }
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
