import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/animations_sandbox_page.dart';
import 'package:or_app/features/system/pages/bat_v3_flight_motion_poc.dart';
import 'package:or_app/features/system/pages/bat_v3_source_data.dart';

void main() {
  test('V3 source set fixes the supplied order, semantics, and assets', () {
    expect(BatV3SourceSet.poses, hasLength(5));
    expect(BatV3SourceSet.poses.map((pose) => pose.name), const [
      'NEUTRAL',
      'TOP INTERMEDIATE',
      'TOP',
      'BOTTOM INTERMEDIATE',
      'BOTTOM',
    ]);
    expect(BatV3SourceSet.poses.map((pose) => pose.asset), const [
      'assets/animations/sandbox/bat_v3/frame_01_neutral.jpg',
      'assets/animations/sandbox/bat_v3/frame_02_top_intermediate.jpg',
      'assets/animations/sandbox/bat_v3/frame_03_top.jpg',
      'assets/animations/sandbox/bat_v3/frame_04_bottom_intermediate.jpg',
      'assets/animations/sandbox/bat_v3/frame_05_bottom.jpg',
    ]);
  });

  test('V3 registration is whole-pose uniform scale plus translation only', () {
    for (final pose in BatV3SourceSet.poses) {
      expect(pose.scale, greaterThan(0));
      expect(pose.scale.isFinite, isTrue);
      expect(pose.translation.isFinite, isTrue);
    }
    expect(BatV3SourceSet.poses.first.scale, .90);
  });

  test('V3 uses the deliberate top and bottom stroke cycle', () {
    expect(BatV3SourceSet.cycle, const [0, 1, 2, 1, 0, 3, 4, 3]);
    expect(BatV3SourceSet.cycle.toSet(), {0, 1, 2, 3, 4});
    expect(BatV3SourceSet.cycle, isNot(const [0, 1, 2, 3, 4, 3, 2, 1]));
    expect(BatV3SourceSet.flutterOffsets, const [0, -2, -4, -2, 0, 2, 4, 2]);
  });

  testWidgets('V3 default timing and cycle playback are deterministic', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_host());
    expect(find.textContaining('PAUSED · 125 ms / POSE'), findsOneWidget);

    final restart = find.byKey(const ValueKey('bat-v3-restart'));
    await tester.ensureVisible(restart);
    await tester.tap(restart);
    await tester.pump();
    expect(find.text('FRAME 01 · NEUTRAL'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 125));
    expect(find.text('FRAME 02 · TOP INTERMEDIATE'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 125));
    expect(find.text('FRAME 03 · TOP'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 125));
    expect(find.text('FRAME 02 · TOP INTERMEDIATE'), findsWidgets);
  });

  testWidgets('V3 source inspection and flight controls are available', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_host());
    for (final view in BatV3View.values) {
      final control = find.byKey(ValueKey('bat-v3-view-${view.name}'));
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: view.name);
    }
    final crossing = find.byKey(const ValueKey('bat-v3-crossing'));
    await tester.ensureVisible(crossing);
    await tester.tap(crossing);
    await tester.pump();
    expect(find.byKey(const ValueKey('bat-v3-crossing-stage')), findsOneWidget);
    final flutterOff = find.byKey(const ValueKey('bat-v3-flutter-off'));
    await tester.ensureVisible(flutterOff);
    await tester.tap(flutterOff);
    final rtl = find.byKey(const ValueKey('bat-v3-rtl'));
    await tester.ensureVisible(rtl);
    await tester.tap(rtl);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('V3 controls remain layout safe at 320, 390, and 900', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 5000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_host());
      await tester.tap(find.byKey(const ValueKey('bat-v3-crossing')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bat-v3-crossing-stage')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets(
    'ANIMATIONS SANDBOX exposes V3 without restoring deleted CAT POCs',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(390, 16000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: AnimationsSandboxPage()));

      expect(find.byKey(const ValueKey('bat-v3-source-audit')), findsOneWidget);
      expect(find.byKey(const ValueKey('bat-v3-flap-poc')), findsOneWidget);
      expect(find.text('CAT TRACE PIPELINE POC'), findsNothing);
    },
  );
}

Widget _host() => MaterialApp(
  home: Scaffold(body: ListView(children: const [BatV3FlightMotionPoc()])),
);

void _useTallViewport(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = const Size(800, 5000);
  tester.view.devicePixelRatio = 1;
}
