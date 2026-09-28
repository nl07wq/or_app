import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:or_app/features/system/pages/ambient_wildlife_v2.dart';
import 'package:or_app/features/system/pages/cat_run_coat_patterns.dart';
import 'package:or_app/features/system/pages/fox_run_v1_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const stageWidth = 390.0;
  const stageHeight = FoxRunV1ProductionGeometry.stageHeight;
  final stageRect = Rect.fromLTWH(0, 0, stageWidth, stageHeight);
  final ground = FoxRunV1ProductionGeometry.stageGroundY(stageHeight);

  Rect boundsAt(
    double bodyCenterX, {
    required bool leftToRight,
    double bodyScale = 1,
  }) => FoxRunV1ProductionGeometry.visibleBounds(
    bodyCenterX: bodyCenterX,
    stageGroundY: ground,
    leftToRight: leftToRight,
    bodyScale: bodyScale,
  );

  Rect boundsFor({
    required double width,
    required double progress,
    required bool leftToRight,
    double bodyScale = 1,
  }) => boundsAt(
    FoxRunV1ProductionGeometry.bodyCenterForProgress(
      stageWidth: width,
      progress: progress,
      leftToRight: leftToRight,
      bodyScale: bodyScale,
    ),
    leftToRight: leftToRight,
    bodyScale: bodyScale,
  );

  Future<void> pumpPreview(WidgetTester tester, double width) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(Size(width, 1400));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: FoxRunV1Section())),
      ),
    );
  }

  Animation<double> crossingAnimation(WidgetTester tester) =>
      tester
              .widget<AnimatedBuilder>(
                find.byKey(const ValueKey('fox-run-v1-crossing')),
              )
              .animation
          as Animation<double>;

  String displayedAsset(WidgetTester tester) =>
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

  double bodyFlexGroundAnchorY(WidgetTester tester) {
    final image = find.descendant(
      of: find.byKey(const ValueKey('fox-run-v1-production-stage')),
      matching: find.byType(Image),
    );
    final box = tester.renderObject<RenderBox>(image);
    return box
        .localToGlobal(
          Offset(
            0,
            box.size.height *
                (FoxRunV1ProductionGeometry.virtualGround /
                    FoxRunV1ProductionGeometry.canvasSize.height),
          ),
        )
        .dy;
  }

  double bodyFlexTorsoAnchorY(WidgetTester tester) {
    final image = find.descendant(
      of: find.byKey(const ValueKey('fox-run-v1-production-stage')),
      matching: find.byType(Image),
    );
    final box = tester.renderObject<RenderBox>(image);
    return box
        .localToGlobal(
          Offset(
            0,
            box.size.height *
                (FoxRunV1ProductionGeometry.bodyOrigin.dy /
                    FoxRunV1ProductionGeometry.canvasSize.height),
          ),
        )
        .dy;
  }

  test('canonical FOX assets 01 through 10 decode', () async {
    for (var frame = 1; frame <= 10; frame++) {
      final asset =
          'assets/animations/sandbox/fox_v1/canonical/frame_${frame.toString().padLeft(2, '0')}.png';
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 1646, reason: asset);
      expect(image.height, 783, reason: asset);
      image.dispose();
      codec.dispose();
    }
  });

  test('historical FOX scale replaces the enlarged 110px torso', () {
    expect(FoxRunV1ProductionGeometry.scaledCanvas.width, closeTo(220, .001));
    expect(
      FoxRunV1ProductionGeometry.displayedTorsoLength,
      closeTo(68.9672, .001),
    );
    expect(
      FoxRunV1ProductionGeometry.displayedTorsoLength /
          FoxRunV1ProductionGeometry.previousDisplayedTorsoLength,
      closeTo(.62697, .001),
    );
  });

  test('FOX preview uses the CAT environment and silhouette references', () {
    expect(
      FoxRunV1ProductionStage.previewBackgroundColor,
      AmbientWildlifeV2Stage.environmentBackground,
    );
    expect(
      FoxRunV1ProductionStage.silhouetteColor,
      CatRunCoatPatterns.baseColor,
    );
    expect(FoxRunV1ProductionGeometry.groundInset, 28);
    expect(FoxRunV1ProductionGeometry.groundVerticalOffset, 2);
  });

  testWidgets('FOX production stage renders the CAT visual treatment', (
    tester,
  ) async {
    await pumpPreview(tester, 390);
    final stage = find.byKey(const ValueKey('fox-run-v1-production-stage'));
    final background = tester.widget<ColoredBox>(
      find.descendant(of: stage, matching: find.byType(ColoredBox)).first,
    );
    final silhouette = tester.widget<ColorFiltered>(
      find.descendant(of: stage, matching: find.byType(ColorFiltered)).first,
    );
    expect(background.color, FoxRunV1ProductionStage.previewBackgroundColor);
    expect(
      silhouette.colorFilter,
      const ColorFilter.mode(
        FoxRunV1ProductionStage.silhouetteColor,
        BlendMode.srcIn,
      ),
    );
    expect(
      find.descendant(of: stage, matching: find.byType(ColorFiltered)),
      findsOneWidget,
    );
  });

  test('FOX pattern uses restrained tones around the base silhouette', () {
    expect(FoxRunV1ProductionStage.silhouetteColor, const Color(0xFF7A7A7A));
    expect(FoxRunV1ProductionStage.patternLightColor, const Color(0xFF9F9F9F));
    expect(FoxRunV1ProductionStage.patternDarkColor, const Color(0xFF535353));
  });

  testWidgets('FOX pattern is alpha-clipped in canonical local coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 390,
          child: FoxRunV1ProductionStage(
            crossing: AlwaysStoppedAnimation(.5),
            asset: 'assets/animations/sandbox/fox_v1/canonical/frame_01.png',
            leftToRight: true,
            pattern: FoxRunV1Pattern.fox,
          ),
        ),
      ),
    );

    final stage = find.byKey(const ValueKey('fox-run-v1-production-stage'));
    final base = find.byKey(const ValueKey('fox-run-v1-pattern-base'));
    expect(base, findsOneWidget);
    expect(
      tester.widget<ColorFiltered>(base).colorFilter,
      const ColorFilter.mode(
        FoxRunV1ProductionStage.silhouetteColor,
        BlendMode.srcIn,
      ),
    );
    const regions = <String, Color>{
      'fox-run-v1-pattern-tail-tip': FoxRunV1ProductionStage.patternLightColor,
      'fox-run-v1-pattern-jaw-throat':
          FoxRunV1ProductionStage.patternLightColor,
      'fox-run-v1-pattern-feet': FoxRunV1ProductionStage.patternDarkColor,
    };
    final canvasRect = Offset.zero & FoxRunV1ProductionGeometry.canvasSize;
    for (final entry in regions.entries) {
      final region = find.byKey(ValueKey(entry.key));
      expect(region, findsOneWidget);
      final clipPath = tester.widget<ClipPath>(region);
      final clipBounds = clipPath.clipper!
          .getClip(FoxRunV1ProductionGeometry.canvasSize)
          .getBounds();
      expect(canvasRect.contains(clipBounds.topLeft), isTrue);
      expect(canvasRect.contains(clipBounds.bottomRight), isTrue);
      final filter = tester.widget<ColorFiltered>(
        find.descendant(of: region, matching: find.byType(ColorFiltered)),
      );
      expect(
        filter.colorFilter,
        ColorFilter.mode(entry.value, BlendMode.srcIn),
      );
      expect(
        find.descendant(of: region, matching: find.byType(Image)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: stage, matching: find.byType(Image)),
      findsNWidgets(4),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FOX pattern supports every frame, size, and direction', (
    tester,
  ) async {
    for (var frame = 1; frame <= 10; frame++) {
      final asset =
          'assets/animations/sandbox/fox_v1/canonical/frame_${frame.toString().padLeft(2, '0')}.png';
      for (final leftToRight in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 390,
              child: FoxRunV1ProductionStage(
                crossing: const AlwaysStoppedAnimation(.5),
                asset: asset,
                leftToRight: leftToRight,
                pattern: FoxRunV1Pattern.fox,
              ),
            ),
          ),
        );
        final images = find.descendant(
          of: find.byKey(const ValueKey('fox-run-v1-production-stage')),
          matching: find.byType(Image),
        );
        expect(images, findsNWidgets(4));
        for (final image in tester.widgetList<Image>(images)) {
          expect((image.image as AssetImage).assetName, asset);
        }
        final transform = tester.widget<Transform>(
          find.byKey(const ValueKey('fox-run-v1-body-flex')),
        );
        expect(transform.transform.storage[0], leftToRight ? 1 : -1);
        expect(tester.takeException(), isNull);
      }
    }

    for (final bodyScale in [.5, .7, 1.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 390,
            child: FoxRunV1ProductionStage(
              crossing: const AlwaysStoppedAnimation(.5),
              asset: 'assets/animations/sandbox/fox_v1/canonical/frame_01.png',
              leftToRight: true,
              bodyScale: bodyScale,
              verticalFlutterOffset: 1,
              bodyFlexOffset: 4,
              pattern: FoxRunV1Pattern.fox,
            ),
          ),
        ),
      );
      final base = find.byKey(const ValueKey('fox-run-v1-pattern-base'));
      expect(
        tester.getSize(base),
        FoxRunV1ProductionGeometry.scaledCanvasFor(bodyScale),
      );
      for (final key in [
        'fox-run-v1-pattern-tail-tip',
        'fox-run-v1-pattern-jaw-throat',
        'fox-run-v1-pattern-feet',
      ]) {
        expect(tester.getSize(find.byKey(ValueKey(key))), tester.getSize(base));
      }
      expect(tester.takeException(), isNull);
    }
  });

  test('RUN cadence follows ordered frames on the crossing timeline', () {
    expect(FoxRunV1Motion.frameCount, 10);
    expect(FoxRunV1Motion.frameDuration, const Duration(milliseconds: 80));
    expect(FoxRunV1Motion.cycleDuration, const Duration(milliseconds: 800));
    expect(FoxRunV1Motion.crossingDuration, const Duration(milliseconds: 2200));
    for (final milliseconds in [60, 80, 100]) {
      expect(
        FoxRunV1Motion.durationForCycles(
          4,
          celDuration: Duration(milliseconds: milliseconds),
        ),
        Duration(milliseconds: milliseconds * 10 * 4),
      );
    }
    for (var cycle = 0; cycle < 2; cycle++) {
      for (var frame = 0; frame < 10; frame++) {
        final elapsedMilliseconds = cycle * 800 + frame * 80;
        expect(
          FoxRunV1Motion.frameAtCrossingProgress(elapsedMilliseconds / 2200),
          frame,
          reason: '${elapsedMilliseconds}ms',
        );
      }
    }
    expect(FoxRunV1Motion.frameAtCrossingProgress(.999999), 7);
    expect(FoxRunV1Motion.frameAtCrossingProgress(0), 0);
  });

  test('diagnostic speeds use the requested V2 durations and ordering', () {
    expect(
      FoxRunV1Motion.durationForSpeed(FoxRunV1Speed.slow),
      const Duration(milliseconds: 3200),
    );
    expect(
      FoxRunV1Motion.durationForSpeed(FoxRunV1Speed.current),
      FoxRunV1Motion.crossingDuration,
    );
    expect(
      FoxRunV1Motion.durationForSpeed(FoxRunV1Speed.current),
      const Duration(milliseconds: 2200),
    );
    expect(
      FoxRunV1Motion.durationForSpeed(FoxRunV1Speed.fast),
      const Duration(milliseconds: 2000),
    );
    expect(
      FoxRunV1Motion.durationForSpeed(FoxRunV1Speed.faster),
      const Duration(milliseconds: 1800),
    );
    expect(
      FoxRunV1Motion.durationForSpeed(FoxRunV1Speed.fastest),
      const Duration(milliseconds: 1600),
    );
    expect(
      FoxRunV1Motion.durationForSpeed(FoxRunV1Speed.maximum),
      const Duration(milliseconds: 1400),
    );
    expect(
      FoxRunV1Motion.durationForSpeed(FoxRunV1Speed.over),
      const Duration(milliseconds: 1200),
    );
    final durations = FoxRunV1Speed.values
        .map(FoxRunV1Motion.durationForSpeed)
        .toList();
    for (var index = 1; index < durations.length; index++) {
      expect(durations[index], lessThan(durations[index - 1]));
    }
  });

  test('selected frames repeat in canonical order at the 80ms cadence', () {
    const selected = [2, 5, 7];
    for (final speed in FoxRunV1Speed.values) {
      final duration = FoxRunV1Motion.durationForSpeed(speed);
      for (final sample in <(int, int)>[(0, 2), (80, 5), (160, 7), (240, 2)]) {
        expect(
          FoxRunV1Motion.frameAtCrossingProgress(
            sample.$1 / duration.inMilliseconds,
            runDuration: duration,
            selectedFrames: selected,
          ),
          sample.$2,
          reason: '${speed.name} at ${sample.$1}ms',
        );
      }
    }
    expect(
      FoxRunV1Motion.frameAtCrossingProgress(.5, selectedFrames: const [4]),
      4,
    );
    expect(
      [
        for (var milliseconds = 0; milliseconds < 480; milliseconds += 80)
          FoxRunV1Motion.frameAtElapsed(
            Duration(milliseconds: milliseconds),
            selectedFrames: const [0, 2, 4, 5, 6],
          ),
      ],
      [0, 2, 4, 5, 6, 0],
    );
  });

  test('BODY SIZE 0.5x and 0.7x derive from the deployed 1x geometry', () {
    final full = FoxRunV1ProductionGeometry.scaledCanvasFor(1);
    final half = FoxRunV1ProductionGeometry.scaledCanvasFor(.5);
    final sevenTenths = FoxRunV1ProductionGeometry.scaledCanvasFor(.7);
    expect(full, FoxRunV1ProductionGeometry.scaledCanvas);
    expect(full.width, closeTo(220, .001));
    expect(full.height, closeTo(104.6537, .001));
    expect(half.width, closeTo(full.width * .5, .001));
    expect(half.height, closeTo(full.height * .5, .001));
    expect(sevenTenths.width, closeTo(full.width * .7, .001));
    expect(sevenTenths.height, closeTo(full.height * .7, .001));
    expect(
      FoxRunV1ProductionGeometry.displayedTorsoLengthFor(.5),
      closeTo(FoxRunV1ProductionGeometry.displayedTorsoLengthFor(1) * .5, .001),
    );
    expect(
      FoxRunV1ProductionGeometry.displayedTorsoLengthFor(.7),
      closeTo(FoxRunV1ProductionGeometry.displayedTorsoLengthFor(1) * .7, .001),
    );
    expect(FoxRunV1ProductionGeometry.scaleFor(FoxRunV1BodySize.half), .5);
    expect(
      FoxRunV1ProductionGeometry.scaleFor(FoxRunV1BodySize.sevenTenths),
      .7,
    );
    expect(FoxRunV1ProductionGeometry.scaleFor(FoxRunV1BodySize.full), 1);
  });

  test('vertical flutter uses the requested BAT-style 8-phase amplitudes', () {
    expect(FoxRunV1Motion.flutterAmplitude(FoxRunV1VerticalFlutter.off), 0);
    expect(FoxRunV1Motion.flutterAmplitude(FoxRunV1VerticalFlutter.half), .5);
    expect(FoxRunV1Motion.flutterAmplitude(FoxRunV1VerticalFlutter.one), 1);
    expect(FoxRunV1Motion.flutterAmplitude(FoxRunV1VerticalFlutter.two), 2);
    const expectedOffsets = {
      FoxRunV1VerticalFlutter.off: [0, 0, 0, 0, 0, 0, 0, 0],
      FoxRunV1VerticalFlutter.half: [0, -.25, -.5, -.25, 0, .25, .5, .25],
      FoxRunV1VerticalFlutter.one: [0, -.5, -1, -.5, 0, .5, 1, .5],
      FoxRunV1VerticalFlutter.two: [0, -1, -2, -1, 0, 1, 2, 1],
    };
    for (final verticalFlutter in FoxRunV1VerticalFlutter.values) {
      expect([
        for (var phase = 0; phase < 8; phase++)
          FoxRunV1Motion.verticalFlutterOffset(
            phase: phase,
            amplitude: FoxRunV1Motion.flutterAmplitude(verticalFlutter),
          ),
      ], expectedOffsets[verticalFlutter]);
    }
    expect(FoxRunV1Motion.flutterLabel(FoxRunV1VerticalFlutter.off), 'OFF');
    expect(FoxRunV1Motion.flutterLabel(FoxRunV1VerticalFlutter.half), '0.5px');
    expect(FoxRunV1Motion.flutterLabel(FoxRunV1VerticalFlutter.one), '1px');
    expect(FoxRunV1Motion.flutterLabel(FoxRunV1VerticalFlutter.two), '2px');
    expect(
      FoxRunV1Motion.flutterPhaseAtElapsed(const Duration(milliseconds: 640)),
      0,
    );
  });

  test('body flex exposes unilateral and shrink-enabled 8-phase waves', () {
    const unilateralOffsets = <FoxRunV1BodyFlex, List<double>>{
      FoxRunV1BodyFlex.off: [0, 0, 0, 0, 0, 0, 0, 0],
      FoxRunV1BodyFlex.half: [0, .25, .5, .25, 0, 0, 0, 0],
      FoxRunV1BodyFlex.one: [0, .5, 1, .5, 0, 0, 0, 0],
      FoxRunV1BodyFlex.two: [0, 1, 2, 1, 0, 0, 0, 0],
      FoxRunV1BodyFlex.four: [0, 2, 4, 2, 0, 0, 0, 0],
    };
    const bilateralOffsets = <FoxRunV1BodyFlex, List<double>>{
      FoxRunV1BodyFlex.off: [0, 0, 0, 0, 0, 0, 0, 0],
      FoxRunV1BodyFlex.half: [0, .25, .5, .25, 0, -.25, -.5, -.25],
      FoxRunV1BodyFlex.one: [0, .5, 1, .5, 0, -.5, -1, -.5],
      FoxRunV1BodyFlex.two: [0, 1, 2, 1, 0, -1, -2, -1],
      FoxRunV1BodyFlex.four: [0, 2, 4, 2, 0, -2, -4, -2],
    };
    for (final bodyFlex in FoxRunV1BodyFlex.values) {
      expect([
        for (var phase = 0; phase < 8; phase++)
          FoxRunV1Motion.bodyFlexOffset(
            phase: phase,
            amplitude: FoxRunV1Motion.bodyFlexAmplitude(bodyFlex),
          ),
      ], unilateralOffsets[bodyFlex]);
      expect([
        for (var phase = 0; phase < 8; phase++)
          FoxRunV1Motion.bodyFlexOffset(
            phase: phase,
            amplitude: FoxRunV1Motion.bodyFlexAmplitude(bodyFlex),
            shrinkEnabled: true,
          ),
      ], bilateralOffsets[bodyFlex]);
    }
    expect(FoxRunV1Motion.bodyFlexLabel(FoxRunV1BodyFlex.off), 'OFF');
    expect(FoxRunV1Motion.bodyFlexLabel(FoxRunV1BodyFlex.half), '0.5px');
    expect(FoxRunV1Motion.bodyFlexLabel(FoxRunV1BodyFlex.one), '1px');
    expect(FoxRunV1Motion.bodyFlexLabel(FoxRunV1BodyFlex.two), '2px');
    expect(FoxRunV1Motion.bodyFlexLabel(FoxRunV1BodyFlex.four), '4px');
  });

  test('BODY FLEX motion modes preserve amplitude and smooth phase motion', () {
    const amplitude = 4.0;
    for (final shrinkEnabled in [false, true]) {
      final current = [
        for (var phase = 0; phase < 8; phase++)
          FoxRunV1Motion.bodyFlexOffsetAtElapsed(
            elapsed: Duration(milliseconds: phase * 80),
            amplitude: amplitude,
            motion: FoxRunV1BodyFlexMotion.current,
            shrinkEnabled: shrinkEnabled,
          ),
      ];
      expect(
        current,
        shrinkEnabled ? [0, 2, 4, 2, 0, -2, -4, -2] : [0, 2, 4, 2, 0, 0, 0, 0],
      );

      for (final motion in [
        FoxRunV1BodyFlexMotion.smooth,
        FoxRunV1BodyFlexMotion.hold,
      ]) {
        final samples = [
          for (var milliseconds = 0; milliseconds < 640; milliseconds++)
            FoxRunV1Motion.bodyFlexOffsetAtElapsed(
              elapsed: Duration(milliseconds: milliseconds),
              amplitude: amplitude,
              motion: motion,
              shrinkEnabled: shrinkEnabled,
            ),
        ];
        expect(samples.reduce((a, b) => a > b ? a : b), closeTo(4, .001));
        expect(samples.every((value) => value.abs() <= 4), isTrue);
        expect(
          samples.reduce((a, b) => a < b ? a : b),
          shrinkEnabled ? closeTo(-4, .001) : greaterThanOrEqualTo(0),
        );
        expect(
          FoxRunV1Motion.bodyFlexOffsetAtElapsed(
            elapsed: const Duration(microseconds: 159999),
            amplitude: amplitude,
            motion: motion,
            shrinkEnabled: shrinkEnabled,
          ),
          closeTo(4, .01),
        );
        expect(
          FoxRunV1Motion.bodyFlexOffsetAtElapsed(
            elapsed: const Duration(milliseconds: 160, microseconds: 1),
            amplitude: amplitude,
            motion: motion,
            shrinkEnabled: shrinkEnabled,
          ),
          closeTo(4, .01),
        );
      }
    }
  });

  test('HOLD retains each peak for 40ms without changing the 640ms cycle', () {
    expect(
      FoxRunV1Motion.bodyFlexPeakHoldDuration,
      const Duration(milliseconds: 40),
    );
    expect(
      FoxRunV1Motion.bodyFlexOffsetAtElapsed(
        elapsed: const Duration(milliseconds: 140),
        amplitude: 4,
        motion: FoxRunV1BodyFlexMotion.smooth,
      ),
      lessThan(4),
    );
    for (final shrinkEnabled in [false, true]) {
      for (final milliseconds in [140, 150, 160, 170, 180]) {
        expect(
          FoxRunV1Motion.bodyFlexOffsetAtElapsed(
            elapsed: Duration(milliseconds: milliseconds),
            amplitude: 4,
            motion: FoxRunV1BodyFlexMotion.hold,
            shrinkEnabled: shrinkEnabled,
          ),
          closeTo(4, .001),
        );
      }
      expect(
        FoxRunV1Motion.bodyFlexOffsetAtElapsed(
          elapsed: const Duration(milliseconds: 640),
          amplitude: 4,
          motion: FoxRunV1BodyFlexMotion.hold,
          shrinkEnabled: shrinkEnabled,
        ),
        0,
      );
    }
    for (final milliseconds in [460, 470, 480, 490, 500]) {
      expect(
        FoxRunV1Motion.bodyFlexOffsetAtElapsed(
          elapsed: Duration(milliseconds: milliseconds),
          amplitude: 4,
          motion: FoxRunV1BodyFlexMotion.hold,
          shrinkEnabled: true,
        ),
        closeTo(-4, .001),
      );
    }
  });

  test('body flex keeps virtual ground fixed at every BODY SIZE', () {
    for (final bodyScale in [.5, .7, 1.0]) {
      final torsoFromAnchor =
          (FoxRunV1ProductionGeometry.bodyOrigin.dy -
              FoxRunV1ProductionGeometry.virtualGround) *
          FoxRunV1ProductionGeometry.displayScale *
          bodyScale;
      for (final flex in [-4.0, -2.0, -1.0, -.5, 0.0, .5, 1.0, 2.0, 4.0]) {
        final scale = FoxRunV1ProductionGeometry.bodyFlexScale(
          bodyScale: bodyScale,
          bodyFlexOffset: flex,
        );
        expect(0 * scale, 0, reason: 'ground contact is the transform anchor');
        expect(torsoFromAnchor * scale - torsoFromAnchor, closeTo(-flex, .001));
      }
    }
  });

  test('Frame 01 static body center and virtual ground are visible', () {
    expect(FoxRunV1ProductionGeometry.groundVerticalOffset, 2);
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
      closeTo(ground + FoxRunV1ProductionGeometry.groundVerticalOffset, 0.001),
    );
    expect(bounds.intersect(stageRect).width, greaterThan(190));
    expect(bounds.intersect(stageRect).height, greaterThan(78));
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
          expect(midpoint.intersect(rect).width, greaterThan(190));
          expect(midpoint.intersect(rect).height, greaterThan(78));
          expect(threeQuarter.intersect(rect).isEmpty, isFalse);
          expect(midpoint.center.dx, closeTo(width / 2, .001));
          expect(quarter.bottom, closeTo(midpoint.bottom, .001));
          expect(threeQuarter.bottom, closeTo(midpoint.bottom, .001));
          expect(quarter.width, closeTo(midpoint.width, .001));
          expect(quarter.height, closeTo(midpoint.height, .001));
          expect(threeQuarter.width, closeTo(midpoint.width, .001));
          expect(threeQuarter.height, closeTo(midpoint.height, .001));
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

  test('all BODY SIZE values keep ground registration and extent exits', () {
    for (final width in [320.0, 390.0, 900.0]) {
      for (final bodyScale in [.5, .7, 1.0]) {
        for (final leftToRight in [true, false]) {
          final start = boundsFor(
            width: width,
            progress: 0,
            leftToRight: leftToRight,
            bodyScale: bodyScale,
          );
          final end = boundsFor(
            width: width,
            progress: 1,
            leftToRight: leftToRight,
            bodyScale: bodyScale,
          );
          final center = FoxRunV1ProductionGeometry.bodyCenterForProgress(
            stageWidth: width,
            progress: .5,
            leftToRight: leftToRight,
            bodyScale: bodyScale,
          );
          final image = FoxRunV1ProductionGeometry.imageTopLeft(
            bodyCenterX: center,
            stageGroundY: ground,
            bodyScale: bodyScale,
          );
          expect(
            image.dy +
                FoxRunV1ProductionGeometry.virtualGround *
                    FoxRunV1ProductionGeometry.displayScale *
                    bodyScale,
            closeTo(
              ground + FoxRunV1ProductionGeometry.groundVerticalOffset,
              .001,
            ),
          );
          if (leftToRight) {
            expect(start.right, closeTo(-8, .001));
            expect(end.left, closeTo(width + 8, .001));
          } else {
            expect(start.left, closeTo(width + 8, .001));
            expect(end.right, closeTo(-8, .001));
          }
        }
      }
    }
  });

  testWidgets('diagnostic controls expose the requested defaults', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      await pumpPreview(tester, width);
      final fastest = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('fox-preview-speed-fastest')),
      );
      expect(fastest.selected, isTrue, reason: '${width.toInt()}px');
      for (final speed in FoxRunV1Speed.values) {
        expect(
          find.byKey(ValueKey('fox-preview-speed-${speed.name}')),
          findsOneWidget,
          reason: '${speed.name} at ${width.toInt()}px',
        );
      }
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('fox-preview-body-size-full')),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('fox-preview-vertical-flutter-off')),
            )
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('fox-preview-vertical-flutter-one')),
            )
            .selected,
        isTrue,
      );
      const flutterLabels = {
        'off': 'OFF',
        'half': '0.5px',
        'one': '1px',
        'two': '2px',
      };
      for (final entry in flutterLabels.entries) {
        final chip = tester.widget<ChoiceChip>(
          find.byKey(ValueKey('fox-preview-vertical-flutter-${entry.key}')),
        );
        expect((chip.label as Text).data, entry.value);
      }
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('fox-preview-body-flex-off')),
            )
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('fox-preview-body-flex-two')),
            )
            .selected,
        isTrue,
      );
      const bodyFlexLabels = {
        'off': 'OFF',
        'half': '0.5px',
        'one': '1px',
        'two': '2px',
        'four': '4px',
      };
      for (final entry in bodyFlexLabels.entries) {
        final chip = tester.widget<ChoiceChip>(
          find.byKey(ValueKey('fox-preview-body-flex-${entry.key}')),
        );
        expect((chip.label as Text).data, entry.value);
      }
      expect(
        find.byKey(const ValueKey('fox-preview-body-flex-six')),
        findsNothing,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('fox-preview-body-flex-motion-smooth')),
            )
            .selected,
        isTrue,
      );
      for (final motion in FoxRunV1BodyFlexMotion.values) {
        expect(
          find.byKey(ValueKey('fox-preview-body-flex-motion-${motion.name}')),
          findsOneWidget,
        );
      }
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('fox-preview-body-shrink-off')),
            )
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('fox-preview-body-shrink-on')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('fox-preview-pattern-off')),
            )
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('fox-preview-pattern-fox')),
        findsOneWidget,
      );
      expect(find.textContaining('FASTEST: canonical FOX'), findsOneWidget);
      expect(find.textContaining('1600ms crossing'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('fox-preview-vertical-flutter-four')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('fox-preview-vertical-flutter-six')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('fox-preview-body-size-sevenTenths')),
        findsOneWidget,
      );
      const defaultFrames = {1, 3, 5, 6, 7};
      for (var frame = 1; frame <= 10; frame++) {
        expect(
          tester
              .widget<FilterChip>(
                find.byKey(ValueKey('fox-preview-frame-$frame')),
              )
              .selected,
          defaultFrames.contains(frame),
          reason: 'frame $frame at ${width.toInt()}px',
        );
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey('fox-run-v1-production-stage')))
            .height,
        FoxRunV1ProductionGeometry.stageHeight,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('speed controls alter travel only and retain 80ms cadence', (
    tester,
  ) async {
    for (final speed in FoxRunV1Speed.values) {
      await pumpPreview(tester, 390);
      if (speed != FoxRunV1Speed.fastest) {
        await tester.tap(
          find.byKey(ValueKey('fox-preview-speed-${speed.name}')),
        );
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
      await tester.pump();
      expect(displayedAsset(tester), endsWith('frame_01.png'));
      await tester.pump(const Duration(milliseconds: 80));
      expect(displayedAsset(tester), endsWith('frame_03.png'));
      await tester.pump(const Duration(milliseconds: 320));
      expect(
        crossingAnimation(tester).value,
        closeTo(
          400 / FoxRunV1Motion.durationForSpeed(speed).inMilliseconds,
          .01,
        ),
        reason: speed.name,
      );
    }
  });

  testWidgets('all SPEED values update an active RUN without reset', (
    tester,
  ) async {
    for (final speed in FoxRunV1Speed.values) {
      await pumpPreview(tester, 390);
      await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 440));
      final before = crossingAnimation(tester).value;
      expect(before, closeTo(440 / 1600, .01));

      await tester.tap(find.byKey(ValueKey('fox-preview-speed-${speed.name}')));
      await tester.pump();
      expect(
        crossingAnimation(tester).value,
        closeTo(before, .001),
        reason: '${speed.name} preserves normalized progress',
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        crossingAnimation(tester).value,
        closeTo(
          before + 120 / FoxRunV1Motion.durationForSpeed(speed).inMilliseconds,
          .01,
        ),
        reason: '${speed.name} applies immediately',
      );
    }
  });

  testWidgets('FOX pattern applies live without restarting the active RUN', (
    tester,
  ) async {
    await pumpPreview(tester, 390);
    await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final before = crossingAnimation(tester).value;
    final frameBefore = displayedAsset(tester);

    await tester.tap(find.byKey(const ValueKey('fox-preview-pattern-fox')));
    await tester.pump();
    expect(crossingAnimation(tester).value, closeTo(before, .001));
    expect(
      (tester
                  .widget<Image>(
                    find.descendant(
                      of: find.byKey(const ValueKey('fox-run-v1-pattern-base')),
                      matching: find.byType(Image),
                    ),
                  )
                  .image
              as AssetImage)
          .assetName,
      frameBefore,
    );
    expect(
      find.byKey(const ValueKey('fox-run-v1-pattern-tail-tip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('fox-run-v1-pattern-jaw-throat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('fox-run-v1-pattern-feet')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('fox-preview-pattern-off')));
    await tester.pump();
    expect(crossingAnimation(tester).value, closeTo(before, .001));
    expect(displayedAsset(tester), frameBefore);
    expect(
      find.byKey(const ValueKey('fox-run-v1-pattern-tail-tip')),
      findsNothing,
    );
  });

  testWidgets('frame selection updates an active RUN without restarting', (
    tester,
  ) async {
    await pumpPreview(tester, 390);
    await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(displayedAsset(tester), endsWith('frame_03.png'));
    final before = crossingAnimation(tester).value;

    await tester.tap(find.byKey(const ValueKey('fox-preview-frame-3')));
    await tester.pump();
    expect(crossingAnimation(tester).value, closeTo(before, .001));
    expect(displayedAsset(tester), endsWith('frame_05.png'));
  });

  testWidgets(
    'BODY SIZE updates an active RUN on the same ground and progress',
    (tester) async {
      await pumpPreview(tester, 390);
      await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 640));
      final image = find.descendant(
        of: find.byKey(const ValueKey('fox-run-v1-production-stage')),
        matching: find.byType(Image),
      );
      final fullRect = tester.getRect(image);
      final fullGround =
          fullRect.top +
          fullRect.height *
              (FoxRunV1ProductionGeometry.virtualGround /
                  FoxRunV1ProductionGeometry.canvasSize.height);
      final before = crossingAnimation(tester).value;

      await tester.tap(
        find.byKey(const ValueKey('fox-preview-body-size-sevenTenths')),
      );
      await tester.pump();
      final sevenTenthsRect = tester.getRect(image);
      final sevenTenthsGround =
          sevenTenthsRect.top +
          sevenTenthsRect.height *
              (FoxRunV1ProductionGeometry.virtualGround /
                  FoxRunV1ProductionGeometry.canvasSize.height);
      expect(crossingAnimation(tester).value, closeTo(before, .001));
      expect(sevenTenthsRect.width, closeTo(fullRect.width * .7, .001));
      expect(sevenTenthsRect.height, closeTo(fullRect.height * .7, .001));
      expect(sevenTenthsGround, closeTo(fullGround, .001));

      await tester.tap(
        find.byKey(const ValueKey('fox-preview-body-size-half')),
      );
      await tester.pump();
      final halfRect = tester.getRect(image);
      final halfGround =
          halfRect.top +
          halfRect.height *
              (FoxRunV1ProductionGeometry.virtualGround /
                  FoxRunV1ProductionGeometry.canvasSize.height);
      expect(crossingAnimation(tester).value, closeTo(before, .001));
      expect(halfRect.width, closeTo(fullRect.width * .5, .001));
      expect(halfRect.height, closeTo(fullRect.height * .5, .001));
      expect(halfGround, closeTo(fullGround, .001));
    },
  );

  testWidgets(
    'VERTICAL FLUTTER updates an active RUN without resetting progress',
    (tester) async {
      await pumpPreview(tester, 390);
      await tester.tap(
        find.byKey(const ValueKey('fox-preview-vertical-flutter-off')),
      );
      await tester.tap(find.byKey(const ValueKey('fox-preview-body-flex-off')));
      await tester.pump();
      final image = find.descendant(
        of: find.byKey(const ValueKey('fox-run-v1-production-stage')),
        matching: find.byType(Image),
      );
      await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final groundedTop = tester.getTopLeft(image).dy;
      final before = crossingAnimation(tester).value;

      await tester.tap(
        find.byKey(const ValueKey('fox-preview-vertical-flutter-half')),
      );
      await tester.pump();
      expect(crossingAnimation(tester).value, closeTo(before, .001));
      expect(tester.getTopLeft(image).dy, closeTo(groundedTop - .25, .001));

      await tester.tap(
        find.byKey(const ValueKey('fox-preview-vertical-flutter-one')),
      );
      await tester.pump();
      expect(crossingAnimation(tester).value, closeTo(before, .001));
      expect(tester.getTopLeft(image).dy, closeTo(groundedTop - .5, .001));

      await tester.tap(
        find.byKey(const ValueKey('fox-preview-vertical-flutter-off')),
      );
      await tester.pump();
      expect(crossingAnimation(tester).value, closeTo(before, .001));
      expect(tester.getTopLeft(image).dy, closeTo(groundedTop, .001));

      await tester.tap(
        find.byKey(const ValueKey('fox-preview-vertical-flutter-two')),
      );
      await tester.pump();
      expect(crossingAnimation(tester).value, closeTo(before, .001));
      expect(tester.getTopLeft(image).dy, closeTo(groundedTop - 1, .001));
      await tester.tap(find.byKey(const ValueKey('fox-preview-pause')));
      await tester.pump();
      expect(tester.getTopLeft(image).dy, closeTo(groundedTop, .001));
    },
  );

  testWidgets(
    'BODY FLEX updates an active RUN around the fixed ground anchor',
    (tester) async {
      await pumpPreview(tester, 390);
      await tester.tap(find.byKey(const ValueKey('fox-preview-body-flex-off')));
      await tester.tap(
        find.byKey(const ValueKey('fox-preview-body-flex-motion-current')),
      );
      await tester.pump();
      final image = find.descendant(
        of: find.byKey(const ValueKey('fox-run-v1-production-stage')),
        matching: find.byType(Image),
      );
      final transform = find.byKey(const ValueKey('fox-run-v1-body-flex'));
      await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      final imageRect = tester.getRect(image);
      final groundAnchor = bodyFlexGroundAnchorY(tester);
      final torsoAnchor = bodyFlexTorsoAnchorY(tester);
      final before = crossingAnimation(tester).value;

      await tester.tap(find.byKey(const ValueKey('fox-preview-body-flex-one')));
      await tester.pump();
      expect(crossingAnimation(tester).value, closeTo(before, .001));
      final flexTransform = tester.widget<Transform>(transform);
      expect(flexTransform.transform.getMaxScaleOnAxis(), greaterThan(1));
      expect(tester.getSize(image), imageRect.size);
      expect(bodyFlexGroundAnchorY(tester), closeTo(groundAnchor, .001));
      expect(bodyFlexTorsoAnchorY(tester), closeTo(torsoAnchor - 1, .001));

      await tester.tap(find.byKey(const ValueKey('fox-preview-body-flex-off')));
      await tester.pump();
      expect(crossingAnimation(tester).value, closeTo(before, .001));
      expect(
        tester.widget<Transform>(transform).transform.getMaxScaleOnAxis(),
        closeTo(1, .001),
      );
    },
  );

  testWidgets(
    'BODY FLEX MOTION applies live without resetting crossing progress',
    (tester) async {
      await pumpPreview(tester, 390);
      await tester.tap(find.byKey(const ValueKey('fox-preview-body-flex-off')));
      await tester.tap(
        find.byKey(const ValueKey('fox-preview-body-flex-motion-current')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(
        find.byKey(const ValueKey('fox-preview-body-flex-four')),
      );
      await tester.pump();
      final groundAnchor = bodyFlexGroundAnchorY(tester);
      final currentTorso = bodyFlexTorsoAnchorY(tester);
      final progress = crossingAnimation(tester).value;

      await tester.tap(
        find.byKey(const ValueKey('fox-preview-body-flex-motion-smooth')),
      );
      await tester.pump();
      expect(crossingAnimation(tester).value, closeTo(progress, .001));
      expect(bodyFlexGroundAnchorY(tester), closeTo(groundAnchor, .001));
      final smoothTorso = bodyFlexTorsoAnchorY(tester);
      expect(smoothTorso, lessThan(currentTorso));

      await tester.tap(
        find.byKey(const ValueKey('fox-preview-body-flex-motion-hold')),
      );
      await tester.pump();
      expect(crossingAnimation(tester).value, closeTo(progress, .001));
      expect(bodyFlexGroundAnchorY(tester), closeTo(groundAnchor, .001));
      expect(bodyFlexTorsoAnchorY(tester), lessThan(smoothTorso));
    },
  );

  testWidgets(
    'HOLD retains deformation while crossing and frame animation continue',
    (tester) async {
      await pumpPreview(tester, 390);
      await tester.tap(
        find.byKey(const ValueKey('fox-preview-vertical-flutter-off')),
      );
      await tester.tap(
        find.byKey(const ValueKey('fox-preview-body-flex-four')),
      );
      await tester.tap(
        find.byKey(const ValueKey('fox-preview-body-flex-motion-hold')),
      );
      await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      final groundAnchor = bodyFlexGroundAnchorY(tester);
      final heldTorso = bodyFlexTorsoAnchorY(tester);
      final progress = crossingAnimation(tester).value;
      final asset = displayedAsset(tester);

      await tester.pump(const Duration(milliseconds: 40));
      expect(crossingAnimation(tester).value, greaterThan(progress));
      expect(displayedAsset(tester), isNot(asset));
      expect(bodyFlexGroundAnchorY(tester), closeTo(groundAnchor, .001));
      expect(bodyFlexTorsoAnchorY(tester), closeTo(heldTorso, .001));
    },
  );

  testWidgets('BODY SHRINK applies live without resetting the active RUN', (
    tester,
  ) async {
    await pumpPreview(tester, 390);
    await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 480));
    final groundAnchor = bodyFlexGroundAnchorY(tester);
    final torsoAnchor = bodyFlexTorsoAnchorY(tester);
    final before = crossingAnimation(tester).value;

    await tester.tap(find.byKey(const ValueKey('fox-preview-body-flex-four')));
    await tester.pump();
    expect(crossingAnimation(tester).value, closeTo(before, .001));
    expect(bodyFlexGroundAnchorY(tester), closeTo(groundAnchor, .001));
    expect(bodyFlexTorsoAnchorY(tester), closeTo(torsoAnchor, .001));

    await tester.tap(find.byKey(const ValueKey('fox-preview-body-shrink-on')));
    await tester.pump();
    expect(crossingAnimation(tester).value, closeTo(before, .001));
    expect(bodyFlexGroundAnchorY(tester), closeTo(groundAnchor, .001));
    expect(bodyFlexTorsoAnchorY(tester), closeTo(torsoAnchor + 4, .001));

    await tester.tap(find.byKey(const ValueKey('fox-preview-body-flex-off')));
    await tester.pump();
    expect(crossingAnimation(tester).value, closeTo(before, .001));
    expect(bodyFlexGroundAnchorY(tester), closeTo(groundAnchor, .001));
    expect(bodyFlexTorsoAnchorY(tester), closeTo(torsoAnchor, .001));
  });

  testWidgets('VERTICAL FLUTTER and BODY FLEX remain independent', (
    tester,
  ) async {
    await pumpPreview(tester, 390);
    await tester.tap(
      find.byKey(const ValueKey('fox-preview-vertical-flutter-off')),
    );
    await tester.tap(find.byKey(const ValueKey('fox-preview-body-flex-off')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final baseGround = bodyFlexGroundAnchorY(tester);
    final progress = crossingAnimation(tester).value;

    await tester.tap(
      find.byKey(const ValueKey('fox-preview-vertical-flutter-one')),
    );
    await tester.pump();
    expect(bodyFlexGroundAnchorY(tester), closeTo(baseGround - 1, .001));
    expect(crossingAnimation(tester).value, closeTo(progress, .001));

    await tester.tap(find.byKey(const ValueKey('fox-preview-body-flex-one')));
    await tester.pump();
    expect(bodyFlexGroundAnchorY(tester), closeTo(baseGround - 1, .001));
    expect(crossingAnimation(tester).value, closeTo(progress, .001));
    expect(
      tester
          .widget<Transform>(find.byKey(const ValueKey('fox-run-v1-body-flex')))
          .transform
          .getMaxScaleOnAxis(),
      greaterThan(1),
    );
  });

  testWidgets('subset, one-frame guard, and repeated RUN stay deterministic', (
    tester,
  ) async {
    await pumpPreview(tester, 390);
    const selected = {3, 6, 8};
    for (var frame = 1; frame <= 10; frame++) {
      final chip = tester.widget<FilterChip>(
        find.byKey(ValueKey('fox-preview-frame-$frame')),
      );
      if (chip.selected != selected.contains(frame)) {
        await tester.tap(find.byKey(ValueKey('fox-preview-frame-$frame')));
        await tester.pump();
      }
    }

    await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
    await tester.pump();
    expect(displayedAsset(tester), endsWith('frame_03.png'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(displayedAsset(tester), endsWith('frame_06.png'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(displayedAsset(tester), endsWith('frame_08.png'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(displayedAsset(tester), endsWith('frame_03.png'));

    await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
    await tester.pump();
    expect(displayedAsset(tester), endsWith('frame_03.png'));

    await tester.tap(find.byKey(const ValueKey('fox-preview-frame-6')));
    await tester.tap(find.byKey(const ValueKey('fox-preview-frame-8')));
    await tester.pump();
    final imageBefore = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('fox-run-v1-production-stage')),
        matching: find.byType(Image),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('fox-preview-frame-3')));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('fox-preview-frame-3')))
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(displayedAsset(tester), endsWith('frame_03.png'));
    expect(
      tester.getSize(
        find.descendant(
          of: find.byKey(const ValueKey('fox-run-v1-production-stage')),
          matching: find.byType(Image),
        ),
      ),
      imageBefore.size,
    );
    expect(
      tester
          .getRect(
            find.descendant(
              of: find.byKey(const ValueKey('fox-run-v1-production-stage')),
              matching: find.byType(Image),
            ),
          )
          .bottom,
      closeTo(imageBefore.bottom, .001),
    );
  });

  testWidgets('all seven speeds fully exit and reset', (tester) async {
    for (final speed in FoxRunV1Speed.values) {
      await pumpPreview(tester, 390);
      if (speed != FoxRunV1Speed.fastest) {
        await tester.tap(
          find.byKey(ValueKey('fox-preview-speed-${speed.name}')),
        );
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
      await tester.pump();
      await tester.pump(FoxRunV1Motion.durationForSpeed(speed));
      expect(crossingAnimation(tester).value, closeTo(0, .01));
      expect(
        displayedAsset(tester),
        anyOf(
          endsWith('frame_01.png'),
          endsWith('frame_03.png'),
          endsWith('frame_05.png'),
          endsWith('frame_06.png'),
          endsWith('frame_07.png'),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
      await tester.pump();
      expect(crossingAnimation(tester).value, closeTo(0, .001));
      expect(displayedAsset(tester), endsWith('frame_01.png'));
    }
  });

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
    for (final frame in [3, 5, 6, 7]) {
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        asset(),
        endsWith('frame_${frame.toString().padLeft(2, '0')}.png'),
      );
    }
    await tester.pump(const Duration(milliseconds: 80));
    expect(asset(), endsWith('frame_01.png'));
    await tester.pump(const Duration(milliseconds: 320));
    expect(crossing(), closeTo(720 / 1600, .01));
    expect(asset(), endsWith('frame_07.png'));

    await tester.pump(const Duration(milliseconds: 400));
    expect(crossing(), greaterThan(.1));
    await tester.tap(find.byKey(const ValueKey('fox-preview-play')));
    await tester.pump();
    expect(crossing(), closeTo(0, .001));
    expect(asset(), endsWith('frame_01.png'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(crossing(), greaterThan(0));
    expect(asset(), endsWith('frame_03.png'));
    expect(tester.takeException(), isNull);
  });

  test('390px mirrored baseline no longer leaves FOX visible at reset', () {
    final end = boundsFor(width: stageWidth, progress: 1, leftToRight: false);
    expect(end.right, closeTo(-8, .001));
    expect(end.intersect(stageRect).isEmpty, isTrue);
  });
}
