import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_motion.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_pixelation.dart';

void main() {
  setUp(() {
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
    BaseCampSoldierPixelCache.instance.resetForTesting();
  });

  tearDown(BaseCampSoldierPixelCache.instance.resetForTesting);

  testWidgets(
    'selected level pixelates breathing and regrip once then reuses cache',
    (tester) async {
      DeviceSettingsController.instance.update(
        const DeviceSettings(
          soldierPixelationLevel: SoldierPixelationLevel.fine,
        ),
      );
      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareAssets(const <String>[
          baseCampBreathingSoldierLowerAsset,
          baseCampBreathingSoldierUpperAsset,
          ...baseCampRifleRegripAssets,
        ], SoldierPixelationLevel.fine),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 512,
              height: 512,
              child: Stack(
                children: <Widget>[
                  BaseCampBreathingSoldier(dy: 0),
                  BaseCampRifleRegripFrame(frame: 0),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => _pixelatedImage(
          SoldierPixelationLevel.fine,
          baseCampRifleRegripAssets.first,
        ).evaluate().isNotEmpty,
      );

      expect(
        _pixelatedImage(
          SoldierPixelationLevel.fine,
          baseCampBreathingSoldierLowerAsset,
        ),
        findsOneWidget,
      );
      expect(
        _pixelatedImage(
          SoldierPixelationLevel.fine,
          baseCampBreathingSoldierUpperAsset,
        ),
        findsOneWidget,
      );
      expect(BaseCampSoldierPixelCache.instance.cachedImageCount, 8);
      expect(BaseCampSoldierPixelCache.instance.processedImageCount, 8);

      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 140));
      }
      expect(BaseCampSoldierPixelCache.instance.processedImageCount, 8);

      DeviceSettingsController.instance.update(
        const DeviceSettings(
          soldierPixelationLevel: SoldierPixelationLevel.medium,
        ),
      );
      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareAssets(const <String>[
          baseCampBreathingSoldierLowerAsset,
          baseCampBreathingSoldierUpperAsset,
          ...baseCampRifleRegripAssets,
        ], SoldierPixelationLevel.medium),
      );
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => BaseCampSoldierPixelCache.instance.processedImageCount == 16,
      );
      expect(BaseCampSoldierPixelCache.instance.cachedImageCount, 8);
      expect(
        _pixelatedImage(
          SoldierPixelationLevel.medium,
          baseCampRifleRegripAssets.first,
        ),
        findsOneWidget,
      );

      DeviceSettingsController.instance.update(const DeviceSettings());
      await tester.pump();
      await tester.pump();
      expect(
        _pixelatedImage(
          SoldierPixelationLevel.medium,
          baseCampRifleRegripAssets.first,
        ),
        findsNothing,
      );
      expect(BaseCampSoldierPixelCache.instance.cachedImageCount, 0);
      expect(find.byType(Image), findsNWidgets(3));
    },
  );

  testWidgets('pixelation preserves the original full-canvas dimensions', (
    tester,
  ) async {
    DeviceSettingsController.instance.update(
      const DeviceSettings(
        soldierPixelationLevel: SoldierPixelationLevel.coarse,
      ),
    );
    await tester.runAsync(
      () => BaseCampSoldierPixelCache.instance.prepareAssets(<String>[
        baseCampRifleRegripAssets.first,
      ], SoldierPixelationLevel.coarse),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.square(
          dimension: 256,
          child: BaseCampRifleRegripFrame(frame: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pumpUntil(
      tester,
      () => _pixelatedImage(
        SoldierPixelationLevel.coarse,
        baseCampRifleRegripAssets.first,
      ).evaluate().isNotEmpty,
    );
    final rendered = tester.widget<RawImage>(
      _pixelatedImage(
        SoldierPixelationLevel.coarse,
        baseCampRifleRegripAssets.first,
      ),
    );
    expect(rendered.image!.width, 512);
    expect(rendered.image!.height, 512);
    expect(rendered.filterQuality, FilterQuality.none);
  });
}

Finder _pixelatedImage(SoldierPixelationLevel level, String asset) =>
    find.byKey(ValueKey<String>('soldier-pixelated-${level.name}-$asset'));

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}
