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
    'live preview selects and persists independent motion pixel levels',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: SoldierLiveMotionPreviewPage()),
      );
      await tester.pump();

      expect(find.text('BREATHING PIXEL'), findsOneWidget);
      expect(find.text('REGRIP PIXEL'), findsOneWidget);
      for (
        var index = 0;
        index < SoldierPixelationLevel.values.length;
        index++
      ) {
        expect(find.text('LV.$index'), findsNWidgets(2));
      }
      expect(
        _pixelControls(tester, BaseCampSoldierMotion.breathing).selected,
        <SoldierPixelationLevel>{SoldierPixelationLevel.original},
      );
      expect(
        _pixelControls(tester, BaseCampSoldierMotion.regrip).selected,
        <SoldierPixelationLevel>{SoldierPixelationLevel.original},
      );

      await _preparePreviewMotionProfile(
        tester,
        BaseCampSoldierMotion.breathing,
        SoldierPixelationLevel.coarse,
      );
      await tester.tap(
        _pixelLevelButton(BaseCampSoldierMotion.breathing, 'LV.3'),
      );
      await tester.pump();
      expect(
        DeviceSettingsController.instance.value.breathingPixelLevel,
        SoldierPixelationLevel.coarse,
      );
      expect(
        DeviceSettingsController.instance.value.regripPixelLevel,
        SoldierPixelationLevel.original,
      );
      expect(
        _pixelControls(tester, BaseCampSoldierMotion.breathing).selected,
        <SoldierPixelationLevel>{SoldierPixelationLevel.coarse},
      );
      await _pumpUntil(
        tester,
        () => _pixelatedImage(
          SoldierPixelationLevel.coarse,
          baseCampBreathingSoldierLowerAsset,
        ).evaluate().isNotEmpty,
      );

      await _preparePreviewMotionProfile(
        tester,
        BaseCampSoldierMotion.regrip,
        SoldierPixelationLevel.fine,
      );
      await tester.tap(_pixelLevelButton(BaseCampSoldierMotion.regrip, 'LV.1'));
      await tester.pump();
      expect(
        DeviceSettingsController.instance.value.breathingPixelLevel,
        SoldierPixelationLevel.coarse,
      );
      expect(
        DeviceSettingsController.instance.value.regripPixelLevel,
        SoldierPixelationLevel.fine,
      );

      final trigger = find.byKey(const ValueKey('soldier-live-trigger-regrip'));
      await tester.ensureVisible(trigger);
      await tester.pump();
      tester.widget<OperationButton>(trigger).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1001));
      expect(find.text('PHASE: RIFLEREGRIP'), findsOneWidget);
      expect(
        _pixelatedImage(
          SoldierPixelationLevel.fine,
          baseCampRifleRegripAssets.first,
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(home: SoldierLiveMotionPreviewPage()),
      );
      await tester.pump();
      expect(
        _pixelControls(tester, BaseCampSoldierMotion.breathing).selected,
        <SoldierPixelationLevel>{SoldierPixelationLevel.coarse},
      );
      expect(
        _pixelControls(tester, BaseCampSoldierMotion.regrip).selected,
        <SoldierPixelationLevel>{SoldierPixelationLevel.fine},
      );

      await tester.tap(
        _pixelLevelButton(BaseCampSoldierMotion.breathing, 'LV.0'),
      );
      await tester.pump();
      expect(
        DeviceSettingsController.instance.value.breathingPixelLevel,
        SoldierPixelationLevel.original,
      );
      expect(
        DeviceSettingsController.instance.value.regripPixelLevel,
        SoldierPixelationLevel.fine,
      );
      expect(
        BaseCampSoldierPixelCache.instance.cachedImageCount,
        greaterThan(0),
      );
    },
  );

  test('all 25 independent level combinations are accepted', () {
    for (final breathing in SoldierPixelationLevel.values) {
      for (final regrip in SoldierPixelationLevel.values) {
        final settings = DeviceSettings(
          breathingPixelLevel: breathing,
          regripPixelLevel: regrip,
        ).normalized();
        expect(settings.breathingPixelLevel, breathing);
        expect(settings.regripPixelLevel, regrip);
      }
    }
  });

  test('pixel levels use increasingly coarse screen-space blocks', () {
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
      expect(find.text('BREATHING PIXEL'), findsOneWidget);
      expect(find.text('REGRIP PIXEL'), findsOneWidget);
      for (var level = 0; level <= 4; level++) {
        expect(find.text('LV.$level'), findsNWidgets(2));
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
      await _preparePreviewProfile(tester, level);
      await tester.pumpWidget(
        const MaterialApp(home: SoldierLiveMotionPreviewPage()),
      );
      await tester.pump();
      await _pumpUntil(
        tester,
        () => _pixelatedImage(
          level,
          baseCampBreathingSoldierLowerAsset,
        ).evaluate().isNotEmpty,
      );

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

SegmentedButton<SoldierPixelationLevel> _pixelControls(
  WidgetTester tester,
  BaseCampSoldierMotion motion,
) => tester.widget<SegmentedButton<SoldierPixelationLevel>>(
  find.byKey(ValueKey('soldier-live-${motion.name}-pixel-level-controls')),
);

Finder _pixelLevelButton(BaseCampSoldierMotion motion, String label) =>
    find.descendant(
      of: find.byKey(
        ValueKey('soldier-live-${motion.name}-pixel-level-controls'),
      ),
      matching: find.text(label),
    );

Finder _pixelatedImage(SoldierPixelationLevel level, String asset) =>
    find.byKey(ValueKey<String>('soldier-pixelated-${level.name}-$asset'));

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 150 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

Future<void> _preparePreviewProfile(
  WidgetTester tester,
  SoldierPixelationLevel level,
) async {
  const width = 430.0 - 32;
  final profile = baseCampSoldierPixelProfile(
    viewport: const Size(width, width / 1.35),
  );
  final prepared = await tester.runAsync(
    () => BaseCampSoldierPixelCache.instance.prepareRequests(
      profile.requests,
      level,
    ),
  );
  expect(prepared, isTrue);
}

Future<void> _preparePreviewMotionProfile(
  WidgetTester tester,
  BaseCampSoldierMotion motion,
  SoldierPixelationLevel level,
) async {
  const width = 430.0 - 32;
  final profile = baseCampSoldierPixelProfile(
    viewport: const Size(width, width / 1.35),
  );
  final prepared = await tester.runAsync(
    () => BaseCampSoldierPixelCache.instance.prepareMotionRequests(
      motion == BaseCampSoldierMotion.breathing
          ? profile.breathingRequests
          : profile.regripRequests,
      motion,
      level,
    ),
  );
  expect(prepared, isTrue);
}
