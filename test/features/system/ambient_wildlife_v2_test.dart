import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:or_app/features/dashboard/widgets/dashboard_ambient_wildlife_stage.dart';
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
  test('forced production plans use the existing supported formations', () {
    for (final species in AmbientWildlifeV2Registry.availableSpecies) {
      final two = AmbientWildlifeV2EventPlan.forced(
        species: species,
        variant: AmbientWildlifeV2ForcedVariant.two,
        leftToRight: true,
      );
      final glitch = AmbientWildlifeV2EventPlan.forced(
        species: species,
        variant: AmbientWildlifeV2ForcedVariant.glitch10,
        leftToRight: false,
      );
      expect(two.leftToRight, isTrue);
      expect(glitch.leftToRight, isFalse);
      expect(glitch.isGlitch, isTrue);
      expect(switch (species) {
        AmbientWildlifeV2Species.cat => two.catPlan!.crossings.length,
        AmbientWildlifeV2Species.bat => two.batInstances.length,
        AmbientWildlifeV2Species.fox => two.foxSpawn!.juvenileCount + 1,
        AmbientWildlifeV2Species.birds => two.birdInstances.length,
      }, 2);
    }
  });

  test('CAT GLITCH uses dense spacing without changing normal CAT spacing', () {
    final normal = AmbientWildlifeV2EventPlan.forced(
      species: AmbientWildlifeV2Species.cat,
      variant: AmbientWildlifeV2ForcedVariant.three,
      leftToRight: true,
    );
    final glitch = AmbientWildlifeV2EventPlan.forced(
      species: AmbientWildlifeV2Species.cat,
      variant: AmbientWildlifeV2ForcedVariant.glitch10,
      leftToRight: true,
    );

    expect(
      normal.catPlan!.crossings[1].startedAtProgress,
      CatRunProductionEventPolicy.normalFollowerTriggerProgress,
    );
    expect(
      glitch.catPlan!.crossings[1].startedAtProgress,
      CatRunProductionEventPolicy.glitchFollowerTriggerProgress,
    );
    expect(CatRunProductionEventPolicy.normalFollowerTriggerProgress, .15);
    expect(CatRunProductionEventPolicy.glitchFollowerTriggerProgress, .025);
  });

  test('CAT GLITCH Preview presets override only forced GLITCH plans', () {
    const presets = [.06, .075, .09, .10, .12];
    for (final preset in presets) {
      for (final leftToRight in [true, false]) {
        final preview = AmbientWildlifeV2EventPlan.forced(
          species: AmbientWildlifeV2Species.cat,
          variant: AmbientWildlifeV2ForcedVariant.glitch10,
          leftToRight: leftToRight,
          catGlitchSpacingOverride: preset,
        );
        expect(preview.catPlan!.crossings, hasLength(10));
        expect(preview.catPlan!.crossings[1].startedAtProgress, preset);
      }
    }

    final normal = AmbientWildlifeV2EventPlan.forced(
      species: AmbientWildlifeV2Species.cat,
      variant: AmbientWildlifeV2ForcedVariant.three,
      leftToRight: true,
      catGlitchSpacingOverride: .12,
    );
    expect(
      normal.catPlan!.crossings[1].startedAtProgress,
      CatRunProductionEventPolicy.normalFollowerTriggerProgress,
    );
    expect(CatRunProductionEventPolicy.glitchFollowerTriggerProgress, .025);
  });

  test('CAT GLITCH applies controlled, symmetric visible overlap', () {
    const stageWidth = 390.0;
    const dashboardCatUnit =
        CatRunV23Travel.catUnit *
        DashboardAmbientWildlifeStage.animalPresentationScale;

    for (final direction in CatRunV23Direction.values) {
      double visibleGap(double spacing) => CatRunV23Travel.visibleFollowerGap(
        stageWidth: stageWidth,
        eventProgress: .60,
        followerTriggerProgress: spacing,
        catUnit: dashboardCatUnit,
        direction: direction,
      );

      final baseline = visibleGap(.05);
      final candidate03 = visibleGap(.03);
      final selected = visibleGap(
        CatRunProductionEventPolicy.glitchFollowerTriggerProgress,
      );
      final candidate02 = visibleGap(.02);

      // Negative means silhouette overlap. The controlled GLITCH procession
      // deliberately becomes denser while retaining its ordered direction.
      expect(baseline, lessThan(0));
      expect(candidate03, lessThan(baseline));
      expect(selected, lessThan(candidate03));
      expect(candidate02, lessThan(selected));
      expect(selected.abs() / baseline.abs(), closeTo(2.787, .03));
    }

    final leftToRight = CatRunV23Travel.visibleFollowerGap(
      stageWidth: stageWidth,
      eventProgress: .60,
      followerTriggerProgress:
          CatRunProductionEventPolicy.glitchFollowerTriggerProgress,
      catUnit: dashboardCatUnit,
      direction: CatRunV23Direction.leftToRight,
    );
    final rightToLeft = CatRunV23Travel.visibleFollowerGap(
      stageWidth: stageWidth,
      eventProgress: .60,
      followerTriggerProgress:
          CatRunProductionEventPolicy.glitchFollowerTriggerProgress,
      catUnit: dashboardCatUnit,
      direction: CatRunV23Direction.rightToLeft,
    );
    expect(leftToRight, closeTo(rightToLeft, .000001));
  });

  test('CAT GLITCH projection ignores Dashboard normal spacing', () {
    const eventProgress = .60;
    const glitchSpacing =
        CatRunProductionEventPolicy.glitchFollowerTriggerProgress;

    for (final normalMultiplier in [.5, .88, 1.5]) {
      expect(
        ambientWildlifeV2CatCrossingProgress(
          eventProgress: eventProgress,
          startedAtProgress: glitchSpacing,
          isGlitch: true,
          normalFollowerSpacingMultiplier: normalMultiplier,
        ),
        closeTo(.575, .000001),
      );
    }
    expect(
      ambientWildlifeV2CatCrossingProgress(
        eventProgress: eventProgress,
        startedAtProgress:
            CatRunProductionEventPolicy.normalFollowerTriggerProgress,
        isGlitch: false,
        normalFollowerSpacingMultiplier: 2 / 3,
      ),
      closeTo(.50, .000001),
    );
  });

  test('CAT Preview SMOOTH levels vary only presentation continuity', () {
    const profiles = [
      AmbientWildlifeV2CatMotionProfile.s1,
      AmbientWildlifeV2CatMotionProfile.s2,
      AmbientWildlifeV2CatMotionProfile.s3,
      AmbientWildlifeV2CatMotionProfile.s4,
    ];
    final tunings = [
      for (final profile in profiles)
        ambientWildlifeV2CatSmoothTuning(profile)!,
    ];

    expect(tunings.map((tuning) => tuning.blendDuration.inMilliseconds), const [
      28,
      48,
      68,
      96,
    ]);
    expect(tunings.map((tuning) => tuning.maximumVisualAnchorOffset), const [
      .006,
      .012,
      .018,
      .024,
    ]);
    for (final tuning in tunings) {
      final offsets = <Offset>[
        for (
          var millisecond = 0;
          millisecond < CatRunV23Travel.crossingDuration.inMilliseconds;
          millisecond += 2
        )
          CatRunV23Travel.smoothVisualAnchorOffsetAt(
            millisecond / CatRunV23Travel.crossingDuration.inMilliseconds,
            tuning: tuning,
          ),
      ];
      expect(
        offsets
            .map((offset) => offset.distance)
            .every(
              (offset) => offset <= tuning.maximumVisualAnchorOffset + .000001,
            ),
        isTrue,
      );
      expect(offsets.toSet().length, greaterThan(1));
    }
    for (final profile in AmbientWildlifeV2CatMotionProfile.values) {
      expect(ambientWildlifeV2CatMotionCurve(profile), Curves.linear);
    }
    expect(
      ambientWildlifeV2CatSmoothTuning(
        AmbientWildlifeV2CatMotionProfile.current,
      ),
      isNull,
    );
    expect(CatRunV23Travel.crossingDuration, CatRunV24Travel.crossingDuration);
  });

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

  test('Dashboard projects FOX pack geometry with the common body scale', () {
    const width = 390.0;
    const scale = DashboardAmbientWildlifeStage.animalPresentationScale;
    final canonicalDistance = AmbientWildlifeV2Fox.juvenileFollowerSpacing;
    final projectedDistance = canonicalDistance * scale;
    final leader = AmbientWildlifeV2Fox.bodyCenterForProgress(
      stageWidth: width,
      progress: .5,
      leftToRight: true,
      trailingDistance: projectedDistance,
      presentationScale: scale,
    );

    expect(scale, .64);
    expect(projectedDistance, closeTo(canonicalDistance * .64, .001));
    expect(
      AmbientWildlifeV2Fox.lastActiveFoxHasFullyExited(
        stageWidth: width,
        progress: 1,
        leftToRight: true,
        juvenileCount: 2,
        presentationScale: scale,
      ),
      isTrue,
    );
    expect(leader.isFinite, isTrue);
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
      expect(BirdV1ProductionFlight.renderedSize, 38);
      expect(BirdV1ProductionFlight.normalSpatialSpacing, 50);
      expect(BirdV1ProductionFlight.glitchSpatialSpacing, 38);
      expect(
        BirdV1ProductionFlight.flightSpeed,
        BirdV1FlightSpeed.onePointFive,
      );

      final first = BirdV1ProductionFlight.frameFor(
        stageWidth: 390,
        elapsedMs: 0,
        instance: BirdV1ProductionFlight.instances.first,
      );
      final second = BirdV1ProductionFlight.frameFor(
        stageWidth: 390,
        elapsedMs: 63,
        instance: BirdV1ProductionFlight.instances.first,
      );
      final seam = BirdV1ProductionFlight.frameFor(
        stageWidth: 390,
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
      expect(
        BirdV1ProductionFlight.launchDelayFor(
          stageWidth: 390,
          instance: two.birdInstances[1],
        ),
        169,
      );
      expect(
        BirdV1ProductionFlight.launchDelayFor(
          stageWidth: 390,
          instance: glitch.birdInstances[1],
        ),
        128,
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
            final elapsed = BirdV1ProductionFlight.eventDurationMs(
              stageWidth: width,
              values: instances,
            );
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

  test(
    'BIRD uses the Dashboard common presentation without legacy correction',
    () {
      const scale = DashboardAmbientWildlifeStage.animalPresentationScale;
      expect(BirdV1ProductionFlight.renderedSize * scale, closeTo(24.32, .001));
      expect(BirdV1ProductionFlight.renderedSize, 38);
      expect(BirdV1ProductionFlight.baseTop, 17.25);
      expect(scale, .64);

      final canonicalEnvelopes =
          <List<BirdV1ProductionInstance>>[
            BirdV1ProductionFlight.instances.take(1).toList(),
            BirdV1ProductionFlight.instances.take(2).toList(),
            BirdV1ProductionFlight.instances,
            BirdV1ProductionFlight.glitchInstances,
          ].map(
            (instances) => BirdV1ProductionFlight.visibleEnvelopeFor(
              values: instances,
              presentationScale: 1,
              presentationTopCrop: 0,
            ),
          );
      for (final envelope in canonicalEnvelopes) {
        expect(envelope.top, greaterThan(3));
        expect(envelope.bottom, lessThan(99));
      }

      final canonicalSingle = BirdV1ProductionFlight.visibleEnvelopeFor(
        values: BirdV1ProductionFlight.instances.take(1).toList(),
        presentationScale: 1,
        presentationTopCrop: 0,
      );
      expect(
        (canonicalSingle.top + canonicalSingle.bottom) / 2,
        closeTo(36.25, .01),
      );

      final single = BirdV1ProductionFlight.visibleEnvelopeFor(
        values: BirdV1ProductionFlight.instances.take(1).toList(),
        presentationScale: scale,
        presentationTopCrop: DashboardAmbientWildlifeStage.topAirspaceCrop,
      );
      final pair = BirdV1ProductionFlight.visibleEnvelopeFor(
        values: BirdV1ProductionFlight.instances.take(2).toList(),
        presentationScale: scale,
        presentationTopCrop: DashboardAmbientWildlifeStage.topAirspaceCrop,
      );
      final flock = BirdV1ProductionFlight.visibleEnvelopeFor(
        values: BirdV1ProductionFlight.glitchInstances,
        presentationScale: scale,
        presentationTopCrop: DashboardAmbientWildlifeStage.topAirspaceCrop,
      );
      final trio = BirdV1ProductionFlight.visibleEnvelopeFor(
        values: BirdV1ProductionFlight.instances,
        presentationScale: scale,
        presentationTopCrop: DashboardAmbientWildlifeStage.topAirspaceCrop,
      );
      expect(single.top, greaterThan(0));
      expect(flock.top, greaterThan(0));
      expect(
        flock.bottom,
        lessThan(
          DashboardAmbientWildlifeStage.height -
              DashboardAmbientWildlifeStage.groundInset,
        ),
      );
      expect(pair.top, lessThan(single.top));
      expect(flock.bottom, greaterThan(pair.bottom));
      expect(
        DashboardAmbientWildlifeStage.height -
            DashboardAmbientWildlifeStage.groundInset -
            flock.bottom,
        greaterThan(10),
      );
      expect(single.top, closeTo(36.86, .01));
      expect(single.bottom, closeTo(63.54, .01));
      expect((single.top + single.bottom) / 2, closeTo(50.20, .01));
      expect((pair.top + pair.bottom) / 2, closeTo(47.00, .01));
      expect((trio.top + trio.bottom) / 2, closeTo(49.56, .01));
      expect((flock.top + flock.bottom) / 2, closeTo(49.24, .01));
      expect(flock.top, closeTo(28.95, .01));
      expect(flock.bottom, closeTo(69.53, .01));
    },
  );

  test('BIRD spatial launch spacing stays readable across stage widths', () {
    for (final width in [320.0, 390.0, 900.0]) {
      final pair = BirdV1ProductionFlight.instances.take(2).toList();
      final delay = BirdV1ProductionFlight.launchDelayFor(
        stageWidth: width,
        instance: pair.last,
      );
      final velocity = BirdV1ProductionFlight.crossingPixelsPerMs(width);
      expect(delay * velocity, closeTo(50, .35), reason: '$width pair');

      final glitchDelay = BirdV1ProductionFlight.launchDelayFor(
        stageWidth: width,
        instance: BirdV1ProductionFlight.glitchInstances[1],
      );
      expect(glitchDelay * velocity, closeTo(38, .35), reason: '$width glitch');

      const scale = DashboardAmbientWildlifeStage.animalPresentationScale;
      final projectedDelay = BirdV1ProductionFlight.launchDelayFor(
        stageWidth: width,
        instance: pair.last,
        presentationScale: scale,
      );
      final projectedVelocity = BirdV1ProductionFlight.crossingPixelsPerMs(
        width,
        presentationScale: scale,
      );
      expect(
        projectedDelay * projectedVelocity,
        closeTo(BirdV1ProductionFlight.normalSpatialSpacing * scale, .35),
        reason: '$width Dashboard pair',
      );

      final projectedGlitchDelay = BirdV1ProductionFlight.launchDelayFor(
        stageWidth: width,
        instance: BirdV1ProductionFlight.glitchInstances[1],
        presentationScale: scale,
      );
      expect(
        projectedGlitchDelay * projectedVelocity,
        closeTo(BirdV1ProductionFlight.glitchSpatialSpacing * scale, .35),
        reason: '$width Dashboard GLITCH10',
      );

      for (final values in [
        pair,
        BirdV1ProductionFlight.instances,
        BirdV1ProductionFlight.glitchInstances,
      ]) {
        final elapsed = BirdV1ProductionFlight.eventDurationMs(
          stageWidth: width,
          values: values,
          presentationScale: scale,
        );
        expect(
          values.every(
            (instance) => BirdV1ProductionFlight.hasFullyExited(
              stageWidth: width,
              elapsedMs: elapsed,
              leftToRight: true,
              instance: instance,
              presentationScale: scale,
            ),
          ),
          isTrue,
          reason: '$width Dashboard full-exit ${values.length}',
        );
      }
    }
  });

  test('Dashboard projects BAT formation launch spacing with body scale', () {
    const scale = DashboardAmbientWildlifeStage.animalPresentationScale;
    final trailing = BatV3ProductionFlight.instances[1];
    final canonicalProgress = BatV3ProductionFlight.progressFor(
      elapsedMs: 120,
      durationMs: BatV3ProductionFlight.fullSpeedDurationMs,
      instance: trailing,
    );
    final projectedProgress = BatV3ProductionFlight.progressFor(
      elapsedMs: 120,
      durationMs: BatV3ProductionFlight.fullSpeedDurationMs,
      instance: trailing,
      presentationScale: scale,
    );

    expect(canonicalProgress, 0);
    expect(projectedProgress, greaterThan(0));
    expect(
      BatV3ProductionFlight.eventDurationMsFor(
        instances: BatV3ProductionFlight.instances,
        presentationScale: scale,
      ),
      lessThan(BatV3ProductionFlight.fullSpeedDurationMs + 360),
    );
  });

  test(
    'BIRD keeps static formation separate from calmer group vertical motion',
    () {
      expect(
        BirdV1ProductionFlight.verticalMotionScaleFor(
          BirdV1ProductionFlight.instances.take(1).toList(),
        ),
        1,
      );
      expect(
        BirdV1ProductionFlight.verticalMotionScaleFor(
          BirdV1ProductionFlight.instances.take(2).toList(),
        ),
        .75,
      );
      expect(
        BirdV1ProductionFlight.verticalMotionScaleFor(
          BirdV1ProductionFlight.instances,
        ),
        .75,
      );
      expect(
        BirdV1ProductionFlight.verticalMotionScaleFor(
          BirdV1ProductionFlight.glitchInstances,
        ),
        .65,
      );
      expect(
        BirdV1ProductionFlight.instances.map((instance) => instance.formationY),
        [0, -10, 8],
      );
      expect(
        BirdV1ProductionFlight.instances.map(
          (instance) => instance.launchSpacingPx,
        ),
        [0, 50, 100],
      );
      expect(BirdV1FlightTuning.birdFlutterVerticalAmplitude, .45);
      expect(BirdV1FlightTuning.birdFlutterRotationAmplitude, .004);
      expect(BirdV1ProductionFlight.cycleDurationMs, 484);
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
