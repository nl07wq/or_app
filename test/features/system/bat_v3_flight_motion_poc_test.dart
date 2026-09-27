import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/animations_sandbox_page.dart';
import 'package:or_app/features/system/pages/bat_v3_flight_motion_poc.dart';
import 'package:or_app/features/system/pages/bat_v3_source_data.dart';

void main() {
  test(
    'V4 canonical cels have one canvas, one body origin, and normalized axes',
    () {
      expect(BatV3SourceSet.poses, hasLength(5));
      expect(BatV3SourceSet.poses.map((p) => p.name), const [
        'NEUTRAL',
        'TOP INTERMEDIATE',
        'TOP',
        'BOTTOM INTERMEDIATE',
        'BOTTOM',
      ]);
      expect(BatV3SourceSet.canonicalCanvas, const Size(1800, 1700));
      expect(BatV3SourceSet.canonicalBodyAnchor, const Offset(800, 850));
      for (final pose in BatV3SourceSet.poses) {
        expect(pose.canonicalAsset, contains('bat_v3/canonical/'));
        expect(
          pose.canonicalBodyAxis,
          closeTo(BatV3SourceSet.canonicalBodyAxis, .01),
        );
        expect(
          BatV3SourceSet.isFullyContained(pose),
          isTrue,
          reason: pose.name,
        );
      }
    },
  );

  test('V4 retains the explicit source stroke, timing, and Y-only flutter', () {
    expect(BatV3SourceSet.cycle, const [0, 1, 2, 1, 0, 3, 4, 3]);
    expect(BatV3SourceSet.flutterOffsets, const [0, -2, -4, -2, 0, 2, 4, 2]);
    expect(BatV3SourceSet.catProductionGrayArgb, 0xFF7A7A7A);
  });

  testWidgets('V4 canonical PNG cels are registered app assets', (
    tester,
  ) async {
    for (final pose in BatV3SourceSet.poses) {
      final bytes = await rootBundle.load(pose.canonicalAsset);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: pose.name);
    }
  });

  testWidgets('V4 exposes canonical and body-overlay inspection only', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_host());
    expect(find.byKey(const ValueKey('bat-v3-view-canonical')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bat-v3-view-bodyOverlay')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bat-v3-view-raw')), findsNothing);
    expect(find.byKey(const ValueKey('bat-v3-view-mask')), findsNothing);
    expect(find.byKey(const ValueKey('bat-v3-view-registered')), findsNothing);
    expect(find.textContaining('PAUSED · 125 ms / POSE'), findsOneWidget);
  });

  testWidgets(
    'V4 keeps canonical playback, selected crossing size, and direction controls',
    (tester) async {
      _viewport(tester);
      await tester.pumpWidget(_host());
      await tester.tap(find.byKey(const ValueKey('bat-v3-restart')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('FRAME 03 · TOP'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('bat-v3-crossing')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bat-v3-crossing-stage')),
        findsOneWidget,
      );
      for (final scale in ['1.00', '0.50', '0.25']) {
        await tester.tap(find.byKey(ValueKey('bat-v3-scale-$scale')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: scale);
      }
      await tester.tap(find.byKey(const ValueKey('bat-v3-rtl')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('V4 remains responsive without legacy CAT POC restoration', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 6000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_host());
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    await tester.pumpWidget(const MaterialApp(home: AnimationsSandboxPage()));
    expect(find.byKey(const ValueKey('bat-v3-source-audit')), findsOneWidget);
    expect(find.text('CAT TRACE PIPELINE POC'), findsNothing);
  });

  testWidgets('Production preview is isolated, canonical, and tunable', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_productionHost());
    expect(
      find.byKey(const ValueKey('bat-v3-production-preview')),
      findsOneWidget,
    );
    expect(find.textContaining('100 ms'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bat-v3-production-stage')),
      findsOneWidget,
    );
    for (final key in [
      'bat-v3-production-timing-100',
      'bat-v3-production-timing-150',
      'bat-v3-production-flutter-off',
      'bat-v3-production-flutter-6',
      'bat-v3-production-speed-5000ms',
      'bat-v3-production-speed-1800ms',
      'bat-v3-production-ltr',
      'bat-v3-production-rtl',
      'bat-v3-production-restart',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: key);
    }
  });

  testWidgets('Production pose clock uses the selected cadence independently', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_productionHost());
    await tester.tap(find.byKey(const ValueKey('bat-v3-production-restart')));
    await tester.pump();
    expect(find.textContaining('FRAME 01 · NEUTRAL'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-timing-100')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('FRAME 02 · TOP INTERMEDIATE'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('FRAME 03 · TOP'), findsOneWidget);

    // Changing timing while playing reschedules only the pose clock.
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-timing-150')),
    );
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.textContaining('FRAME 03 · TOP'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('FRAME 02 · TOP INTERMEDIATE'), findsOneWidget);
  });

  test(
    'Production preview crosses full width and applies flutter in screen px',
    () {
      for (final width in [320.0, 390.0, 900.0]) {
        expect(
          BatV3ProductionFlight.leftFor(
            stageWidth: width,
            progress: 0,
            leftToRight: true,
          ),
          closeTo(
            -BatV3ProductionFlight.visibleBatMaxX -
                BatV3ProductionFlight.entryExitGap,
            .001,
          ),
        );
        expect(
          BatV3ProductionFlight.leftFor(
            stageWidth: width,
            progress: 1,
            leftToRight: true,
          ),
          closeTo(
            width -
                BatV3ProductionFlight.visibleBatMinX +
                BatV3ProductionFlight.entryExitGap,
            .001,
          ),
        );
        expect(
          BatV3ProductionFlight.leftFor(
            stageWidth: width,
            progress: 0,
            leftToRight: false,
          ),
          closeTo(
            width -
                BatV3ProductionFlight.visibleBatMinX +
                BatV3ProductionFlight.entryExitGap,
            .001,
          ),
        );
        expect(
          BatV3ProductionFlight.leftFor(
            stageWidth: width,
            progress: 1,
            leftToRight: false,
          ),
          closeTo(
            -BatV3ProductionFlight.visibleBatMaxX -
                BatV3ProductionFlight.entryExitGap,
            .001,
          ),
        );
      }
      const base =
          (BatV3ProductionFlight.stageHeight -
              BatV3ProductionFlight.batHeight) /
          2;
      expect(BatV3ProductionFlight.topFor(0), base);
      expect(BatV3ProductionFlight.topFor(-2), base - 2);
      expect(BatV3ProductionFlight.topFor(-4), base - 4);
      expect(BatV3ProductionFlight.topFor(2), base + 2);
      expect(BatV3ProductionFlight.topFor(4), base + 4);
      expect(BatV3ProductionFlight.crossingDurations, const {
        '5000MS': 5000,
        '3600MS': 3600,
        '2800MS': 2800,
        '2200MS': 2200,
        '1800MS': 1800,
      });
    },
  );

  test(
    'Production preview keeps 4, 6, and 8px screen-space flutter phases',
    () {
      const expected = <int, List<double>>{
        4: [0, -2, -4, -2, 0, 2, 4, 2],
        6: [0, -3, -6, -3, 0, 3, 6, 3],
        8: [0, -4, -8, -4, 0, 4, 8, 4],
      };
      for (final entry in expected.entries) {
        final actual = List<double>.generate(
          8,
          (index) => BatV3ProductionFlight.flutterOffset(
            cycleIndex: index,
            amplitude: entry.key,
            enabled: true,
          ),
        );
        expect(actual, entry.value, reason: '${entry.key}px');
        final off = List<double>.generate(
          8,
          (index) => BatV3ProductionFlight.flutterOffset(
            cycleIndex: index,
            amplitude: entry.key,
            enabled: false,
          ),
        );
        expect(off, List<double>.filled(8, 0), reason: '${entry.key}px off');
      }
    },
  );
}

Widget _host() => MaterialApp(
  home: Scaffold(body: ListView(children: const [BatV3FlightMotionPoc()])),
);
Widget _productionHost() => MaterialApp(
  home: Scaffold(body: ListView(children: const [BatV3ProductionPreview()])),
);
void _viewport(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
}
