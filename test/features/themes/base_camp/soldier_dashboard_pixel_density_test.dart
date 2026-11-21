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

  test('Dashboard density follows calibrated grid across widths and DPR', () {
    final viewports = <double, Size>{
      320: const Size(91.7, 82),
      375: const Size(113.7, 82),
      390: const Size(119.7, 82),
      430: const Size(135.7, 82),
    };
    for (final dpr in <double>[2, 3]) {
      for (final entry in viewports.entries) {
        Size? previous;
        for (final level in SoldierPixelationLevel.values.skip(1)) {
          final request = baseCampSoldierPixelProfile(
            viewport: entry.value,
            devicePixelRatio: dpr,
            density: BaseCampSoldierPixelDensity.dashboardCorrected,
          ).requestFor(baseCampBreathingSoldierLowerAsset);
          final grid = request.reducedSize(level);
          if (previous != null) {
            expect(grid.width, lessThan(previous.width));
            expect(grid.height, lessThan(previous.height));
          }
          previous = grid;
          expect(grid.width, lessThanOrEqualTo(request.sourceSize.width));
          expect(grid.height, lessThanOrEqualTo(request.sourceSize.height));
          expect(
            grid.width,
            lessThanOrEqualTo(
              (request.targetRect.width * dpr).ceilToDouble() + 2,
            ),
          );
          expect(
            grid.height,
            lessThanOrEqualTo(
              (request.targetRect.height * dpr).ceilToDouble() + 2,
            ),
          );
          // ignore: avoid_print
          print(
            'width=${entry.key.toInt()} dpr=$dpr ${level.controlLabel} '
            'grid=${grid.width.toInt()}x${grid.height.toInt()}',
          );
        }
      }
    }
  });

  test('390dp DPR3 calibration remains within one grid cell', () {
    final profile = baseCampSoldierPixelProfile(
      viewport: const Size(119.7, 82),
      devicePixelRatio: 3,
      density: BaseCampSoldierPixelDensity.dashboardCorrected,
    );
    const expected = <SoldierPixelationLevel, Size>{
      SoldierPixelationLevel.fine: Size(147, 133),
      SoldierPixelationLevel.medium: Size(110, 100),
      SoldierPixelationLevel.coarse: Size(98, 89),
      SoldierPixelationLevel.extreme: Size(80, 73),
    };
    final request = profile.requestFor(baseCampBreathingSoldierLowerAsset);
    for (final entry in expected.entries) {
      final grid = request.reducedSize(entry.key);
      expect(grid.width, closeTo(entry.value.width, 1));
      expect(grid.height, closeTo(entry.value.height, 1));
    }
  });

  test('standard Editor density remains unchanged', () {
    final request = baseCampSoldierPixelProfile(
      viewport: const Size(119.7, 82),
      devicePixelRatio: 3,
    ).requestFor(baseCampBreathingSoldierLowerAsset);
    const expected = <SoldierPixelationLevel, Size>{
      SoldierPixelationLevel.fine: Size(46, 41),
      SoldierPixelationLevel.medium: Size(35, 31),
      SoldierPixelationLevel.coarse: Size(31, 28),
      SoldierPixelationLevel.extreme: Size(25, 23),
    };
    for (final entry in expected.entries) {
      expect(request.reducedSize(entry.key), entry.value);
    }
  });

  testWidgets('density identity prevents standard and Dashboard cache mixing', (
    tester,
  ) async {
    const level = SoldierPixelationLevel.coarse;
    const viewport = Size(119.7, 82);
    final standard = baseCampSoldierPixelProfile(
      viewport: viewport,
      devicePixelRatio: 3,
    );
    final dashboard = baseCampSoldierPixelProfile(
      viewport: viewport,
      devicePixelRatio: 3,
      density: BaseCampSoldierPixelDensity.dashboardCorrected,
    );
    expect(standard.key, isNot(dashboard.key));
    expect(
      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareMotionRequests(
          standard.breathingRequests,
          BaseCampSoldierMotion.breathing,
          level,
        ),
      ),
      isTrue,
    );
    expect(
      BaseCampSoldierPixelCache.instance.cachedFrame(
        dashboard.requestFor(baseCampBreathingSoldierLowerAsset),
        level,
      ),
      isNull,
    );
  });

  testWidgets('all corrected Dashboard frames prepare within bounded memory', (
    tester,
  ) async {
    const viewport = Size(119.7, 82);
    for (final level in SoldierPixelationLevel.values.skip(1)) {
      BaseCampSoldierPixelCache.instance.resetForTesting();
      final profile = baseCampSoldierPixelProfile(
        viewport: viewport,
        devicePixelRatio: 3,
        density: BaseCampSoldierPixelDensity.dashboardCorrected,
      );
      final watch = Stopwatch()..start();
      expect(
        await tester.runAsync(
          () => BaseCampSoldierPixelCache.instance.prepareRequests(
            profile.requests,
            level,
          ),
        ),
        isTrue,
      );
      watch.stop();
      // ignore: avoid_print
      print(
        '${level.controlLabel}: prepareMs=${watch.elapsedMilliseconds} '
        'images=${BaseCampSoldierPixelCache.instance.cachedImageCount} '
        'pixels=${BaseCampSoldierPixelCache.instance.cachedPixelCount}',
      );
      expect(
        BaseCampSoldierPixelCache.instance.cachedImageCount,
        baseCampSoldierPixelFrameCount,
      );
      expect(
        BaseCampSoldierPixelCache.instance.cachedPixelCount,
        lessThan(250000),
      );
    }
  });
}
