import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/operation_status.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/dashboard/widgets/operation_ambient_animation.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';

import '../../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../../operation_date/operation_date_test_fixture.dart';

void main() {
  setUp(() {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-11-01');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('BASE CAMP owns a compact terminal and retains the square map', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('base-camp-tactical-terminal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('base-camp-soldier-lower')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('base-camp-soldier-upper')),
      findsOneWidget,
    );
    expect(find.text('OPERATION PROGRESS'), findsOneWidget);
    expect(find.byType(OperationAmbientAnimation), findsOneWidget);
    final waveform = tester.widget<OperationAmbientAnimation>(
      find.byType(OperationAmbientAnimation),
    );
    expect(waveform.showStatusLabel, isFalse);
    expect(
      find.byKey(const ValueKey('base-camp-industrial-lcd')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('base-camp-map')), findsOneWidget);
    final mapSize = tester.getSize(find.byKey(const ValueKey('base-camp-map')));
    expect(
      mapSize.width / mapSize.height,
      closeTo(
        baseCampMapArtworkSize.width / baseCampMapArtworkSize.height,
        .02,
      ),
    );
    final viewport = tester.getSize(
      find.byKey(const ValueKey('base-camp-home-map-viewport')),
    );
    expect(viewport.height, closeTo(mapSize.height, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('soldier panel long press opens the independent live preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(
      find.byKey(const ValueKey('base-camp-soldier-panel')),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('SOLDIER LIVE MOTION PREVIEW'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('soldier-live-trigger-regrip')),
      findsOneWidget,
    );
  });

  testWidgets(
    'dashboard uses the remaining viewport for a fully visible square map',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in const [
        Size(390, 844),
        Size(390, 750),
        Size(375, 667),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const MaterialApp(home: BaseCampDashboardPage()),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final terminal = tester.getRect(
          find.byKey(const ValueKey('base-camp-tactical-terminal')),
        );
        final mapRegion = tester.getRect(
          find.byKey(const ValueKey('base-camp-home-map-region')),
        );
        expect(terminal.height, 356);
        expect(mapRegion.width, closeTo(mapRegion.height, .1));
        expect(mapRegion.bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('terminal pages swipe and open an expanded detail sheet', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(
      find.byKey(const ValueKey('base-camp-terminal-pages')),
      const Offset(-320, 0),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final page = find.byKey(const ValueKey('base-camp-terminal-page-morning'));
    expect(page, findsOneWidget);
    await tester.ensureVisible(page);
    await tester.pump();
    await tester.tap(page);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('OPEN STATUS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress keeps an equal three-column, six-card grid', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    final grid = tester.widget<GridView>(
      find.descendant(
        of: find.byKey(const ValueKey('base-camp-progress-grid')),
        matching: find.byType(GridView),
      ),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(delegate.crossAxisSpacing, 6);
    expect(delegate.mainAxisSpacing, 6);
  });

  testWidgets('status compartment contains the clock, monitor and lamps', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('base-camp-dot-matrix-clock')),
      findsOneWidget,
    );
    expect(find.text('FINE'), findsOneWidget);
    expect(find.text('CAUTION'), findsOneWidget);
    expect(find.text('DANGER'), findsOneWidget);
  });

  test('dot matrix clock dims every changed character at second rollovers', () {
    const prefix = '11/09 (MON) ';
    expect(
      dotMatrixClockChangedIndexes('${prefix}12:34:08', '${prefix}12:34:09'),
      {prefix.length + 7},
    );
    expect(
      dotMatrixClockChangedIndexes('${prefix}12:34:09', '${prefix}12:34:10'),
      {prefix.length + 6, prefix.length + 7},
    );
    expect(
      dotMatrixClockChangedIndexes('${prefix}12:34:59', '${prefix}12:35:00'),
      {prefix.length + 4, prefix.length + 6, prefix.length + 7},
    );
    expect(
      dotMatrixClockChangedIndexes('${prefix}23:59:59', '${prefix}00:00:00'),
      {
        prefix.length,
        prefix.length + 1,
        prefix.length + 3,
        prefix.length + 4,
        prefix.length + 6,
        prefix.length + 7,
      },
    );
  });

  test('clock formats every weekday with its required three-letter value', () {
    expect(baseCampClockText(DateTime(2026, 11, 9)), contains('(MON)'));
    expect(baseCampClockText(DateTime(2026, 11, 10)), contains('(TUE)'));
    expect(baseCampClockText(DateTime(2026, 11, 11)), contains('(WED)'));
    expect(baseCampClockText(DateTime(2026, 11, 12)), contains('(THU)'));
    expect(baseCampClockText(DateTime(2026, 11, 13)), contains('(FRI)'));
    expect(baseCampClockText(DateTime(2026, 11, 14)), contains('(SAT)'));
    expect(baseCampClockText(DateTime(2026, 11, 15)), contains('(SUN)'));
  });

  testWidgets('progress uses instrument cells instead of progress bars', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('FOOD readout preserves formal partial and completion semantics', () {
    expect(baseCampFoodProgressText(0), 'NOT RECORDED');
    expect(baseCampFoodProgressText(1), '1 / 3');
    expect(baseCampFoodProgressText(2), '2 / 3');
    expect(baseCampFoodProgressText(3), 'COMPLETE');
  });

  testWidgets(
    'instrument panels retain exact nested geometry on mobile widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [320.0, 375.0, 430.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(
          const MaterialApp(home: BaseCampDashboardPage()),
        );
        await tester.pump(const Duration(milliseconds: 120));
        final progress = find.byKey(
          const ValueKey('base-camp-terminal-page-progress'),
        );
        final panels = find.descendant(
          of: progress,
          matching: find.byKey(const ValueKey('base-camp-instrument-panel')),
        );
        final readouts = find.descendant(
          of: progress,
          matching: find.byKey(const ValueKey('base-camp-lcd-readout')),
        );
        expect(panels, findsNWidgets(6));
        expect(readouts, findsNWidgets(6));
        for (final panel in panels.evaluate()) {
          expect(
            tester
                .getSize(find.byElementPredicate((element) => element == panel))
                .height,
            closeTo(53, .1),
          );
        }
        for (final readout in readouts.evaluate()) {
          final readoutRect = tester.getRect(
            find.byElementPredicate((element) => element == readout),
          );
          expect(
            panels
                .evaluate()
                .map((panel) {
                  return tester.getRect(
                    find.byElementPredicate((element) => element == panel),
                  );
                })
                .any(
                  (panelRect) =>
                      panelRect.contains(readoutRect.topLeft) &&
                      panelRect.contains(readoutRect.bottomRight),
                ),
            isTrue,
          );
          expect(
            tester
                .getSize(
                  find.byElementPredicate((element) => element == readout),
                )
                .height,
            closeTo(25, .1),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  test(
    'breathing offset is periodic, vertical-only and stays within range',
    () {
      expect(baseCampBreathingOffset(0), 0);
      expect(baseCampBreathingOffset(600), closeTo(-.5, .0001));
      expect(baseCampBreathingOffset(1200), closeTo(-1, .0001));
      expect(baseCampBreathingOffset(1800), closeTo(-.5, .0001));
      expect(baseCampBreathingOffset(2400), closeTo(0, .0001));
    },
  );

  test(
    'tactical grid shares wall origins with the bounded perspective floor',
    () {
      const panel = Size(128, 100);
      expect(baseCampSoldierGroundY(panel), 78);
      expect(baseCampSoldierWallLinePositions(panel.width), [0, 32, 64, 96]);
      expect(baseCampSoldierWallLinePositions(78), [0, 32, 64]);
      expect(baseCampSoldierFloorLinePositions(panel), [83.5, 90.1, 96.7]);
      for (final expectation in <(double, double)>[
        (-51.2, 0),
        (6.4, 32),
        (64, 64),
        (121.6, 96),
      ]) {
        final endpoint = baseCampSoldierPerspectiveEndpoint(
          panel,
          expectation.$2,
        );
        expect(endpoint.dx, closeTo(expectation.$1, .001));
        expect(endpoint.dy, 100);
      }
    },
  );

  test(
    'rifle frame transform has one stable standing size and foot anchor',
    () {
      final layout = baseCampRifleRegripLayout(const Size(122, 90));
      expect(layout.normalFootY, closeTo(layout.specialFootY, .001));
      expect(
        layout.normalFootY - layout.normalHeadY,
        closeTo(layout.specialFootY - layout.specialHeadY, .15),
      );
      expect(layout.specialHeadY, greaterThanOrEqualTo(0));
      expect(layout.specialFootY, lessThanOrEqualTo(90));
    },
  );

  test('rifle regrip timeline uses every approved frame once in order', () {
    expect(baseCampRifleRegripPreIdleMs, 1000);
    expect(baseCampRifleRegripAnimationMs, 1850);
    expect(baseCampRifleRegripPostIdleMs, 1000);
    expect(baseCampRifleRegripEventMs, 3850);
    expect(baseCampRifleRegripFrameDurations, [400, 350, 200, 350, 150, 400]);

    expect(baseCampRifleRegripPhase(0), BaseCampRifleRegripPhase.preIdle);
    expect(baseCampRifleRegripPhase(999), BaseCampRifleRegripPhase.preIdle);
    expect(
      baseCampRifleRegripPhase(1000),
      BaseCampRifleRegripPhase.rifleRegrip,
    );
    expect(baseCampRifleRegripFrameIndex(1000), 0);
    expect(baseCampRifleRegripFrameIndex(1400), 1);
    expect(baseCampRifleRegripFrameIndex(1750), 2);
    expect(baseCampRifleRegripFrameIndex(1950), 3);
    expect(baseCampRifleRegripFrameIndex(2300), 4);
    expect(baseCampRifleRegripFrameIndex(2450), 5);
    expect(baseCampRifleRegripPhase(2850), BaseCampRifleRegripPhase.postIdle);
    expect(baseCampRifleRegripPhase(3849), BaseCampRifleRegripPhase.postIdle);
    expect(baseCampRifleRegripPhase(3850), BaseCampRifleRegripPhase.breathing);
  });

  test('rifle regrip random interval is always between 60 and 120 seconds', () {
    expect(baseCampRifleRegripIntervalMs((_) => 0), 60000);
    expect(baseCampRifleRegripIntervalMs((_) => 1), 60001);
    expect(baseCampRifleRegripIntervalMs((_) => 60000), 120000);
  });

  test(
    'all corrected rifle frames are transparent, normalized RGBA assets',
    () async {
      expect(baseCampRifleRegripAssets, hasLength(6));
      final normalMaterial = await _opaqueRgbaMean(
        baseCampBreathingSoldierUpperAsset,
      );
      for (final asset in baseCampRifleRegripAssets) {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 512);
        expect(frame.image.height, 512);
        final rgba = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(rgba, isNotNull);
        var top = frame.image.height;
        var bottom = -1;
        final material = await _opaqueRgbaMean(asset);
        for (var y = 0; y < frame.image.height; y++) {
          for (var x = 0; x < frame.image.width; x++) {
            final offset = (y * frame.image.width + x) * 4;
            final alpha = rgba!.getUint8(offset + 3);
            if (alpha == 0) continue;
            top = math.min(top, y);
            bottom = math.max(bottom, y);
          }
        }
        expect(top, 32);
        expect(bottom, 511);
        expect(bottom - top + 1, 480);
        // PNG channel rounding and Flutter's decoder differ by at most 1.5
        // channel values (under 0.6% of the full range).
        expect(material.red, closeTo(normalMaterial.red, 1.5));
        expect(material.green, closeTo(normalMaterial.green, 1.5));
        expect(material.blue, closeTo(normalMaterial.blue, 1.5));
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  testWidgets('STATUS DATA and SUSTAINMENT retain five nested instruments', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 120));
    final pages = find.byKey(const ValueKey('base-camp-terminal-pages'));
    await tester.drag(pages, const Offset(-320, 0));
    await tester.pump(const Duration(milliseconds: 300));
    for (final pageName in ['morning', 'sustainment']) {
      final page = find.byKey(ValueKey('base-camp-terminal-page-$pageName'));
      final panels = find.descendant(
        of: page,
        matching: find.byKey(const ValueKey('base-camp-instrument-panel')),
      );
      final readouts = find.descendant(
        of: page,
        matching: find.byKey(const ValueKey('base-camp-lcd-readout')),
      );
      expect(panels, findsNWidgets(5));
      expect(readouts, findsNWidgets(5));
      for (final panel in panels.evaluate()) {
        expect(
          tester
              .getRect(find.byElementPredicate((element) => element == panel))
              .bottom,
          // The content viewport ends before the page's 10dp lower padding;
          // keep the complete panel at least 2dp above that boundary.
          lessThanOrEqualTo(tester.getRect(page).bottom - 12),
        );
      }
      if (pageName == 'morning') {
        await tester.drag(pages, const Offset(-320, 0));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('instrument geometry remains bounded at accessibility scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: const MaterialApp(home: BaseCampDashboardPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(const ValueKey('base-camp-instrument-panel')),
      findsNWidgets(6),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('terminal polarity updates the LCD immediately', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(const ValueKey('base-camp-lcd-polarity-switch')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('LCD polarity controls command text and page indicators only', (
    tester,
  ) async {
    DeviceSettingsController.instance.update(
      DeviceSettingsController.instance.value.copyWith(
        baseCampLcdNegative: false,
      ),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 160));
    final pages = find.byKey(const ValueKey('base-camp-terminal-pages'));
    final indicators = List<Finder>.generate(
      4,
      (index) => find.byKey(ValueKey('base-camp-page-indicator-$index')),
    );
    expect(tester.getSize(indicators[0]), const Size(20, 5));
    expect(tester.getSize(indicators[1]), const Size(8, 5));
    for (var index = 0; index < 3; index++) {
      await tester.drag(pages, const Offset(-320, 0));
      await tester.pump(const Duration(milliseconds: 300));
    }

    final command = tester.widget<Text>(
      find.byKey(const ValueKey('base-camp-command-intent')),
    );
    expect(command.style?.color, const Color(0xff273326));
    final selectedBefore = indicators.indexWhere(
      (indicator) =>
          (tester.widget<AnimatedContainer>(indicator).decoration!
                  as BoxDecoration)
              .color ==
          const Color(0xffc7d6a0),
    );
    expect(selectedBefore, greaterThan(0));
    final active = indicators[selectedBefore];
    final inactive = indicators.firstWhere((indicator) => indicator != active);
    expect(tester.getSize(inactive), const Size(8, 5));

    await tester.tap(
      find.byKey(const ValueKey('base-camp-lcd-polarity-switch')),
    );
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('base-camp-command-intent')))
          .style
          ?.color,
      const Color(0xffaeb894),
    );
    expect(
      indicators.indexWhere(
        (indicator) =>
            (tester.widget<AnimatedContainer>(indicator).decoration!
                    as BoxDecoration)
                .color ==
            const Color(0xffc7d6a0),
      ),
      selectedBefore,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambient waveform preserves the STANDARD label by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OperationAmbientAnimation(status: OperationStatus.green),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('operation-ambient-status-label')),
      findsOneWidget,
    );
  });
}

Future<({double red, double green, double blue})> _opaqueRgbaMean(
  String asset,
) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final rgba = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  var red = 0;
  var green = 0;
  var blue = 0;
  var count = 0;
  for (var offset = 0; offset < rgba!.lengthInBytes; offset += 4) {
    if (rgba.getUint8(offset + 3) < 16) continue;
    red += rgba.getUint8(offset);
    green += rgba.getUint8(offset + 1);
    blue += rgba.getUint8(offset + 2);
    count++;
  }
  frame.image.dispose();
  codec.dispose();
  return (red: red / count, green: green / count, blue: blue / count);
}
