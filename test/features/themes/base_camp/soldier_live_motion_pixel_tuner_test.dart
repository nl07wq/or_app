import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_motion.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_pixelation.dart';
import 'package:or_app/features/themes/base_camp/soldier_live_motion_preview_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
    BaseCampSoldierPixelCache.instance.resetForTesting();
    baseCampRifleGlobalAlignment.resetForTesting();
  });

  tearDown(BaseCampSoldierPixelCache.instance.resetForTesting);

  testWidgets(
    'live preview selects all pixel levels and applies level to regrip',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: SoldierLiveMotionPreviewPage()),
      );
      await tester.pump();

      for (
        var index = 0;
        index < SoldierPixelationLevel.values.length;
        index++
      ) {
        expect(find.text('PIXEL LV.$index'), findsOneWidget);
      }
      expect(_pixelControls(tester).selected, <SoldierPixelationLevel>{
        SoldierPixelationLevel.original,
      });

      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareRequests(
          baseCampSoldierPixelProfile().requests,
          SoldierPixelationLevel.coarse,
        ),
      );
      await tester.tap(find.text('PIXEL LV.3'));
      await tester.pump();
      expect(
        DeviceSettingsController.instance.value.soldierPixelationLevel,
        SoldierPixelationLevel.coarse,
      );
      expect(_pixelControls(tester).selected, <SoldierPixelationLevel>{
        SoldierPixelationLevel.coarse,
      });
      expect(
        _pixelatedImage(
          SoldierPixelationLevel.coarse,
          baseCampBreathingSoldierLowerAsset,
        ),
        findsOneWidget,
      );

      final trigger = find.byKey(const ValueKey('soldier-live-trigger-regrip'));
      tester.widget<OperationButton>(trigger).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1001));
      expect(find.text('PHASE: RIFLEREGRIP'), findsOneWidget);
      expect(
        _pixelatedImage(
          SoldierPixelationLevel.coarse,
          baseCampRifleRegripAssets.first,
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(home: SoldierLiveMotionPreviewPage()),
      );
      await tester.pump();
      expect(_pixelControls(tester).selected, <SoldierPixelationLevel>{
        SoldierPixelationLevel.coarse,
      });

      await tester.tap(find.text('PIXEL LV.0'));
      await tester.pump();
      expect(
        DeviceSettingsController.instance.value.soldierPixelationLevel,
        SoldierPixelationLevel.original,
      );
      expect(BaseCampSoldierPixelCache.instance.cachedImageCount, 0);
    },
  );

  test('pixel levels use increasingly coarse source block quantization', () {
    expect(
      SoldierPixelationLevel.values
          .map((level) => level.referenceBlockSize)
          .toList(growable: false),
      <int>[1, 6, 8, 9, 11],
    );
  });

  for (final width in <double>[320, 375, 390, 430]) {
    testWidgets('five pixel controls fit at ${width.toInt()}dp', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: SoldierLiveMotionPreviewPage()),
      );
      await tester.pump();
      for (var level = 0; level <= 4; level++) {
        expect(find.text('PIXEL LV.$level'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final level in SoldierPixelationLevel.values.skip(1)) {
    testWidgets('${level.controlLabel} remains active through TRIGGER REGRIP', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DeviceSettingsController.instance.resetForTesting(
        DeviceSettings(soldierPixelationLevel: level),
      );
      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareRequests(
          baseCampSoldierPixelProfile().requests,
          level,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: SoldierLiveMotionPreviewPage()),
      );
      await tester.pump();

      final trigger = find.byKey(const ValueKey('soldier-live-trigger-regrip'));
      tester.widget<OperationButton>(trigger).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1001));
      expect(
        _pixelatedImage(level, baseCampRifleRegripAssets.first),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

SegmentedButton<SoldierPixelationLevel> _pixelControls(WidgetTester tester) =>
    tester.widget<SegmentedButton<SoldierPixelationLevel>>(
      find.byKey(const ValueKey('soldier-live-pixel-level-controls')),
    );

Finder _pixelatedImage(SoldierPixelationLevel level, String asset) =>
    find.byKey(ValueKey<String>('soldier-pixelated-${level.name}-$asset'));
