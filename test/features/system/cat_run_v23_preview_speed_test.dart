import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/cat_run_v23_production_preview.dart';
import 'package:or_app/features/system/pages/cat_run_v24_presentation.dart';

void main() {
  test(
    'FORCE GLITCH keeps every CAT on the shared 3-second progress clock',
    () {
      final plan = CatRunProductionEventPlan.forceGlitch(
        random: math.Random(7),
        direction: CatRunV23Direction.leftToRight,
      );

      expect(plan.crossings, hasLength(10));
      expect(plan.crossings.first.startedAtProgress, 0);
      expect(plan.crossings.last.startedAtProgress, .9);
      expect(plan.finalProgress, 1.9);
      expect(
        CatRunV23Travel.durationForGlobalProgress(plan.finalProgress),
        const Duration(milliseconds: 5700),
      );

      double individualProgress(int milliseconds, int index) =>
          CatRunV23Travel.globalProgressAt(
            Duration(milliseconds: milliseconds),
          ) -
          plan.crossings[index].startedAtProgress;

      expect(individualProgress(0, 0), 0);
      expect(individualProgress(750, 0), closeTo(.25, .000001));
      expect(individualProgress(1500, 0), closeTo(.5, .000001));
      expect(individualProgress(2250, 0), closeTo(.75, .000001));
      expect(individualProgress(3000, 0), closeTo(1, .000001));

      expect(individualProgress(2700, 9), 0);
      expect(individualProgress(3450, 9), closeTo(.25, .000001));
      expect(individualProgress(4200, 9), closeTo(.5, .000001));
      expect(individualProgress(4950, 9), closeTo(.75, .000001));
      expect(individualProgress(5700, 9), closeTo(1, .000001));
    },
  );

  test(
    'normal and glitch individual velocities match at every target width',
    () {
      for (final width in [320.0, 390.0, 900.0]) {
        final normalVelocity = CatRunV23Travel.velocityFor(width);
        final glitchVelocity =
            (width + CatRunV23Travel.offstagePadding * 2) /
            CatRunV23Travel.crossingDuration.inSeconds;
        expect(glitchVelocity / normalVelocity, closeTo(1, .000001));
      }
    },
  );

  testWidgets('FORCE GLITCH paints global progress through 1.9 over 5.7s', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CatRunV23ProductionPreview(random: math.Random(7))),
    );
    await tester.tap(find.byKey(const ValueKey('cat-run-v23-force-glitch')));
    await tester.pump();

    CatRunV23StagePainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('cat-run-v23-stage')),
                )
                .painter!
            as CatRunV23StagePainter;

    expect(painter().progress, closeTo(0, .000001));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(painter().progress, closeTo(.5, .01));
    await tester.pump(const Duration(milliseconds: 4200));
    expect(
      find.byKey(const ValueKey('cat-run-v23-force-glitch')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
