import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/font_readiness_service.dart';
import 'package:or_app/core/theme/app_theme.dart';

void main() {
  test(
    'Japanese UI default selects M PLUS 1 Code without replacing specialty faces',
    () {
      expect(
        StandardTheme.theme.textTheme.bodyMedium?.fontFamily,
        FontReadinessService.fontFamily,
      );
      expect(FontReadinessService.fontFamily, 'MPlus1Code');
      expect(
        FontReadinessService.fontAsset,
        'assets/fonts/MPLUS1Code[wght].ttf',
      );
      expect(FontReadinessService.baseCampLatinFontFamily, 'PressStart2P');
      expect(FontReadinessService.baseCampJapaneseFontFamily, 'DotGothic16');
    },
  );

  testWidgets('configured application and BASE CAMP assets load once', (
    tester,
  ) async {
    for (final asset in <String>[
      FontReadinessService.fontAsset,
      FontReadinessService.baseCampLatinFontAsset,
      FontReadinessService.baseCampJapaneseFontAsset,
    ]) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(10000), reason: asset);
    }

    final first = FontReadinessService.instance.ensureReady();
    final duplicate = FontReadinessService.instance.ensureReady();
    expect(identical(first, duplicate), isTrue);
    await first;
    expect(FontReadinessService.instance.state, FontReadinessState.ready);
  });

  testWidgets('an explicit specialty face continues to override the default', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StandardTheme.theme,
        home: const Text(
          '93.6 kg',
          style: TextStyle(fontFamily: 'ShareTechMono'),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('93.6 kg')).style?.fontFamily,
      'ShareTechMono',
    );
  });

  test(
    'font readiness is single-flight and retry remains actionable',
    () async {
      var attempts = 0;
      final service = FontReadinessService.withLoaderForTesting(() async {
        attempts++;
        if (attempts == 1) {
          throw StateError('simulated bundled asset failure');
        }
      });

      final first = service.ensureReady();
      final duplicate = service.ensureReady();
      expect(identical(first, duplicate), isTrue);
      await first;
      expect(attempts, 1);
      expect(service.state, FontReadinessState.failed);
      expect(service.error, isA<StateError>());

      await service.retry();
      expect(attempts, 2);
      expect(service.state, FontReadinessState.ready);
      expect(service.error, isNull);
    },
  );
}
