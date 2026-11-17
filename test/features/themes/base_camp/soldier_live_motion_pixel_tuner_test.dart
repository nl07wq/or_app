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
        () => BaseCampSoldierPixelCache.instance.prepareAssets(<String>[
          baseCampBreathingSoldierLowerAsset,
          baseCampBreathingSoldierUpperAsset,
          ...baseCampRifleRegripAssets,
        ], SoldierPixelationLevel.coarse),
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
          .map((level) => level.sourceBlockSize)
          .toList(growable: false),
      <int>[1, 6, 12, 24],
    );
  });
}

SegmentedButton<SoldierPixelationLevel> _pixelControls(WidgetTester tester) =>
    tester.widget<SegmentedButton<SoldierPixelationLevel>>(
      find.byKey(const ValueKey('soldier-live-pixel-level-controls')),
    );

Finder _pixelatedImage(SoldierPixelationLevel level, String asset) =>
    find.byKey(ValueKey<String>('soldier-pixelated-${level.name}-$asset'));
