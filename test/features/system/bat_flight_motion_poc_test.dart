import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/animations_sandbox_page.dart';
import 'package:or_app/features/system/pages/bat_flight_motion_poc.dart';

void main() {
  test(
    'five source-derived frames retain source order and body registration',
    () {
      expect(BatFlightMotionSource.frames, hasLength(5));
      expect(BatFlightMotionSource.frames.map((frame) => frame.sourceIndex), [
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(
        BatFlightMotionSource.frames
            .map((frame) => frame.bodyAnchor)
            .every(
              (anchor) =>
                  (anchor - BatFlightMotionSource.bodyAnchor).distance <=
                  BatFlightMotionSource.bodyAnchorTolerance,
            ),
        isTrue,
      );
      expect(
        BatFlightMotionSource.frames.every((frame) => frame.bodyScale == 1),
        isTrue,
      );

      final bounds = BatFlightMotionSource.frames
          .map((frame) => frame.contour().getBounds())
          .toList();
      expect(bounds.map((bound) => bound.width).toSet().length, greaterThan(2));
      expect(
        bounds.map((bound) => bound.height).toSet().length,
        greaterThan(2),
      );
    },
  );

  test(
    'five frame cycle is discrete source-order ping-pong without hard reset',
    () {
      expect(BatFlightMotionSource.pingPongSequence, const [
        0,
        1,
        2,
        3,
        4,
        3,
        2,
        1,
      ]);
      expect(BatFlightMotionSource.pingPongSequence[4], 4);
      expect(BatFlightMotionSource.pingPongSequence[5], 3);
      expect(
        BatFlightMotionSource.frameDuration,
        const Duration(milliseconds: 70),
      );
    },
  );

  testWidgets(
    'motion POC selects all source frames and mirrors one vector set',
    (tester) async {
      await tester.pumpWidget(_host());
      for (var index = 0; index < 5; index++) {
        await tester.tap(find.byKey(ValueKey('bat-motion-frame-${index + 1}')));
        await tester.pump();
        expect(_mainPainter(tester).frameIndex, index);
      }
      await tester.tap(find.byKey(const ValueKey('bat-motion-direction-rtl')));
      await tester.pump();
      expect(_productionPainter(tester).leftToRight, isFalse);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('bat-motion-production-preview')),
            )
            .height,
        48,
      );
    },
  );

  testWidgets('playback traverses the source-order ping-pong cycle', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.byKey(const ValueKey('bat-motion-play-pause')));
    await tester.pump(BatFlightMotionSource.frameDuration);
    expect(_productionPainter(tester).frameIndex, 1);
    await tester.pump(BatFlightMotionSource.frameDuration * 3);
    expect(_productionPainter(tester).frameIndex, 4);
    await tester.pump(BatFlightMotionSource.frameDuration);
    expect(_productionPainter(tester).frameIndex, 3);
    await tester.tap(find.byKey(const ValueKey('bat-motion-play-pause')));
  });

  testWidgets('motion POC remains layout-safe at 320, 390, and 900', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_host());
      await tester.tap(find.byKey(const ValueKey('bat-motion-frame-4')));
      await tester.tap(find.byKey(const ValueKey('bat-motion-zoom-4')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bat-motion-production-preview')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('ANIMATIONS SANDBOX includes the isolated BAT motion POC', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 12000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const MaterialApp(home: AnimationsSandboxPage()));
    expect(find.byKey(const ValueKey('bat-motion-poc')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bat-motion-production-preview')),
      findsOneWidget,
    );
  });
}

Widget _host() => MaterialApp(
  home: Scaffold(body: ListView(children: const [BatFlightMotionPoc()])),
);

BatMotionPainter _mainPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const ValueKey('bat-motion-inspection-1')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as BatMotionPainter;

BatMotionPainter _productionPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const ValueKey('bat-motion-production-preview')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as BatMotionPainter;
