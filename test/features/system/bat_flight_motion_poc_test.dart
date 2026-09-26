import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/animations_sandbox_page.dart';
import 'package:or_app/features/system/pages/bat_flight_motion_poc.dart';
import 'package:or_app/features/system/pages/bat_source_vector_rebuild_data.dart';

void main() {
  test(
    'five frozen HIGH vectors retain their source order and fidelity gates',
    () {
      final frames = BatSourceVectorRebuild.frames;

      expect(frames, hasLength(5));
      expect(frames.map((frame) => frame.sourceIndex), [1, 2, 3, 4, 5]);
      for (final frame in frames) {
        expect(frame.rawPointCount, greaterThan(frame.highPointCount));
        expect(frame.highPointCount, greaterThan(100));
        expect(
          frame.iou,
          greaterThanOrEqualTo(BatSourceVectorRebuild.minimumIou),
        );
        expect(
          frame.disagreement,
          lessThanOrEqualTo(BatSourceVectorRebuild.maximumDisagreement),
        );
      }
      expect(BatSourceVectorRebuild.allFramesPass, isTrue);
    },
  );

  test(
    'flap cycle uses every frozen HIGH frame without endpoint hard jump',
    () {
      expect(BatSourceVectorRebuild.flapSequence, const [
        0,
        1,
        2,
        3,
        4,
        3,
        2,
        1,
      ]);
      expect(BatSourceVectorRebuild.flapSequence.toSet(), {0, 1, 2, 3, 4});
      expect(BatSourceVectorRebuild.flapSequence[4], 4);
      expect(BatSourceVectorRebuild.flapSequence[5], 3);
      expect(BatSourceVectorRebuild.flapSequence.last, 1);
      expect(BatSourceVectorRebuild.defaultFlapStepMilliseconds, 70);
      expect(BatSourceVectorRebuild.flapTimingPresets, const [50, 70, 90]);
    },
  );

  test(
    'registration and body-size diagnostics do not mutate HIGH geometry',
    () {
      expect(BatSourceVectorRebuild.bodySizeDiagnostics, hasLength(5));
      for (
        var index = 0;
        index < BatSourceVectorRebuild.frames.length;
        index++
      ) {
        final frame = BatSourceVectorRebuild.frames[index];
        final highBefore = List<int>.from(frame.highPoints);
        final rawBefore = List<int>.from(frame.rawPoints);
        final diagnostic = BatSourceVectorRebuild.bodyDiagnosticFor(index);
        final painter = BatSourceVectorPainter(
          frame: frame,
          mode: BatSourceInspectionMode.registered,
          leftToRight: true,
          scale: 1,
          presentationPadding: const Offset(0, 180),
        );

        expect(painter.frame.highPoints, highBefore);
        expect(painter.frame.rawPoints, rawBefore);
        expect(BatSourceVectorFrame.uniformScale, 1.0);
        expect(frame.registrationTranslation.isFinite, isTrue);
        expect(diagnostic.headToPelvisDistance, greaterThan(0));
        expect(diagnostic.torsoLength, greaterThan(0));
      }
    },
  );

  testWidgets('playback follows the discrete 70ms ping-pong flap cycle', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_host());
    final restart = find.byKey(const ValueKey('bat-flap-restart'));
    await tester.ensureVisible(restart);
    await tester.tap(restart);
    await tester.pump();
    expect(_flapPainter(tester).frame.sourceIndex, 1);

    await tester.pump(const Duration(milliseconds: 70));
    expect(_flapPainter(tester).frame.sourceIndex, 2);
    await tester.pump(const Duration(milliseconds: 210));
    expect(_flapPainter(tester).frame.sourceIndex, 5);
    await tester.pump(const Duration(milliseconds: 70));
    expect(_flapPainter(tester).frame.sourceIndex, 4);

    final pause = find.byKey(const ValueKey('bat-flap-pause'));
    await tester.ensureVisible(pause);
    await tester.tap(pause);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_flapPainter(tester).frame.sourceIndex, 4);
  });

  testWidgets('timing presets preserve geometry, direction, and registration', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_host());
    final timing50 = find.byKey(const ValueKey('bat-flap-timing-50'));
    final restart = find.byKey(const ValueKey('bat-flap-restart'));
    final pause = find.byKey(const ValueKey('bat-flap-pause'));
    final timing90 = find.byKey(const ValueKey('bat-flap-timing-90'));
    final rtl = find.byKey(const ValueKey('bat-flap-direction-rtl'));
    await tester.ensureVisible(timing50);
    await tester.tap(timing50);
    await tester.ensureVisible(restart);
    await tester.tap(restart);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_flapPainter(tester).frame.sourceIndex, 2);

    await tester.ensureVisible(pause);
    await tester.tap(pause);
    await tester.ensureVisible(timing90);
    await tester.tap(timing90);
    await tester.ensureVisible(rtl);
    await tester.tap(rtl);
    await tester.ensureVisible(restart);
    await tester.tap(restart);
    await tester.pump(const Duration(milliseconds: 90));
    final painter = _flapPainter(tester);
    expect(painter.frame.sourceIndex, 2);
    expect(painter.leftToRight, isFalse);
    expect(painter.mode, BatSourceInspectionMode.registered);
    expect(painter.presentationPadding, const Offset(0, 180));
  });

  testWidgets(
    'manual frame controls, source audit modes, and 48px previews work',
    (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_host());

      for (var index = 0; index < 5; index++) {
        final frame = find.byKey(ValueKey('bat-flap-frame-${index + 1}'));
        await tester.ensureVisible(frame);
        await tester.tap(frame);
        await tester.pump();
        expect(_flapPainter(tester).frame.sourceIndex, index + 1);
      }

      for (final mode in BatSourceInspectionMode.values) {
        final control = find.byKey(
          ValueKey('bat-source-vector-mode-${mode.name}'),
        );
        await tester.ensureVisible(control);
        await tester.tap(control);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: mode.name);
      }

      expect(
        tester
            .getSize(find.byKey(const ValueKey('bat-flap-production-preview')))
            .height,
        48,
      );
      expect(
        find.byKey(const ValueKey('bat-source-vector-production-preview')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'source audit and flap controls remain layout-safe at 320, 390, and 900',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0, 900.0]) {
        tester.view.physicalSize = Size(width, 5000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(_host());
        final zoom = find.byKey(const ValueKey('bat-flap-zoom-4'));
        await tester.ensureVisible(zoom);
        await tester.tap(zoom);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('bat-flap-production-preview')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    },
  );

  testWidgets(
    'ANIMATIONS SANDBOX keeps source audit, flap POC, and CAT cleanup',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(390, 16000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: AnimationsSandboxPage()));

      expect(
        find.byKey(const ValueKey('bat-source-vector-rebuild-poc')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('bat-flap-cycle-poc')), findsOneWidget);
      expect(find.text('CAT TRACE PIPELINE POC'), findsNothing);
    },
  );
}

Widget _host() => MaterialApp(
  home: Scaffold(body: ListView(children: const [BatFlightMotionPoc()])),
);

void _useTallViewport(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = const Size(800, 5000);
  tester.view.devicePixelRatio = 1;
}

BatSourceVectorPainter _flapPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const ValueKey('bat-flap-production-preview')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as BatSourceVectorPainter;
