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
    expect(find.textContaining('125 ms'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bat-v3-production-stage')),
      findsOneWidget,
    );
    for (final key in [
      'bat-v3-production-timing-100',
      'bat-v3-production-timing-150',
      'bat-v3-production-flutter-off',
      'bat-v3-production-flutter-2',
      'bat-v3-production-speed-slow',
      'bat-v3-production-speed-fast',
      'bat-v3-production-ltr',
      'bat-v3-production-rtl',
      'bat-v3-production-restart',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: key);
    }
  });
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
