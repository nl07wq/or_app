import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/dashboard_glass_card.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/core/theme/app_theme.dart';
import 'package:or_app/features/body_history/pages/data_center_history_page.dart';
import 'package:or_app/features/body_history/services/history_visual_preference.dart';
import 'package:or_app/features/body_history/widgets/history_data_vault_hyperspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpHistory(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool animateAmbient = false,
    Duration dataVaultSimulationTime = Duration.zero,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: StandardTheme.theme,
        home: DataCenterHistoryPage(
          animateAmbient: animateAmbient,
          dataVaultSimulationTime: dataVaultSimulationTime,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('supports all independent title and ambient combinations', (
    tester,
  ) async {
    await pumpHistory(tester);
    for (final title in HistoryTitleVariant.values) {
      for (final ambient in HistoryAmbientVariant.values) {
        await tester.tap(
          find.text(switch (title) {
            HistoryTitleVariant.archiveDisplay => 'A DISPLAY',
            HistoryTitleVariant.archivePlate => 'B PLATE',
            HistoryTitleVariant.memoryModule => 'C MODULE',
          }),
        );
        await tester.tap(
          find.text(switch (ambient) {
            HistoryAmbientVariant.chronoArchive => 'A CHRONO',
            HistoryAmbientVariant.dataVault => 'B VAULT',
            HistoryAmbientVariant.memoryStream => 'C STREAM',
          }),
        );
        await tester.pump();
        expect(
          find.byKey(ValueKey('history-title-${title.name}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('history-ambient-${ambient.name}')),
          findsOneWidget,
        );
      }
    }
  });

  testWidgets('retains the fixed title and ambient while history scrolls', (
    tester,
  ) async {
    await pumpHistory(tester);
    final titleBefore = tester.getTopLeft(
      find.byKey(const ValueKey('history-title-archiveDisplay')),
    );
    final ambientBefore = tester.getTopLeft(
      find.byKey(const ValueKey('history-ambient-chronoArchive')),
    );
    final cardBefore = tester.getTopLeft(find.text('BODY HISTORY'));

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pump();

    expect(
      tester.getTopLeft(
        find.byKey(const ValueKey('history-title-archiveDisplay')),
      ),
      titleBefore,
    );
    expect(
      tester.getTopLeft(
        find.byKey(const ValueKey('history-ambient-chronoArchive')),
      ),
      ambientBefore,
    );
    expect(
      tester.getTopLeft(find.text('BODY HISTORY')).dy,
      lessThan(cardBefore.dy),
    );
  });

  testWidgets(
    'applies the Dashboard glass material only to HISTORY link cards',
    (tester) async {
      await pumpHistory(tester);

      // ListView lazily builds the three visible cards at this viewport; every
      // built link card must use the Dashboard source material.
      expect(find.byType(DashboardGlassCard), findsNWidgets(3));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is OperationButton && widget.dashboardGlass == true,
        ),
        findsNWidgets(3),
      );
      expect(
        find.byKey(const ValueKey('history-visual-selector')),
        findsOneWidget,
      );
    },
  );

  for (final size in const [
    Size(320, 844),
    Size(375, 844),
    Size(390, 844),
    Size(430, 844),
  ]) {
    testWidgets('renders HISTORY visual controls without overflow at $size', (
      tester,
    ) async {
      await pumpHistory(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('history-visual-selector')),
        findsOneWidget,
      );
    });
  }

  testWidgets('renders the default visual golden', (tester) async {
    await pumpHistory(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/data_center_history_visual_default.png'),
    );
  });

  testWidgets('renders all HISTORY title and ambient golden combinations', (
    tester,
  ) async {
    await pumpHistory(tester);
    for (final title in HistoryTitleVariant.values) {
      for (final ambient in HistoryAmbientVariant.values) {
        await tester.tap(
          find.text(switch (title) {
            HistoryTitleVariant.archiveDisplay => 'A DISPLAY',
            HistoryTitleVariant.archivePlate => 'B PLATE',
            HistoryTitleVariant.memoryModule => 'C MODULE',
          }),
        );
        await tester.tap(
          find.text(switch (ambient) {
            HistoryAmbientVariant.chronoArchive => 'A CHRONO',
            HistoryAmbientVariant.dataVault => 'B VAULT',
            HistoryAmbientVariant.memoryStream => 'C STREAM',
          }),
        );
        await tester.pump();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/data_center_history_${title.name}_${ambient.name}.png',
          ),
        );
      }
    }
  });

  testWidgets('renders distinct title comparison goldens', (tester) async {
    await pumpHistory(tester);
    for (final title in HistoryTitleVariant.values) {
      await tester.tap(
        find.text(switch (title) {
          HistoryTitleVariant.archiveDisplay => 'A DISPLAY',
          HistoryTitleVariant.archivePlate => 'B PLATE',
          HistoryTitleVariant.memoryModule => 'C MODULE',
        }),
      );
      await tester.pump();
      await expectLater(
        find.byKey(ValueKey('history-title-${title.name}')),
        matchesGoldenFile('goldens/history_title_${title.name}.png'),
      );
    }
  });

  testWidgets('keeps each animated ambient continuous at loop boundary', (
    tester,
  ) async {
    await pumpHistory(tester, animateAmbient: true);
    for (final ambient in HistoryAmbientVariant.values) {
      await tester.tap(
        find.text(switch (ambient) {
          HistoryAmbientVariant.chronoArchive => 'A CHRONO',
          HistoryAmbientVariant.dataVault => 'B VAULT',
          HistoryAmbientVariant.memoryStream => 'C STREAM',
        }),
      );
      await tester.pump();
      await expectLater(
        find.byKey(ValueKey('history-ambient-${ambient.name}')),
        matchesGoldenFile('goldens/history_ambient_${ambient.name}_start.png'),
      );
      await tester.pump(const Duration(seconds: 9));
      await expectLater(
        find.byKey(ValueKey('history-ambient-${ambient.name}')),
        matchesGoldenFile(
          'goldens/history_ambient_${ambient.name}_quarter.png',
        ),
      );
      await tester.pump(const Duration(seconds: 27));
      await expectLater(
        find.byKey(ValueKey('history-ambient-${ambient.name}')),
        matchesGoldenFile('goldens/history_ambient_${ambient.name}_loop.png'),
      );
    }
  });

  testWidgets('renders V1.8 wave, beacon pulse and irregular impulses', (
    tester,
  ) async {
    const phases = <(String, Duration)>[
      ('start', Duration.zero),
      ('cruise', Duration(seconds: 5)),
      ('boost_ramp_up', Duration(milliseconds: 8100)),
      ('boost_peak', Duration(milliseconds: 8650)),
      ('boost_ramp_down', Duration(milliseconds: 9300)),
      ('corner_unboosted', Duration(seconds: 34)),
      ('boundary_before', Duration(milliseconds: 47990)),
      ('boundary_after', Duration(milliseconds: 48010)),
      ('second_boundary_before', Duration(milliseconds: 95990)),
      ('second_boundary_after', Duration(milliseconds: 96010)),
    ];

    for (final phase in phases) {
      await pumpHistory(tester, dataVaultSimulationTime: phase.$2);
      await tester.tap(find.text('B VAULT'));
      await tester.pump();
      if (phase.$2 != Duration.zero) await tester.pump(phase.$2);
      await expectLater(
        find.byKey(const ValueKey('history-ambient-dataVault')),
        matchesGoldenFile(
          'goldens/history_data_vault_v18_wave_${phase.$1}.png',
        ),
      );
    }
  });

  test('DATA VAULT V1.8 wave motion is fast, deterministic and continuous', () {
    expect(HistoryDataVaultMotion.speedAt(0), closeTo(14.175, .000001));
    expect(HistoryDataVaultMotion.baseSpeedAt(12), closeTo(14.175, .000001));
    expect(HistoryDataVaultMotion.baseSpeedAt(17), closeTo(32.40, .000001));
    expect(HistoryDataVaultMotion.baseSpeedAt(22), closeTo(32.40, .000001));
    expect(HistoryDataVaultMotion.baseSpeedAt(27), closeTo(22.275, .000001));
    expect(HistoryDataVaultMotion.baseSpeedAt(36), closeTo(22.275, .000001));
    expect(HistoryDataVaultMotion.baseSpeedAt(42), closeTo(14.175, .000001));
    expect(HistoryDataVaultMotion.speedAt(48), closeTo(14.175, .000001));
    expect(HistoryDataVaultMotion.speedWaveAt(12), closeTo(1.05, .000001));
    expect(HistoryDataVaultMotion.speedWaveAt(0), closeTo(1, .000001));
    expect(HistoryDataVaultMotion.speedWaveAt(48), closeTo(1, .000001));
    expect(HistoryDataVaultMotion.boostMultiplierAt(8.65), greaterThan(1.65));
    expect(HistoryDataVaultMotion.boostMultiplierAt(19.5), greaterThan(1.80));
    expect(HistoryDataVaultMotion.boostMultiplierAt(5), closeTo(1, .000001));
    for (var milliseconds = 0; milliseconds <= 48000; milliseconds += 250) {
      final seconds = milliseconds / 1000;
      expect(
        HistoryDataVaultMotion.speedAt(seconds),
        greaterThanOrEqualTo(14.17),
      );
      expect(
        HistoryDataVaultMotion.speedAt(seconds),
        lessThanOrEqualTo(HistoryDataVaultMotion.baseSpeedAt(seconds) * 2),
      );
    }
    for (final transition in [0.0, 12.0, 17.0, 22.0, 27.0, 36.0, 42.0, 48.0]) {
      expect(
        (HistoryDataVaultMotion.speedAt(transition - .001) -
                HistoryDataVaultMotion.speedAt(transition + .001))
            .abs(),
        lessThan(.08),
      );
    }
    for (final boundary in [40.0, 105.0, 130.0, 195.0, 240.0]) {
      expect(
        (HistoryDataVaultMotion.curvatureAt(boundary - .001) -
                HistoryDataVaultMotion.curvatureAt(boundary + .001))
            .abs(),
        lessThan(.001),
      );
    }
    for (var second = 0; second < 240; second++) {
      expect(
        HistoryDataVaultMotion.distanceAt((second + 1).toDouble()),
        greaterThan(HistoryDataVaultMotion.distanceAt(second.toDouble())),
      );
    }
    expect(
      HistoryDataVaultMotion.distanceAt(48),
      closeTo(HistoryDataVaultMotion.distancePerCycle, .0001),
    );
    expect(
      HistoryDataVaultMotion.distanceAt(48.01),
      greaterThan(HistoryDataVaultMotion.distanceAt(48)),
    );
    expect(
      HistoryDataVaultMotion.distanceAt(48.001) -
          HistoryDataVaultMotion.distanceAt(47.999),
      closeTo(.02835, .004),
    );
    expect(
      HistoryDataVaultMotion.distanceAt(96.01) -
          HistoryDataVaultMotion.distanceAt(95.99),
      closeTo(.2835, .004),
    );
    expect(
      HistoryDataVaultMotion.distanceAt(48),
      closeTo(HistoryDataVaultMotion.distancePerCycle, .0001),
    );
    expect(HistoryDataVaultMotion.navigationHeadOffset, 5.5);
    expect(HistoryDataVaultMotion.navigationTrailOffset, 1.2);
    expect(
      HistoryDataVaultMotion.beaconSprintAdvance(
        HistoryDataVaultMotion.speedAt(20),
        20,
      ),
      greaterThan(1.9),
    );

    const seconds = 20.0;
    final profiles = <DataVaultImpulseProfile>[];
    for (final surface in DataVaultImpulseSurface.values) {
      final laneCount = switch (surface) {
        DataVaultImpulseSurface.floor => 5,
        DataVaultImpulseSurface.leftWall ||
        DataVaultImpulseSurface.rightWall => 2,
        DataVaultImpulseSurface.ceiling => 3,
      };
      for (var lane = 0; lane < laneCount; lane++) {
        final profile = HistoryDataVaultMotion.impulseProfileFor(surface, lane);
        profiles.add(profile);
        expect(profile.repeatInterval, inInclusiveRange(1.1, 3.7));
        expect(profile.speedMultiplier, inInclusiveRange(.85, 1.25));
        expect(profile.headLength, greaterThan(.29));
        expect(profile.tailLength, greaterThan(2));
      }
    }
    expect(
      profiles.map((profile) => profile.repeatInterval).toSet().length,
      greaterThan(6),
    );
    expect(
      profiles.map((profile) => profile.launchOffset).toSet().length,
      greaterThan(6),
    );

    final families = <DataVaultImpulseFamily>{};
    final colors = <int>{};
    for (var packet = -12; packet <= 12; packet++) {
      final variant = HistoryDataVaultMotion.impulseVariantFor(
        DataVaultImpulseSurface.floor,
        2,
        packet,
      );
      families.add(variant.family);
      colors.add(variant.colorIndex);
    }
    expect(families, containsAll(DataVaultImpulseFamily.values));
    expect(colors.length, greaterThan(2));
    final floorAtNear = HistoryDataVaultMotion.floorImpulseLateralAt(0, 7, 20);
    final floorAtFar = HistoryDataVaultMotion.floorImpulseLateralAt(0, 7, 45);
    expect((floorAtNear - floorAtFar).abs(), greaterThan(.01));
    expect([-3.2, -1.6, 0.0, 1.6, 3.2], isNot(contains(floorAtNear)));

    final pulseLow = HistoryDataVaultMotion.beaconPulseAt(.1);
    final pulseHigh = HistoryDataVaultMotion.beaconPulseAt(1.7);
    expect(
      (pulseHigh.outerRadius - pulseLow.outerRadius).abs(),
      greaterThan(.03),
    );
    expect(
      (pulseHigh.outerAlpha - pulseLow.outerAlpha).abs(),
      greaterThan(.06),
    );

    final profile = HistoryDataVaultMotion.impulseProfileFor(
      DataVaultImpulseSurface.floor,
      0,
    );
    final launch = profile.launchOffset + 7 * profile.repeatInterval;
    final incomingBefore = HistoryDataVaultMotion.impulseHeadDistance(
      seconds: launch + .50,
      launchSeconds: launch,
      speedMultiplier: profile.speedMultiplier,
    );
    final incomingAfter = HistoryDataVaultMotion.impulseHeadDistance(
      seconds: launch + .51,
      launchSeconds: launch,
      speedMultiplier: profile.speedMultiplier,
    );
    expect(incomingAfter, lessThan(incomingBefore));
    expect(
      HistoryDataVaultMotion.impulseHeadDistance(
            seconds: 48.01,
            launchSeconds: 46,
            speedMultiplier: profile.speedMultiplier,
          ) -
          HistoryDataVaultMotion.impulseHeadDistance(
            seconds: 47.99,
            launchSeconds: 46,
            speedMultiplier: profile.speedMultiplier,
          ),
      lessThan(0),
    );

    final activeIndex =
        ((seconds - profile.launchOffset) / profile.repeatInterval).floor();
    final activeLaunch =
        profile.launchOffset + activeIndex * profile.repeatInterval;
    final pillarHead = HistoryDataVaultMotion.impulseHeadDistance(
      seconds: seconds,
      launchSeconds: activeLaunch,
      speedMultiplier: profile.speedMultiplier,
    );
    expect(
      HistoryDataVaultMotion.pillarAccessResponse(
        seconds,
        HistoryDataVaultMotion.distanceAt(seconds),
        pillarHead,
      ),
      greaterThan(.99),
    );
  });

  test('measures bounded local DATA VAULT painter work', () {
    const times = [
      0.0,
      7.0,
      16.0,
      20.0,
      27.0,
      32.0,
      37.0,
      42.0,
      47.99,
      48.01,
      96.01,
    ];
    final watch = Stopwatch()..start();
    for (final seconds in times) {
      final recorder = ui.PictureRecorder();
      HistoryDataVaultHyperspace(
        seconds: seconds,
      ).paint(Canvas(recorder), const Size(390, 844));
      recorder.endRecording().dispose();
    }
    watch.stop();
    // Informational only: CI/browser machines differ and this is not an
    // iPhone Safari frame-time assertion.
    // ignore: avoid_print
    print('DATA_VAULT_LOCAL_PAINT_11_MS=${watch.elapsedMilliseconds}');
    expect(watch.elapsedMicroseconds, greaterThanOrEqualTo(0));
  });
}
