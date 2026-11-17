import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/themes/base_camp/base_camp_asset_metrics.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_motion.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_pixelation.dart';

void main() {
  setUp(() {
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
    BaseCampSoldierPixelCache.instance.resetForTesting();
  });

  tearDown(BaseCampSoldierPixelCache.instance.resetForTesting);

  test('all levels resolve to one screen-space block density', () {
    final profile = baseCampSoldierPixelProfile();
    final breathing = profile.requestFor(baseCampBreathingSoldierLowerAsset);
    for (final level in SoldierPixelationLevel.values.skip(1)) {
      final breathingSize = breathing.reducedSize(level);
      final breathingBlockX =
          baseCampAssetMetrics[breathing.asset]!.width / breathingSize.width;
      final breathingBlockY =
          baseCampAssetMetrics[breathing.asset]!.height / breathingSize.height;
      for (final asset in baseCampRifleRegripAssets) {
        final request = profile.requestFor(asset);
        final size = request.reducedSize(level);
        final metric = baseCampAssetMetrics[asset]!;
        final regripBlockX = metric.width * request.screenScaleX / size.width;
        final regripBlockY = metric.height * request.screenScaleY / size.height;
        expect(regripBlockX, closeTo(breathingBlockX, .08));
        expect(regripBlockY, closeTo(breathingBlockY, .08));
      }
      expect(
        breathingBlockX,
        closeTo(level.referenceBlockSize.toDouble(), .08),
      );
      expect(
        breathingBlockY,
        closeTo(level.referenceBlockSize.toDouble(), .08),
      );
    }
  });

  test('regrip sampling follows final alignment axis scales', () {
    final profile = baseCampSoldierPixelProfile(
      globalScale: 1.2,
      frameScales: const <double>[.8, .9, 1, 1.1, 1.2, 1.3],
      horizontalScaleY: .7,
      verticalScaleX: 1.25,
    );
    final breathing = profile.requestFor(baseCampBreathingSoldierLowerAsset);
    final breathingSize = breathing.reducedSize(SoldierPixelationLevel.extreme);
    final expectedX =
        baseCampAssetMetrics[breathing.asset]!.width / breathingSize.width;
    final expectedY =
        baseCampAssetMetrics[breathing.asset]!.height / breathingSize.height;
    for (final asset in baseCampRifleRegripAssets) {
      final request = profile.requestFor(asset);
      final size = request.reducedSize(SoldierPixelationLevel.extreme);
      final metric = baseCampAssetMetrics[asset]!;
      expect(
        metric.width * request.screenScaleX / size.width,
        closeTo(expectedX, .12),
      );
      expect(
        metric.height * request.screenScaleY / size.height,
        closeTo(expectedY, .12),
      );
    }
  });

  test('breathing layers share one source grid and profile origin', () {
    final profile = baseCampSoldierPixelProfile();
    final lower = profile.requestFor(baseCampBreathingSoldierLowerAsset);
    final upper = profile.requestFor(baseCampBreathingSoldierUpperAsset);
    expect(lower.profileKey, upper.profileKey);
    for (final level in SoldierPixelationLevel.values.skip(1)) {
      expect(lower.reducedSize(level), upper.reducedSize(level));
    }
  });

  testWidgets('failed profile is not partially committed', (tester) async {
    final profile = baseCampSoldierPixelProfile();
    final requests = <BaseCampSoldierPixelRequest>[
      ...profile.requests.take(2),
      BaseCampSoldierPixelRequest(
        asset: 'assets/missing_soldier_frame.png',
        profileKey: profile.key,
      ),
    ];
    final prepared = await tester.runAsync(
      () => BaseCampSoldierPixelCache.instance.prepareRequests(
        requests,
        SoldierPixelationLevel.fine,
      ),
    );
    expect(prepared, isFalse);
    expect(BaseCampSoldierPixelCache.instance.cachedImageCount, 0);
    expect(BaseCampSoldierPixelCache.instance.lastFailure, isNotNull);
  });

  testWidgets(
    'selected level pixelates breathing and regrip once then reuses cache',
    (tester) async {
      DeviceSettingsController.instance.update(
        const DeviceSettings(
          soldierPixelationLevel: SoldierPixelationLevel.fine,
        ),
      );
      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareRequests(
          baseCampSoldierPixelProfile().requests,
          SoldierPixelationLevel.fine,
        ),
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
        () => BaseCampSoldierPixelCache.instance.prepareRequests(
          baseCampSoldierPixelProfile().requests,
          SoldierPixelationLevel.medium,
        ),
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
      () => BaseCampSoldierPixelCache.instance.prepareRequests(
        baseCampSoldierPixelProfile().requests,
        SoldierPixelationLevel.coarse,
      ),
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
