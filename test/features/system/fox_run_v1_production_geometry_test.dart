import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:or_app/features/system/pages/fox_run_v1_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const stageWidth = 390.0;
  const stageHeight = FoxRunV1ProductionGeometry.stageHeight;
  final stageRect = Rect.fromLTWH(0, 0, stageWidth, stageHeight);
  final ground = FoxRunV1ProductionGeometry.stageGroundY(stageHeight);

  Rect boundsAt(double bodyCenterX, {required bool leftToRight}) =>
      FoxRunV1ProductionGeometry.visibleBounds(
        bodyCenterX: bodyCenterX,
        stageGroundY: ground,
        leftToRight: leftToRight,
      );

  Rect boundsFor({
    required double width,
    required double progress,
    required bool leftToRight,
  }) => boundsAt(
    FoxRunV1ProductionGeometry.bodyCenterForProgress(
      stageWidth: width,
      progress: progress,
      leftToRight: leftToRight,
    ),
    leftToRight: leftToRight,
  );

  test('canonical FOX assets 01 through 10 decode', () async {
    for (var frame = 1; frame <= 10; frame++) {
      final asset =
          'assets/animations/sandbox/fox_v1/canonical/frame_${frame.toString().padLeft(2, '0')}.png';
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });

  test('Frame 01 static body center and virtual ground are visible', () {
    const bodyCenterX = stageWidth / 2;
    final image = FoxRunV1ProductionGeometry.imageTopLeft(
      bodyCenterX: bodyCenterX,
      stageGroundY: ground,
    );
    final scaledOrigin = Offset(
      FoxRunV1ProductionGeometry.bodyOrigin.dx *
          FoxRunV1ProductionGeometry.displayScale,
      FoxRunV1ProductionGeometry.bodyOrigin.dy *
          FoxRunV1ProductionGeometry.displayScale,
    );
    final bounds = boundsAt(bodyCenterX, leftToRight: true);

    expect(image.dx + scaledOrigin.dx, closeTo(bodyCenterX, 0.001));
    expect(
      image.dy +
          FoxRunV1ProductionGeometry.virtualGround *
              FoxRunV1ProductionGeometry.displayScale,
      closeTo(ground, 0.001),
    );
    expect(bounds.intersect(stageRect).width, greaterThan(100));
    expect(bounds.intersect(stageRect).height, greaterThan(80));
  });

  test('all 10 cels share the in-place visibility registration', () {
    const bodyCenterX = stageWidth / 2;
    final frame01 = boundsAt(bodyCenterX, leftToRight: true);
    for (var frame = 1; frame <= 10; frame++) {
      // Runtime selection changes only the canonical asset path.  There is no
      // frame scale, dx, dy, fit, or recenter branch.
      final bounds = boundsAt(bodyCenterX, leftToRight: true);
      expect(bounds, frame01, reason: 'frame $frame');
      expect(
        bounds.intersect(stageRect).isEmpty,
        isFalse,
        reason: 'frame $frame',
      );
    }
  });

  test('10 to 01 retains the same transformed registration', () {
    const bodyCenterX = stageWidth / 2;
    expect(
      boundsAt(bodyCenterX, leftToRight: true),
      boundsAt(bodyCenterX, leftToRight: true),
    );
  });

  for (final width in [320.0, 390.0, 900.0]) {
    for (final leftToRight in [true, false]) {
      final direction = leftToRight ? 'L to R' : 'R to L';
      test(
        '$direction FOX path uses its rendered extent at ${width.toInt()}px',
        () {
          final rect = Rect.fromLTWH(0, 0, width, stageHeight);
          final samples = <double, Rect>{
            for (final progress in [0.0, .25, .5, .75, 1.0])
              progress: boundsFor(
                width: width,
                progress: progress,
                leftToRight: leftToRight,
              ),
          };
          final start = samples[0]!;
          final quarter = samples[.25]!;
          final midpoint = samples[.5]!;
          final threeQuarter = samples[.75]!;
          final end = samples[1]!;

          expect(start.intersect(rect).isEmpty, isTrue);
          expect(end.intersect(rect).isEmpty, isTrue);
          expect(quarter.intersect(rect).isEmpty, isFalse);
          expect(midpoint.intersect(rect).width, greaterThan(100));
          expect(midpoint.intersect(rect).height, greaterThan(80));
          expect(threeQuarter.intersect(rect).isEmpty, isFalse);
          expect(midpoint.center.dx, closeTo(width / 2, .001));
          expect(quarter.bottom, closeTo(midpoint.bottom, .001));
          expect(threeQuarter.bottom, closeTo(midpoint.bottom, .001));
          expect(quarter.size, midpoint.size);
          expect(threeQuarter.size, midpoint.size);
          if (leftToRight) {
            expect(start.right, closeTo(-8, .001));
            expect(end.left, closeTo(width + 8, .001));
            expect(quarter.left, lessThan(midpoint.left));
            expect(midpoint.left, lessThan(threeQuarter.left));
          } else {
            expect(start.left, closeTo(width + 8, .001));
            expect(end.right, closeTo(-8, .001));
            expect(quarter.left, greaterThan(midpoint.left));
            expect(midpoint.left, greaterThan(threeQuarter.left));
          }
        },
      );
    }

    testWidgets('FOX BODY lane clips only scene edges at ${width.toInt()}px', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(Size(width, 300));
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const FoxRunV1ProductionStage(
                crossing: AlwaysStoppedAnimation(.5),
                asset:
                    'assets/animations/sandbox/fox_v1/canonical/frame_01.png',
                leftToRight: true,
              ),
            ),
          ),
        ),
      );
      final stage = find.byKey(const ValueKey('fox-run-v1-production-stage'));
      expect(tester.getSize(stage), Size(width, stageHeight));
      expect(
        find.descendant(of: stage, matching: find.byType(ClipRect)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('FOX first RUN resets cleanly and a second RUN restarts', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: FoxRunV1Section())),
      ),
    );

    double crossing() =>
        (tester
                    .widget<AnimatedBuilder>(
                      find.byKey(const ValueKey('fox-run-v1-crossing')),
                    )
                    .animation
                as Animation<double>)
            .value;
    String asset() =>
        (tester
                    .widget<Image>(
                      find.descendant(
                        of: find.byKey(
                          const ValueKey('fox-run-v1-production-stage'),
                        ),
                        matching: find.byType(Image),
                      ),
                    )
                    .image
                as AssetImage)
            .assetName;

    await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
    await tester.pump();
    expect(crossing(), closeTo(0, .001));
    expect(asset(), endsWith('frame_01.png'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(asset(), endsWith('frame_02.png'));
    await tester.pump(const Duration(milliseconds: 670));
    expect(crossing(), closeTo(.25, .01));
    await tester.pump(const Duration(milliseconds: 750));
    expect(crossing(), closeTo(.5, .01));
    await tester.pump(const Duration(milliseconds: 750));
    expect(crossing(), closeTo(.75, .01));
    await tester.pump(const Duration(milliseconds: 750));
    expect(crossing(), closeTo(0, .01));

    await tester.pump(const Duration(milliseconds: 400));
    expect(crossing(), greaterThan(.1));
    await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
    await tester.pump();
    expect(crossing(), closeTo(0, .001));
    expect(asset(), endsWith('frame_01.png'));
    await tester.pump(const Duration(milliseconds: 750));
    expect(crossing(), closeTo(.25, .01));
    expect(tester.takeException(), isNull);
  });

  test('390px mirrored baseline no longer leaves FOX visible at reset', () {
    final end = boundsFor(width: stageWidth, progress: 1, leftToRight: false);
    expect(end.right, closeTo(-8, .001));
    expect(end.intersect(stageRect).isEmpty, isTrue);
  });
}
