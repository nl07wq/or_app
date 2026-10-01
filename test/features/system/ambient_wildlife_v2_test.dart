import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:or_app/core/theme/app_theme.dart';
import 'package:or_app/features/system/pages/ambient_wildlife_v2.dart';
import 'package:or_app/features/system/pages/bat_v3_flight_motion_poc.dart';
import 'package:or_app/features/system/pages/bat_v3_source_data.dart';
import 'package:or_app/features/system/pages/bird_v1_flight_preview.dart';
import 'package:or_app/features/system/pages/cat_run_v23_production_preview.dart';
import 'package:or_app/features/system/pages/cat_run_v24_presentation.dart';
import 'package:or_app/features/system/pages/cat_run_v2_registration.dart';
import 'package:or_app/features/system/pages/cat_run_v2_trace_data.dart';
import 'package:or_app/features/system/pages/fox_run_v1_section.dart';

void main() {
  test('V2 registry exposes CAT, BAT, FOX, and BIRD to RANDOM', () {
    expect(AmbientWildlifeV2Registry.availableSpecies, const [
      AmbientWildlifeV2Species.cat,
      AmbientWildlifeV2Species.bat,
      AmbientWildlifeV2Species.fox,
      AmbientWildlifeV2Species.birds,
    ]);
    expect(
      AmbientWildlifeV2Registry.available(AmbientWildlifeV2Species.fox),
      isTrue,
    );
    expect(
      AmbientWildlifeV2Registry.available(AmbientWildlifeV2Species.birds),
      isTrue,
    );
  });

  test('FOX production policy uses the 48px Ambient torso authority', () {
    final plan = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.fox,
      leftToRight: true,
      nextInt: (_) => 0,
    );

    expect(plan.isFox, isTrue);
    expect(plan.isGlitch, isFalse);
    expect(
      AmbientWildlifeV2Fox.crossingDuration,
      const Duration(milliseconds: 1600),
    );
    expect(
      AmbientWildlifeV2Fox.dashboardCrossingDuration,
      const Duration(milliseconds: 1800),
    );
    expect(
      AmbientWildlifeV2Fox.frameDuration,
      const Duration(milliseconds: 80),
    );
    expect(AmbientWildlifeV2Fox.selectedFrames, const [0, 2, 4, 5, 6]);
    expect(
      [
        for (var phase = 0; phase < 6; phase++)
          AmbientWildlifeV2Fox.frameAtElapsed(
            Duration(milliseconds: phase * 80),
          ),
      ],
      const [0, 2, 4, 5, 6, 0],
    );
    expect(AmbientWildlifeV2Fox.verticalFlutterAmplitude, 1);
    expect(AmbientWildlifeV2Fox.bodyFlexAmplitude, 2);
    expect(AmbientWildlifeV2Fox.ambientTorsoLength, 48);
    expect(AmbientWildlifeV2Fox.canvasSize.width, closeTo(153.1163, .001));
    expect(AmbientWildlifeV2Fox.canvasSize.height, closeTo(72.8372, .001));
    expect(AmbientWildlifeV2Fox.neutralFrame, 4);
    expect(
      AmbientWildlifeV2Fox.assetForFrame(AmbientWildlifeV2Fox.neutralFrame),
      endsWith('frame_05.png'),
    );
    expect(AmbientWildlifeV2Fox.juvenileTorsoLength, 30);
    expect(AmbientWildlifeV2Fox.juvenileFollowerSpacing, closeTo(92.458, .01));
  });

  test('FOX spawn uses independent exact pattern and pack boundaries', () {
    AmbientWildlifeV2EventPlan planFor(List<int> rolls) {
      var index = 0;
      return AmbientWildlifeV2EventPlan.resolve(
        species: AmbientWildlifeV2Species.fox,
        leftToRight: true,
        nextInt: (_) => rolls[index++],
      );
    }

    final patternOne = planFor([0, 79, 94, 54]).foxSpawn!;
    final noPatternOne = planFor([0, 80, 94, 54]).foxSpawn!;
    final two = planFor([0, 79, 94, 55]).foxSpawn!;
    final three = planFor([0, 79, 94, 85]).foxSpawn!;
    final gricth = planFor([0, 80, 95]).foxSpawn!;

    expect(AmbientWildlifeV2FoxSpawn.patternProbability, .80);
    expect(AmbientWildlifeV2FoxSpawn.abnormalPackProbability, .05);
    expect(patternOne.pattern, FoxRunV1Pattern.fox);
    expect(noPatternOne.pattern, FoxRunV1Pattern.off);
    expect(patternOne.pack, AmbientWildlifeV2FoxPack.one);
    expect(two.pack, AmbientWildlifeV2FoxPack.two);
    expect(three.pack, AmbientWildlifeV2FoxPack.three);
    expect(gricth.pack, AmbientWildlifeV2FoxPack.gricthTen);
    expect(gricth.juvenileCount, 9);
  });

  test(
    'FOX pack duration extends event time while retaining individual speed',
    () {
      const width = 390.0;
      const safetyGap = FoxRunV1ProductionGeometry.crossingSafetyGap;
      final baseStart = AmbientWildlifeV2Fox.bodyCenterForProgress(
        stageWidth: width,
        progress: 0,
        leftToRight: true,
      );
      final baseEnd = AmbientWildlifeV2Fox.bodyCenterForProgress(
        stageWidth: width,
        progress: 1,
        leftToRight: true,
      );
      final trailingDistance = 9 * AmbientWildlifeV2Fox.juvenileFollowerSpacing;
      final packStart = AmbientWildlifeV2Fox.bodyCenterForProgress(
        stageWidth: width,
        progress: 0,
        leftToRight: true,
        trailingDistance: trailingDistance,
      );
      final packEnd = AmbientWildlifeV2Fox.bodyCenterForProgress(
        stageWidth: width,
        progress: 1,
        leftToRight: true,
        trailingDistance: trailingDistance,
      );
      final duration = AmbientWildlifeV2Fox.durationForPack(
        stageWidth: width,
        leftToRight: true,
        juvenileCount: 9,
      );

      expect(
        AmbientWildlifeV2Fox.juvenileFollowerSpacing,
        greaterThan(safetyGap),
      );
      expect(duration, greaterThan(AmbientWildlifeV2Fox.crossingDuration));
      expect(
        (packEnd - packStart) / duration.inMicroseconds,
        closeTo(
          (baseEnd - baseStart) /
              AmbientWildlifeV2Fox.crossingDuration.inMicroseconds,
          .000001,
        ),
      );
    },
  );

  test('Dashboard FOX uses FASTER while canonical V2 remains FASTEST', () {
    const width = 390.0;
    expect(
      AmbientWildlifeV2Fox.durationForPack(
        stageWidth: width,
        leftToRight: true,
        juvenileCount: 0,
        baseDuration: AmbientWildlifeV2Fox.dashboardCrossingDuration,
      ),
      const Duration(milliseconds: 1800),
    );
    expect(
      AmbientWildlifeV2Fox.durationForPack(
        stageWidth: width,
        leftToRight: true,
        juvenileCount: 9,
        baseDuration: AmbientWildlifeV2Fox.dashboardCrossingDuration,
      ),
      greaterThan(const Duration(milliseconds: 1800)),
    );
  });

  test('every FOX pack reaches its last-active full-exit endpoint', () {
    for (final width in [320.0, 390.0, 900.0]) {
      for (final leftToRight in [true, false]) {
        for (final juvenileCount in [0, 1, 2, 9]) {
          expect(
            AmbientWildlifeV2Fox.lastActiveFoxHasFullyExited(
              stageWidth: width,
              progress: 0,
              leftToRight: leftToRight,
              juvenileCount: juvenileCount,
            ),
            isFalse,
            reason: '$width / $leftToRight / $juvenileCount start',
          );
          expect(
            AmbientWildlifeV2Fox.lastActiveFoxHasFullyExited(
              stageWidth: width,
              progress: 1,
              leftToRight: leftToRight,
              juvenileCount: juvenileCount,
            ),
            isTrue,
            reason: '$width / $leftToRight / $juvenileCount end',
          );
        }
      }
    }
  });

  test('CAT policy retains its production 5% glitch authority', () {
    final glitch = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.cat,
      leftToRight: true,
      nextInt: (max) => 0,
    );
    final normal = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.cat,
      leftToRight: false,
      nextInt: (max) => max == 20 ? 1 : 0,
    );
    expect(CatRunProductionEventPolicy.glitchProbability, .05);
    expect(glitch.isGlitch, isTrue);
    expect(glitch.catPlan!.crossings, hasLength(10));
    expect(normal.isGlitch, isFalse);
    expect(normal.catPlan!.allowsRecursiveContinuation, isTrue);
  });

  test('BAT policy resolves normal count and replaces it with GLITCH ×10', () {
    final normal = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.bat,
      leftToRight: true,
      nextInt: (max) => max == 20 ? 1 : 85,
    );
    final glitch = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.bat,
      leftToRight: false,
      nextInt: (_) => 0,
    );
    expect(normal.isGlitch, isFalse);
    expect(normal.batInstances, hasLength(3));
    expect(normal.batInstances.map((instance) => instance.phaseOffset), [
      0,
      2,
      5,
    ]);
    expect(glitch.isGlitch, isTrue);
    expect(glitch.batInstances, BatV3ProductionFlight.glitchInstances);
    expect(glitch.batInstances, hasLength(10));
  });

  test('BAT normal count policy uses exact 50/30/20 branches', () {
    expect(BatV3ProductionEventPolicy.normalCountForRoll(0), 1);
    expect(BatV3ProductionEventPolicy.normalCountForRoll(49), 1);
    expect(BatV3ProductionEventPolicy.normalCountForRoll(50), 2);
    expect(BatV3ProductionEventPolicy.normalCountForRoll(79), 2);
    expect(BatV3ProductionEventPolicy.normalCountForRoll(80), 3);
    expect(BatV3ProductionEventPolicy.normalCountForRoll(99), 3);
  });

  test(
    'BIRD production authority is the approved Cruise overlap candidate',
    () {
      expect(BirdV1ProductionFlight.frameSet, const [0, 1, 2, 3, 4, 5]);
      expect(BirdV1ProductionFlight.holds, const [63, 55, 58, 68, 115, 125]);
      expect(BirdV1ProductionFlight.transition, BirdV1Transition.overlap20);
      expect(BirdV1ProductionFlight.transitionMs, 20);
      expect(
        BirdV1ProductionFlight.crossingDuration,
        const Duration(milliseconds: 1467),
      );
      expect(BirdV1ProductionFlight.flutterOn, isTrue);
      expect(BirdV1ProductionFlight.renderedSize, 56);
      expect(
        BirdV1ProductionFlight.flightSpeed,
        BirdV1FlightSpeed.onePointFive,
      );

      final first = BirdV1ProductionFlight.frameFor(
        elapsedMs: 0,
        instance: BirdV1ProductionFlight.instances.first,
      );
      final second = BirdV1ProductionFlight.frameFor(
        elapsedMs: 63,
        instance: BirdV1ProductionFlight.instances.first,
      );
      final seam = BirdV1ProductionFlight.frameFor(
        elapsedMs: BirdV1ProductionFlight.cycleDurationMs,
        instance: BirdV1ProductionFlight.instances.first,
      );
      expect(first.frame, 0);
      expect(second.frame, 1);
      expect(second.previousFrame, 0);
      expect(seam.frame, 0);
      expect(seam.previousFrame, 5);
    },
  );

  test(
    'BIRD variants use deterministic formation and a rare GLITCH10 branch',
    () {
      AmbientWildlifeV2EventPlan planFor(List<int> rolls) {
        var index = 0;
        return AmbientWildlifeV2EventPlan.resolve(
          species: AmbientWildlifeV2Species.birds,
          leftToRight: true,
          nextInt: (max) => rolls[index++] % max,
        );
      }

      final one = planFor([0, 1, 0]);
      final two = planFor([0, 1, 50]);
      final three = planFor([0, 1, 80]);
      final glitch = planFor([0, 0, 0]);
      expect(one.isBird, isTrue);
      expect(one.birdInstances, hasLength(1));
      expect(two.birdInstances, hasLength(2));
      expect(three.birdInstances, hasLength(3));
      expect(glitch.isGlitch, isTrue);
      expect(glitch.birdInstances, hasLength(10));
      expect(BirdV1ProductionEventPolicy.glitchProbability, .05);
      expect(
        glitch.birdInstances.map((instance) => instance.formationY).toSet(),
        hasLength(greaterThan(1)),
      );
      expect(
        glitch.birdInstances.map((instance) => instance.phaseOffsetMs).toSet(),
        hasLength(10),
      );
    },
  );

  test(
    'BIRD formation exits fully and remains inside the airspace envelope',
    () {
      for (final width in [320.0, 390.0, 900.0]) {
        for (final leftToRight in [true, false]) {
          for (final instances in [
            BirdV1ProductionFlight.instances.take(1).toList(),
            BirdV1ProductionFlight.instances.take(2).toList(),
            BirdV1ProductionFlight.instances,
            BirdV1ProductionFlight.glitchInstances,
          ]) {
            final elapsed = BirdV1ProductionFlight.eventDurationMs(instances);
            expect(
              instances.every(
                (instance) => BirdV1ProductionFlight.hasFullyExited(
                  stageWidth: width,
                  elapsedMs: elapsed,
                  leftToRight: leftToRight,
                  instance: instance,
                ),
              ),
              isTrue,
              reason: '$width / $leftToRight / ${instances.length}',
            );
          }
        }
      }
      expect(BirdV1ProductionFlight.minimumTopClearance, greaterThan(0));
      expect(BirdV1ProductionFlight.groundClearanceFor(99), greaterThan(0));
    },
  );

  testWidgets('neutral species art keeps the shared environment visible', (
    tester,
  ) async {
    Future<void> pumpNeutral(AmbientWildlifeV2Species species) =>
        tester.pumpWidget(
          MaterialApp(
            home: AmbientWildlifeV2Stage(
              plan: null,
              requestId: 0,
              neutral: true,
              neutralSpecies: species,
              paused: false,
              leftToRight: true,
            ),
          ),
        );

    await pumpNeutral(AmbientWildlifeV2Species.cat);
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-environment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-ground-line')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-neutral-cat')),
      findsOneWidget,
    );
    final catPainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('ambient-wildlife-v2-neutral-cat')),
                )
                .painter!
            as CatRunV23StagePainter;
    expect(catPainter.neutralFrame02, isTrue);
    expect(catPainter.catUnit, CatRunV23Travel.catUnit);
    expect(catPainter.showGroundLine, isFalse);
    expect(catPainter.paintBackground, isFalse);
    expect(catPainter.groundInset, AmbientWildlifeV2Stage.groundInset);
    expect(catPainter.groundLineColor, AmbientWildlifeV2Stage.groundLineColor);
    final stageStack = tester
        .widgetList<Stack>(
          find.descendant(
            of: find.byKey(const ValueKey('ambient-wildlife-v2-stage')),
            matching: find.byType(Stack),
          ),
        )
        .first;
    final groundLayer = stageStack.children[1] as Positioned;
    expect(
      ((groundLayer.child as IgnorePointer).child as CustomPaint).key,
      const ValueKey('ambient-wildlife-v2-ground-line'),
    );
    expect(stageStack.children[2], isA<Positioned>());

    await pumpNeutral(AmbientWildlifeV2Species.bat);
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-environment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-neutral-bat')),
      findsOneWidget,
    );
    final bat = tester.widget<BatV3CanonicalFrame>(
      find.byType(BatV3CanonicalFrame),
    );
    expect(bat.pose, BatV3SourceSet.poses[1]);
    expect(find.byType(BatV3ProductionStage), findsNothing);

    await pumpNeutral(AmbientWildlifeV2Species.fox);
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-neutral-fox')),
      findsOneWidget,
    );
    final neutralFox = tester.widget<Image>(find.byType(Image));
    expect(
      (neutralFox.image as AssetImage).assetName,
      AmbientWildlifeV2Fox.assetForFrame(AmbientWildlifeV2Fox.neutralFrame),
    );
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('FOX motion uses the requested production settings and exits', (
    tester,
  ) async {
    for (final leftToRight in [true, false]) {
      final plan = AmbientWildlifeV2EventPlan.resolve(
        species: AmbientWildlifeV2Species.fox,
        leftToRight: leftToRight,
        nextInt: (_) => 0,
      );
      await tester.pumpWidget(_stageHost(plan: null, requestId: 0));
      await tester.pumpWidget(_stageHost(plan: plan, requestId: 1));
      await tester.pump(const Duration(milliseconds: 160));

      expect(
        find.byKey(const ValueKey('ambient-wildlife-v2-fox-motion')),
        findsOneWidget,
        reason: '$leftToRight',
      );
      expect(
        find.byKey(const ValueKey('ambient-wildlife-v2-fox-body-flex')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('fox-run-v1-pattern-base')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        find.byKey(const ValueKey('ambient-wildlife-preview-idle')),
        findsOneWidget,
      );
      await tester.pumpWidget(_stageHost(plan: plan, requestId: 2));
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        find.byKey(const ValueKey('ambient-wildlife-v2-fox-motion')),
        findsOneWidget,
        reason: 'repeated run $leftToRight',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'FOX keeps each sampled pattern and pack fixed through its spawn',
    (tester) async {
      AmbientWildlifeV2EventPlan planFor(List<int> rolls) {
        var index = 0;
        return AmbientWildlifeV2EventPlan.resolve(
          species: AmbientWildlifeV2Species.fox,
          leftToRight: true,
          nextInt: (_) => rolls[index++],
        );
      }

      final patternedPack = planFor([0, 0, 95]);
      await tester.pumpWidget(_stageHost(plan: null, requestId: 0));
      await tester.pumpWidget(_stageHost(plan: patternedPack, requestId: 1));
      await tester.pump(const Duration(milliseconds: 160));

      expect(patternedPack.foxSpawn!.pattern, FoxRunV1Pattern.fox);
      expect(patternedPack.foxSpawn!.juvenileCount, 9);
      for (var index = 1; index <= 9; index++) {
        expect(
          find.byKey(ValueKey('ambient-wildlife-v2-fox-juvenile-$index')),
          findsOneWidget,
        );
      }
      expect(find.byType(ClipPath), findsNWidgets(30));
      expect(tester.takeException(), isNull);

      final plainAdult = planFor([0, 80, 94, 54]);
      await tester.pumpWidget(_stageHost(plan: plainAdult, requestId: 2));
      await tester.pump(const Duration(milliseconds: 160));
      expect(plainAdult.foxSpawn!.pattern, FoxRunV1Pattern.off);
      expect(plainAdult.foxSpawn!.juvenileCount, 0);
      expect(find.byType(ClipPath), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visual ground line moves without moving a FOX pack or rerolling it',
    (tester) async {
      var index = 0;
      final plan = AmbientWildlifeV2EventPlan.resolve(
        species: AmbientWildlifeV2Species.fox,
        leftToRight: true,
        nextInt: (_) => [0, 0, 95][index++],
      );
      await tester.pumpWidget(_stageHost(plan: null, requestId: 0));
      await tester.pumpWidget(_stageHost(plan: plan, requestId: 1));
      await tester.pump(const Duration(milliseconds: 160));
      final adult = find.byKey(
        const ValueKey('ambient-wildlife-v2-fox-motion'),
      );
      final juvenile = find.byKey(
        const ValueKey('ambient-wildlife-v2-fox-juvenile-9'),
      );
      final adultPosition = tester.getTopLeft(adult);
      final juvenilePosition = tester.getTopLeft(juvenile);

      await tester.pumpWidget(
        _stageHost(plan: plan, requestId: 1, visualGroundLineOffset: -8),
      );
      await tester.pump();

      expect(tester.getTopLeft(adult), adultPosition);
      expect(tester.getTopLeft(juvenile), juvenilePosition);
      expect(plan.foxSpawn!.juvenileCount, 9);
      expect(plan.foxSpawn!.pattern, FoxRunV1Pattern.fox);
      expect(
        AmbientWildlifeV2Stage.visualGroundLineY(stageHeight: 112),
        AmbientWildlifeV2Stage.legacyVisualGroundLineY(
          stageHeight: 112,
          offset: -8,
        ),
      );
      for (var offset = 0; offset <= 8; offset++) {
        expect(
          AmbientWildlifeV2Stage.visualGroundLineY(
            stageHeight: 112,
            offset: offset.toDouble(),
          ),
          99 + offset,
          reason: 'offset $offset',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('visual ground line leaves Neutral FOX placement unchanged', (
    tester,
  ) async {
    Widget host(double offset) => MaterialApp(
      home: AmbientWildlifeV2Stage(
        plan: null,
        requestId: 0,
        neutral: true,
        neutralSpecies: AmbientWildlifeV2Species.fox,
        paused: false,
        leftToRight: false,
        visualGroundLineOffset: offset,
      ),
    );

    await tester.pumpWidget(host(0));
    final fox = find.byKey(const ValueKey('ambient-wildlife-v2-neutral-fox'));
    final position = tester.getTopLeft(fox);
    await tester.pumpWidget(host(-3));
    await tester.pump();
    expect(tester.getTopLeft(fox), position);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FOX pack entry and last-follower exit work at Ambient widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 300);
      tester.view.devicePixelRatio = 1;
      var index = 0;
      final plan = AmbientWildlifeV2EventPlan.resolve(
        species: AmbientWildlifeV2Species.fox,
        leftToRight: false,
        nextInt: (_) => [0, 0, 95][index++],
      );
      final duration = AmbientWildlifeV2Fox.durationForPack(
        stageWidth: width,
        leftToRight: false,
        juvenileCount: 9,
      );
      await tester.pumpWidget(
        _stageHost(plan: null, requestId: 0, width: width),
      );
      await tester.pumpWidget(
        _stageHost(plan: plan, requestId: 1, width: width),
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        find.byKey(const ValueKey('ambient-wildlife-v2-fox-motion')),
        findsOneWidget,
        reason: '$width entry',
      );
      expect(
        find.byKey(const ValueKey('ambient-wildlife-v2-fox-juvenile-9')),
        findsOneWidget,
      );
      await tester.pump(
        duration -
            const Duration(milliseconds: 160) +
            const Duration(milliseconds: 20),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('ambient-wildlife-preview-idle')),
        findsOneWidget,
        reason: '$width full pack exit',
      );
      expect(tester.takeException(), isNull, reason: '$width');
    }
  });

  test('FOX ground contact geometry remains based on the Ambient stage', () {
    const stageHeight = BatV3ProductionFlight.stageHeight;
    const stageWidth = 390.0;
    final groundY = stageHeight - AmbientWildlifeV2Stage.groundInset;
    final center = AmbientWildlifeV2Fox.bodyCenterForProgress(
      stageWidth: stageWidth,
      progress: .5,
      leftToRight: true,
    );
    final bounds = AmbientWildlifeV2Fox.visibleBoundsFor(
      bodyCenterX: center,
      stageGroundY: groundY,
      leftToRight: true,
    );

    expect(bounds.width, closeTo(135.1326, .01));
    expect(bounds.bottom, lessThanOrEqualTo(groundY));
    expect(groundY, stageHeight - AmbientWildlifeV2Stage.groundInset);
  });

  test('48px FOX fully enters and exits at all supported Ambient widths', () {
    const groundY =
        BatV3ProductionFlight.stageHeight - AmbientWildlifeV2Stage.groundInset;
    for (final width in [320.0, 390.0, 900.0]) {
      for (final leftToRight in [true, false]) {
        final startCenter = AmbientWildlifeV2Fox.bodyCenterForProgress(
          stageWidth: width,
          progress: 0,
          leftToRight: leftToRight,
        );
        final endCenter = AmbientWildlifeV2Fox.bodyCenterForProgress(
          stageWidth: width,
          progress: 1,
          leftToRight: leftToRight,
        );
        final start = AmbientWildlifeV2Fox.visibleBoundsFor(
          bodyCenterX: startCenter,
          stageGroundY: groundY,
          leftToRight: leftToRight,
        );
        final end = AmbientWildlifeV2Fox.visibleBoundsFor(
          bodyCenterX: endCenter,
          stageGroundY: groundY,
          leftToRight: leftToRight,
        );
        if (leftToRight) {
          expect(start.right, lessThanOrEqualTo(-7.999));
          expect(end.left, greaterThanOrEqualTo(width + 7.999));
        } else {
          expect(start.left, greaterThanOrEqualTo(width + 7.999));
          expect(end.right, lessThanOrEqualTo(-7.999));
        }
      }
    }
  });

  test('CAT neutral Frame 02 uses production motion geometry and ground', () {
    final trace = catRunV2HighTraces[1];
    final rawPath = Path()..addPolygon(trace.points, true);
    final motionPath = Path()
      ..addPolygon(CatRunV24ScaleAudit.correctedPoints(trace), true);
    final neutralPath = Path()
      ..addPolygon(CatRunV23StagePainter.neutralFrame02Points, true);
    final rawBounds = rawPath.getBounds();
    final motionBounds = motionPath.getBounds();
    final neutralBounds = neutralPath.getBounds();
    const stageSize = Size(390, CatRunV23Travel.stageHeight);
    const unit = CatRunV23Travel.catUnit;
    final groundY = stageSize.height - AmbientWildlifeV2Stage.groundInset;
    final originY = groundY - CatRunV2Registration.virtualGround * unit;
    final renderedBounds = Rect.fromCenter(
      center: Offset(
        stageSize.width / 2,
        originY + neutralBounds.center.dy * unit,
      ),
      width: neutralBounds.width * unit,
      height: neutralBounds.height * unit,
    );

    expect(neutralBounds, motionBounds);
    expect(neutralBounds.width * unit, lessThan(rawBounds.width * unit));
    expect(neutralBounds.height * unit, lessThan(rawBounds.height * unit));
    expect(renderedBounds.center.dx, stageSize.width / 2);
    expect(renderedBounds.bottom, closeTo(groundY, .001));
  });

  testWidgets('CAT production preview restores the FOX ground treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StandardTheme.theme,
        home: const SingleChildScrollView(child: CatRunV23ProductionPreview()),
      ),
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('cat-run-v23-stage')),
                )
                .painter!
            as CatRunV23StagePainter;
    expect(painter.showGroundLine, isTrue);
    expect(painter.paintBackground, isTrue);
    expect(painter.groundLineColor, const Color(0xFF43474E));
    expect(painter.groundInset, 5);
    expect(CatRunV23Travel.stageHeight, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CAT motion keeps production size and shared ground', (
    tester,
  ) async {
    final plan = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.cat,
      leftToRight: true,
      nextInt: (max) => max == 20 ? 1 : 0,
    );
    await tester.pumpWidget(_stageHost(plan: null, requestId: 0));
    await tester.pumpWidget(_stageHost(plan: plan, requestId: 1));
    await tester.pump(const Duration(milliseconds: 80));
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('ambient-wildlife-v2-cat-stage')),
                )
                .painter!
            as CatRunV23StagePainter;
    expect(painter.catUnit, CatRunV23Travel.catUnit);
    expect(painter.showGroundLine, isFalse);
    expect(painter.paintBackground, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'BAT motion fills the shared stage and enters visibly in both directions',
    (tester) async {
      for (final leftToRight in [true, false]) {
        final plan = AmbientWildlifeV2EventPlan.resolve(
          species: AmbientWildlifeV2Species.bat,
          leftToRight: leftToRight,
          nextInt: (max) => max == 20 ? 1 : 0,
        );

        await tester.pumpWidget(_stageHost(plan: null, requestId: 0));
        await tester.pumpWidget(_stageHost(plan: plan, requestId: 1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1100));

        final stage = find.byKey(const ValueKey('ambient-wildlife-v2-stage'));
        final environment = find.byKey(
          const ValueKey('ambient-wildlife-v2-environment'),
        );
        final bat = find.byKey(const ValueKey('bat-v3-production-instance-0'));
        expect(stage, findsOneWidget);
        expect(environment, findsOneWidget);
        expect(find.byType(BatV3ProductionStage), findsOneWidget);
        expect(bat, findsOneWidget, reason: '$leftToRight');
        expect(tester.getRect(environment), tester.getRect(stage));
        expect(tester.getRect(bat).overlaps(tester.getRect(stage)), isTrue);
        expect(find.byType(Image), findsWidgets);
        expect(
          AmbientWildlifeV2Stage.environmentBackground,
          const Color(0xFF101010),
        );
        expect(AmbientWildlifeV2Stage.groundLineColor, const Color(0xFF383838));
        expect(AmbientWildlifeV2Stage.groundInset, 5);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('BAT normal groups and GLITCH use the shared visible stage', (
    tester,
  ) async {
    for (final configuration in [
      (countRoll: 50, expected: <int>[0, 2]),
      (countRoll: 80, expected: <int>[0, 2, 5]),
      (countRoll: 0, expected: List<int>.generate(10, (index) => index)),
    ]) {
      final plan = AmbientWildlifeV2EventPlan.resolve(
        species: AmbientWildlifeV2Species.bat,
        leftToRight: true,
        nextInt: (max) => max == 20
            ? (configuration.expected.length == 10 ? 0 : 1)
            : configuration.countRoll,
      );
      await tester.pumpWidget(_stageHost(plan: null, requestId: 0));
      await tester.pumpWidget(_stageHost(plan: plan, requestId: 1));
      await tester.pump(const Duration(milliseconds: 1500));

      for (final identifier in configuration.expected) {
        expect(
          find.byKey(ValueKey('bat-v3-production-instance-$identifier')),
          findsOneWidget,
          reason: 'instance $identifier',
        );
      }
      expect(
        find.byKey(const ValueKey('ambient-wildlife-v2-environment')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('BAT remains visible in the fixed stage at target widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plan = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.bat,
      leftToRight: true,
      nextInt: (max) => max == 20 ? 1 : 0,
    );
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 300);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _stageHost(plan: null, requestId: 0, width: width),
      );
      await tester.pumpWidget(
        _stageHost(plan: plan, requestId: 1, width: width),
      );
      await tester.pump(const Duration(milliseconds: 1100));

      final stage = find.byKey(const ValueKey('ambient-wildlife-v2-stage'));
      final environment = find.byKey(
        const ValueKey('ambient-wildlife-v2-environment'),
      );
      final bat = find.byKey(const ValueKey('bat-v3-production-instance-0'));
      expect(tester.getSize(stage).width, width);
      expect(tester.getRect(environment), tester.getRect(stage));
      expect(tester.getRect(bat).overlaps(tester.getRect(stage)), isTrue);
      expect(tester.takeException(), isNull, reason: '$width');
    }
  });

  testWidgets(
    'neutral CAT, BAT, FOX, and BIRD fit the stage at target widths',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0, 900.0]) {
        tester.view.physicalSize = Size(width, 300);
        tester.view.devicePixelRatio = 1;
        for (final species in [
          AmbientWildlifeV2Species.cat,
          AmbientWildlifeV2Species.bat,
          AmbientWildlifeV2Species.fox,
          AmbientWildlifeV2Species.birds,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: SizedBox(
                width: width,
                child: AmbientWildlifeV2Stage(
                  plan: null,
                  requestId: 0,
                  neutral: true,
                  neutralSpecies: species,
                  paused: false,
                  leftToRight: true,
                ),
              ),
            ),
          );
          expect(
            tester
                .getSize(
                  find.byKey(const ValueKey('ambient-wildlife-v2-stage')),
                )
                .width,
            width,
          );
          expect(tester.takeException(), isNull, reason: '$species at $width');
        }
      }
    },
  );

  testWidgets(
    'BIRD production motion is visible in both directions at target widths',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final plan = AmbientWildlifeV2EventPlan.resolve(
        species: AmbientWildlifeV2Species.birds,
        leftToRight: true,
        nextInt: (max) => max == 20 ? 1 : 0,
      );
      for (final width in [320.0, 390.0, 900.0]) {
        for (final leftToRight in [true, false]) {
          tester.view.physicalSize = Size(width, 300);
          tester.view.devicePixelRatio = 1;
          final directionalPlan = AmbientWildlifeV2EventPlan.resolve(
            species: AmbientWildlifeV2Species.birds,
            leftToRight: leftToRight,
            nextInt: (max) => max == 20 ? 1 : 0,
          );
          await tester.pumpWidget(
            _stageHost(plan: null, requestId: 0, width: width),
          );
          await tester.pumpWidget(
            _stageHost(plan: directionalPlan, requestId: 1, width: width),
          );
          await tester.pump(const Duration(milliseconds: 800));
          final stage = find.byKey(const ValueKey('ambient-wildlife-v2-stage'));
          final bird = find.byKey(
            const ValueKey('ambient-wildlife-v2-bird-instance-0'),
          );
          expect(stage, findsOneWidget);
          expect(bird, findsOneWidget, reason: '$width / $leftToRight');
          expect(tester.getRect(bird).overlaps(tester.getRect(stage)), isTrue);
          expect(find.byType(BirdV1Frame), findsWidgets);
          expect(
            tester.takeException(),
            isNull,
            reason: '$width / $leftToRight',
          );
        }
      }
      expect(plan.birdInstances, hasLength(1));
    },
  );

  testWidgets(
    'FOX completion waits for the selected pack duration and emits once',
    (tester) async {
      var rollIndex = 0;
      final rolls = <int>[0, 0, 95];
      var completed = 0;
      const width = 390.0;
      final duration = AmbientWildlifeV2Fox.durationForPack(
        stageWidth: width,
        leftToRight: true,
        juvenileCount: 9,
      );
      Widget host(AmbientWildlifeV2EventPlan? plan, int requestId) =>
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: AmbientWildlifeV2Stage(
                  plan: plan,
                  requestId: requestId,
                  neutral: false,
                  neutralSpecies: AmbientWildlifeV2Species.fox,
                  paused: false,
                  leftToRight: true,
                  onCompleted: () => completed++,
                ),
              ),
            ),
          );
      final plan = AmbientWildlifeV2EventPlan.resolve(
        species: AmbientWildlifeV2Species.fox,
        leftToRight: true,
        nextInt: (max) => rolls[rollIndex++ % rolls.length] % max,
      );
      await tester.pumpWidget(host(null, 0));
      await tester.pumpWidget(host(plan, 1));

      await tester.pump();
      await tester.pump(duration - const Duration(milliseconds: 1));
      expect(completed, 0);
      expect(
        find.byKey(const ValueKey('ambient-wildlife-v2-fox-juvenile-9')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump();
      expect(completed, 1);
      expect(
        find.byKey(const ValueKey('ambient-wildlife-preview-idle')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'production manual trigger uses V2 species planning and queues one follow-up',
    (tester) async {
      final stageKey = GlobalKey<AmbientWildlifeV2ProductionStageState>();
      final rolls = <int>[2, 0, 0, 0, 0];
      var rollIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: AmbientWildlifeV2ProductionStage(
                key: stageKey,
                nextInt: (max) => rolls[rollIndex++ % rolls.length] % max,
                minimumInterval: const Duration(hours: 1),
                maximumInterval: const Duration(hours: 1),
              ),
            ),
          ),
        ),
      );

      expect(stageKey.currentState!.isActive, isFalse);
      expect(stageKey.currentState!.triggerManualSequence(), isTrue);
      await tester.pump();
      expect(stageKey.currentState!.isActive, isTrue);
      expect(
        find.byKey(const ValueKey('ambient-wildlife-v2-fox-motion')),
        findsOneWidget,
      );

      expect(stageKey.currentState!.triggerManualSequence(), isTrue);
      expect(stageKey.currentState!.hasQueuedManualSequence, isTrue);
      expect(stageKey.currentState!.triggerManualSequence(), isFalse);
      expect(
        find.byKey(const ValueKey('ambient-wildlife-v2-fox-motion')),
        findsOneWidget,
      );

      await tester.pump(
        AmbientWildlifeV2Fox.dashboardCrossingDuration +
            const Duration(milliseconds: 20),
      );
      await tester.pump();
      expect(stageKey.currentState!.hasQueuedManualSequence, isFalse);
      expect(stageKey.currentState!.isActive, isTrue);
    },
  );

  testWidgets('production manual queue can select and complete BIRD', (
    tester,
  ) async {
    final stageKey = GlobalKey<AmbientWildlifeV2ProductionStageState>();
    final rolls = <int>[3, 0, 0, 1, 0];
    var rollIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: AmbientWildlifeV2ProductionStage(
              key: stageKey,
              nextInt: (max) => rolls[rollIndex++ % rolls.length] % max,
              minimumInterval: const Duration(hours: 1),
              maximumInterval: const Duration(hours: 1),
            ),
          ),
        ),
      ),
    );

    expect(stageKey.currentState!.triggerManualSequence(), isTrue);
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-bird-instance-0')),
      findsOneWidget,
    );
    await tester.pump(BirdV1ProductionFlight.crossingDuration);
    await tester.pump(const Duration(milliseconds: 5));
    expect(stageKey.currentState!.isActive, isFalse);
  });

  testWidgets('production scheduler advances from FOX to the next species', (
    tester,
  ) async {
    final stageKey = GlobalKey<AmbientWildlifeV2ProductionStageState>();
    final rolls = <int>[2, 0, 0, 0, 95, 0, 0, 0, 0];
    var rollIndex = 0;
    const width = 390.0;
    final foxDuration = AmbientWildlifeV2Fox.durationForPack(
      stageWidth: width,
      leftToRight: true,
      juvenileCount: 9,
      baseDuration: AmbientWildlifeV2Fox.dashboardCrossingDuration,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AmbientWildlifeV2ProductionStage(
              key: stageKey,
              nextInt: (max) => rolls[rollIndex++ % rolls.length] % max,
              minimumInterval: const Duration(milliseconds: 1),
              maximumInterval: const Duration(milliseconds: 1),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-fox-juvenile-9')),
      findsOneWidget,
    );
    expect(stageKey.currentState!.isActive, isTrue);

    await tester.pump(foxDuration + const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 1));
    expect(stageKey.currentState!.isActive, isTrue);
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-cat-stage')),
      findsOneWidget,
    );
  });
}

Widget _stageHost({
  required AmbientWildlifeV2EventPlan? plan,
  required int requestId,
  double width = 390,
  double visualGroundLineOffset = 0,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      child: AmbientWildlifeV2Stage(
        plan: plan,
        requestId: requestId,
        neutral: false,
        neutralSpecies: AmbientWildlifeV2Species.bat,
        paused: false,
        leftToRight: plan?.leftToRight ?? true,
        visualGroundLineOffset: visualGroundLineOffset,
      ),
    ),
  ),
);
