import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bat_v3_flight_motion_poc.dart';
import 'bat_v3_source_data.dart';
import 'bird_v1_flight_preview.dart';
import 'cat_run_coat_patterns.dart';
import 'cat_run_v23_production_preview.dart';
import 'cat_run_v24_presentation.dart';
import 'fox_pattern_preview.dart';
import 'fox_run_v1_section.dart';

enum AmbientWildlifeV2Species { cat, bat, fox, birds }

/// Explicit production variants used only by the Dashboard preview.  They
/// select from the same production formations; they do not create preview
/// geometry.
enum AmbientWildlifeV2ForcedVariant { one, two, three, glitch10 }

/// Dashboard Preview comparison profiles. Production keeps [current] until a
/// separate acceptance task deliberately adopts one of the smooth candidates.
enum AmbientWildlifeV2CatMotionProfile { current, smoothB, smoothC, smoothMax }

Curve ambientWildlifeV2CatMotionCurve(
  AmbientWildlifeV2CatMotionProfile profile,
) => switch (profile) {
  AmbientWildlifeV2CatMotionProfile.current => Curves.linear,
  AmbientWildlifeV2CatMotionProfile.smoothB ||
  AmbientWildlifeV2CatMotionProfile.smoothC ||
  AmbientWildlifeV2CatMotionProfile.smoothMax => Curves.linear,
};

/// Preview smooth candidates vary presentation continuity only. They never alter the
/// production crossing duration, speed, frame order, or travel curve.
CatRunV23SmoothTuning? ambientWildlifeV2CatSmoothTuning(
  AmbientWildlifeV2CatMotionProfile profile,
) => switch (profile) {
  AmbientWildlifeV2CatMotionProfile.current => null,
  AmbientWildlifeV2CatMotionProfile.smoothB => CatRunV23Travel.smoothBTuning,
  AmbientWildlifeV2CatMotionProfile.smoothC => CatRunV23Travel.smoothCTuning,
  AmbientWildlifeV2CatMotionProfile.smoothMax =>
    CatRunV23Travel.smoothMaxTuning,
};

String ambientWildlifeV2CatMotionProfileLabel(
  AmbientWildlifeV2CatMotionProfile profile,
) => switch (profile) {
  AmbientWildlifeV2CatMotionProfile.current => 'CURRENT',
  AmbientWildlifeV2CatMotionProfile.smoothB => 'SMOOTH B',
  AmbientWildlifeV2CatMotionProfile.smoothC => 'SMOOTH C',
  AmbientWildlifeV2CatMotionProfile.smoothMax => 'SMOOTH MAX',
};

/// GLITCH has a fixed production spacing authority. Dashboard presentation
/// may compact normal CAT chains, but must never derive a GLITCH offset from
/// that normal-only multiplier.
double ambientWildlifeV2CatCrossingProgress({
  required double eventProgress,
  required double startedAtProgress,
  required bool isGlitch,
  required double normalFollowerSpacingMultiplier,
}) =>
    eventProgress -
    startedAtProgress * (isGlitch ? 1 : normalFollowerSpacingMultiplier);

@immutable
class AmbientWildlifeV2SpeciesDefinition {
  const AmbientWildlifeV2SpeciesDefinition({
    required this.species,
    required this.available,
  });

  final AmbientWildlifeV2Species species;
  final bool available;
}

/// The single availability authority for Ambient Wildlife V2. Future species
/// become selectable by supplying their production event/renderer here rather
/// than rewriting the selector or AUTO lifecycle.
abstract final class AmbientWildlifeV2Registry {
  static const species = <AmbientWildlifeV2SpeciesDefinition>[
    AmbientWildlifeV2SpeciesDefinition(
      species: AmbientWildlifeV2Species.cat,
      available: true,
    ),
    AmbientWildlifeV2SpeciesDefinition(
      species: AmbientWildlifeV2Species.bat,
      available: true,
    ),
    AmbientWildlifeV2SpeciesDefinition(
      species: AmbientWildlifeV2Species.fox,
      available: true,
    ),
    AmbientWildlifeV2SpeciesDefinition(
      species: AmbientWildlifeV2Species.birds,
      available: true,
    ),
  ];

  static bool available(AmbientWildlifeV2Species value) =>
      species.firstWhere((definition) => definition.species == value).available;

  static List<AmbientWildlifeV2Species> get availableSpecies => species
      .where((definition) => definition.available)
      .map((definition) => definition.species)
      .toList(growable: false);
}

@immutable
class AmbientWildlifeV2EventPlan {
  const AmbientWildlifeV2EventPlan._({
    required this.species,
    required this.leftToRight,
    required this.isGlitch,
    required this.catPlan,
    required this.catExecutor,
    required this.batInstances,
    required this.birdInstances,
    required this.foxSpawn,
  });

  final AmbientWildlifeV2Species species;
  final bool leftToRight;
  final bool isGlitch;
  final CatRunProductionEventPlan? catPlan;
  final CatRunProductionEventExecutor? catExecutor;
  final List<BatV3ProductionInstance> batInstances;
  final List<BirdV1ProductionInstance> birdInstances;
  final AmbientWildlifeV2FoxSpawn? foxSpawn;

  bool get isCat => species == AmbientWildlifeV2Species.cat;
  bool get isBat => species == AmbientWildlifeV2Species.bat;
  bool get isBird => species == AmbientWildlifeV2Species.birds;
  bool get isFox => species == AmbientWildlifeV2Species.fox;

  static AmbientWildlifeV2EventPlan resolve({
    required AmbientWildlifeV2Species species,
    required bool leftToRight,
    required int Function(int max) nextInt,
  }) {
    assert(AmbientWildlifeV2Registry.available(species));
    final direction = leftToRight
        ? CatRunV23Direction.leftToRight
        : CatRunV23Direction.rightToLeft;
    final random = math.Random(nextInt(1 << 20));
    return switch (species) {
      AmbientWildlifeV2Species.cat => _catPlan(
        leftToRight: leftToRight,
        nextInt: nextInt,
        random: random,
        direction: direction,
      ),
      AmbientWildlifeV2Species.bat => _batPlan(
        leftToRight: leftToRight,
        nextInt: nextInt,
      ),
      AmbientWildlifeV2Species.fox => _foxPlan(
        leftToRight: leftToRight,
        nextInt: nextInt,
      ),
      AmbientWildlifeV2Species.birds => _birdPlan(
        leftToRight: leftToRight,
        nextInt: nextInt,
      ),
    };
  }

  /// A deterministic entry point for production-surface inspection. Random
  /// Dashboard scheduling continues to call [resolve]; this is intentionally
  /// opt-in so production probabilities remain untouched.
  static AmbientWildlifeV2EventPlan forced({
    required AmbientWildlifeV2Species species,
    required AmbientWildlifeV2ForcedVariant variant,
    required bool leftToRight,
    double? catGlitchSpacingOverride,
  }) {
    final direction = leftToRight
        ? CatRunV23Direction.leftToRight
        : CatRunV23Direction.rightToLeft;
    final count = switch (variant) {
      AmbientWildlifeV2ForcedVariant.one => 1,
      AmbientWildlifeV2ForcedVariant.two => 2,
      AmbientWildlifeV2ForcedVariant.three => 3,
      AmbientWildlifeV2ForcedVariant.glitch10 => 10,
    };
    return switch (species) {
      AmbientWildlifeV2Species.cat => AmbientWildlifeV2EventPlan._(
        species: species,
        leftToRight: leftToRight,
        isGlitch: variant == AmbientWildlifeV2ForcedVariant.glitch10,
        catPlan: variant == AmbientWildlifeV2ForcedVariant.glitch10
            ? CatRunProductionEventPlan.forceGlitch(
                random: math.Random(0),
                direction: direction,
                spacingOverride: catGlitchSpacingOverride,
              )
            : CatRunProductionEventPlan.forceCount(
                random: math.Random(0),
                direction: direction,
                count: count,
              ),
        catExecutor: null,
        batInstances: const [],
        birdInstances: const [],
        foxSpawn: null,
      )._withExecutor(),
      AmbientWildlifeV2Species.bat => AmbientWildlifeV2EventPlan._(
        species: species,
        leftToRight: leftToRight,
        isGlitch: variant == AmbientWildlifeV2ForcedVariant.glitch10,
        catPlan: null,
        catExecutor: null,
        batInstances: variant == AmbientWildlifeV2ForcedVariant.glitch10
            ? BatV3ProductionFlight.glitchInstances
            : BatV3ProductionFlight.instances
                  .take(count)
                  .toList(growable: false),
        birdInstances: const [],
        foxSpawn: null,
      ),
      AmbientWildlifeV2Species.fox => AmbientWildlifeV2EventPlan._(
        species: species,
        leftToRight: leftToRight,
        isGlitch: variant == AmbientWildlifeV2ForcedVariant.glitch10,
        catPlan: null,
        catExecutor: null,
        batInstances: const [],
        birdInstances: const [],
        foxSpawn: AmbientWildlifeV2FoxSpawn(
          pattern: FoxRunV1Pattern.fox,
          pack: switch (variant) {
            AmbientWildlifeV2ForcedVariant.one => AmbientWildlifeV2FoxPack.one,
            AmbientWildlifeV2ForcedVariant.two => AmbientWildlifeV2FoxPack.two,
            AmbientWildlifeV2ForcedVariant.three =>
              AmbientWildlifeV2FoxPack.three,
            AmbientWildlifeV2ForcedVariant.glitch10 =>
              AmbientWildlifeV2FoxPack.gricthTen,
          },
        ),
      ),
      AmbientWildlifeV2Species.birds => AmbientWildlifeV2EventPlan._(
        species: species,
        leftToRight: leftToRight,
        isGlitch: variant == AmbientWildlifeV2ForcedVariant.glitch10,
        catPlan: null,
        catExecutor: null,
        batInstances: const [],
        birdInstances: variant == AmbientWildlifeV2ForcedVariant.glitch10
            ? BirdV1ProductionFlight.glitchInstances
            : BirdV1ProductionFlight.instances
                  .take(count)
                  .toList(growable: false),
        foxSpawn: null,
      ),
    };
  }

  AmbientWildlifeV2EventPlan _withExecutor() => AmbientWildlifeV2EventPlan._(
    species: species,
    leftToRight: leftToRight,
    isGlitch: isGlitch,
    catPlan: catPlan,
    catExecutor: CatRunProductionEventExecutor(
      plan: catPlan!,
      random: math.Random(0),
    ),
    batInstances: batInstances,
    birdInstances: birdInstances,
    foxSpawn: foxSpawn,
  );

  static AmbientWildlifeV2EventPlan _catPlan({
    required bool leftToRight,
    required int Function(int max) nextInt,
    required math.Random random,
    required CatRunV23Direction direction,
  }) {
    final eventRoll = nextInt(20);
    final catPlan = CatRunProductionEventPlan.sampledForDirection(
      source: CatRunProductionEventSource.sandbox,
      random: random,
      direction: direction,
      eventRoll: eventRoll,
    );
    return AmbientWildlifeV2EventPlan._(
      species: AmbientWildlifeV2Species.cat,
      leftToRight: leftToRight,
      isGlitch: catPlan.isGlitch,
      catPlan: catPlan,
      catExecutor: CatRunProductionEventExecutor(plan: catPlan, random: random),
      batInstances: const [],
      birdInstances: const [],
      foxSpawn: null,
    );
  }

  static AmbientWildlifeV2EventPlan _batPlan({
    required bool leftToRight,
    required int Function(int max) nextInt,
  }) {
    final eventRoll = nextInt(20);
    final countRoll = nextInt(100);
    final glitch = BatV3ProductionEventPolicy.isGlitchRoll(eventRoll);
    return AmbientWildlifeV2EventPlan._(
      species: AmbientWildlifeV2Species.bat,
      leftToRight: leftToRight,
      isGlitch: glitch,
      catPlan: null,
      catExecutor: null,
      batInstances: BatV3ProductionEventPolicy.instancesFor(
        eventRoll: eventRoll,
        countRoll: countRoll,
      ),
      birdInstances: const [],
      foxSpawn: null,
    );
  }

  static AmbientWildlifeV2EventPlan _foxPlan({
    required bool leftToRight,
    required int Function(int max) nextInt,
  }) => AmbientWildlifeV2EventPlan._(
    species: AmbientWildlifeV2Species.fox,
    leftToRight: leftToRight,
    isGlitch: false,
    catPlan: null,
    catExecutor: null,
    batInstances: const [],
    birdInstances: const [],
    foxSpawn: AmbientWildlifeV2FoxSpawn.sample(nextInt: nextInt),
  );

  static AmbientWildlifeV2EventPlan _birdPlan({
    required bool leftToRight,
    required int Function(int max) nextInt,
  }) {
    final eventRoll = nextInt(20);
    final countRoll = nextInt(100);
    final instances = BirdV1ProductionEventPolicy.instancesFor(
      eventRoll: eventRoll,
      countRoll: countRoll,
    );
    return AmbientWildlifeV2EventPlan._(
      species: AmbientWildlifeV2Species.birds,
      leftToRight: leftToRight,
      isGlitch: BirdV1ProductionEventPolicy.isGlitchRoll(eventRoll),
      catPlan: null,
      catExecutor: null,
      batInstances: const [],
      birdInstances: instances,
      foxSpawn: null,
    );
  }
}

/// Dashboard production authority for the approved Bird V1 candidate. This
/// consumes the sandbox's fixed source cels and tuning math without exposing
/// any of its diagnostic controls to Ambient Wildlife.
abstract final class BirdV1ProductionFlight {
  // 38px is the smallest candidate needed to keep the frozen GLITCH10
  // formation 3px clear of the top while lifting the single Bird center.
  static const renderedSize = 38.0;
  static const stageHeight = BatV3ProductionFlight.stageHeight;
  static const crossingDuration = Duration(milliseconds: 1467);
  static const entryExitGap = 3.0;
  // With the -13px GLITCH10 formation member and scaled bob/flutter, this
  // retains a 3.05px top clearance while moving the single Bird visible
  // center from Y=40 to Y=36.25 in the canonical Ambient airspace.
  static const baseTop = 17.25;
  static const flutterOn = true;
  static const cadence = BirdV1Cadence.cruise;
  static const transition = BirdV1Transition.overlap20;
  static const flightSpeed = BirdV1FlightSpeed.onePointFive;

  /// Spatial separation is the authority; launch time is derived from the
  /// actual stage velocity so a flock keeps this clearance at every width.
  static const normalSpatialSpacing = 50.0;
  static const glitchSpatialSpacing = 38.0;
  static const instances = <BirdV1ProductionInstance>[
    BirdV1ProductionInstance(
      identifier: 0,
      phaseOffsetMs: 0,
      launchSpacingPx: 0,
      formationY: 0,
    ),
    BirdV1ProductionInstance(
      identifier: 1,
      phaseOffsetMs: 77,
      launchSpacingPx: normalSpatialSpacing,
      formationY: -10,
    ),
    BirdV1ProductionInstance(
      identifier: 2,
      phaseOffsetMs: 154,
      launchSpacingPx: normalSpatialSpacing * 2,
      formationY: 8,
    ),
  ];
  static const glitchInstances = <BirdV1ProductionInstance>[
    BirdV1ProductionInstance(
      identifier: 0,
      phaseOffsetMs: 0,
      launchSpacingPx: 0,
      formationY: 0,
    ),
    BirdV1ProductionInstance(
      identifier: 1,
      phaseOffsetMs: 47,
      launchSpacingPx: glitchSpatialSpacing,
      formationY: -9,
    ),
    BirdV1ProductionInstance(
      identifier: 2,
      phaseOffsetMs: 94,
      launchSpacingPx: glitchSpatialSpacing * 2,
      formationY: 6,
    ),
    BirdV1ProductionInstance(
      identifier: 3,
      phaseOffsetMs: 141,
      launchSpacingPx: glitchSpatialSpacing * 3,
      formationY: -4,
    ),
    BirdV1ProductionInstance(
      identifier: 4,
      phaseOffsetMs: 188,
      launchSpacingPx: glitchSpatialSpacing * 4,
      formationY: 10,
    ),
    BirdV1ProductionInstance(
      identifier: 5,
      phaseOffsetMs: 235,
      launchSpacingPx: glitchSpatialSpacing * 5,
      formationY: -13,
    ),
    BirdV1ProductionInstance(
      identifier: 6,
      phaseOffsetMs: 282,
      launchSpacingPx: glitchSpatialSpacing * 6,
      formationY: 3,
    ),
    BirdV1ProductionInstance(
      identifier: 7,
      phaseOffsetMs: 329,
      launchSpacingPx: glitchSpatialSpacing * 7,
      formationY: -10,
    ),
    BirdV1ProductionInstance(
      identifier: 8,
      phaseOffsetMs: 376,
      launchSpacingPx: glitchSpatialSpacing * 8,
      formationY: 9,
    ),
    BirdV1ProductionInstance(
      identifier: 9,
      phaseOffsetMs: 423,
      launchSpacingPx: glitchSpatialSpacing * 9,
      formationY: -1,
    ),
  ];

  static const _bobAmplitude = 1.4;
  static const _flutterAmplitude =
      BirdV1FlightTuning.birdFlutterVerticalAmplitude;
  static const _glitchVerticalMotionScale = .65;
  static const _minimumTopClearance =
      baseTop -
      13 -
      (_bobAmplitude + _flutterAmplitude) * _glitchVerticalMotionScale;
  static const _maximumBottom =
      baseTop +
      10 +
      renderedSize +
      (_bobAmplitude + _flutterAmplitude) * _glitchVerticalMotionScale;

  static List<int> get frameSet => BirdV1SourceSet.cycle;
  static List<int> get holds => BirdV1FlightTuning.cruiseHoldsMs;
  static int get transitionMs => BirdV1FlightTuning.transitionMs(transition);
  static int get cycleDurationMs => BirdV1FlightTuning.cycleDurationMs(cadence);

  static double verticalMotionScaleFor(List<BirdV1ProductionInstance> values) =>
      switch (values.length) {
        0 || 1 => 1,
        2 || 3 => .75,
        _ => .65,
      };
  static double get minimumTopClearance => _minimumTopClearance;
  static double get maximumBottom => _maximumBottom;
  static double groundClearanceFor(double groundY) => groundY - maximumBottom;

  static ({double top, double bottom}) visibleEnvelopeFor({
    required List<BirdV1ProductionInstance> values,
    required double presentationScale,
    required double presentationTopCrop,
  }) {
    final minimumFormationY = values
        .map((value) => value.formationY)
        .reduce(math.min);
    final maximumFormationY = values
        .map((value) => value.formationY)
        .reduce(math.max);
    final motionScale = verticalMotionScaleFor(values);
    final verticalAmplitude = (_bobAmplitude + _flutterAmplitude) * motionScale;
    return (
      top:
          presentationTopCrop +
          (baseTop + minimumFormationY - verticalAmplitude) * presentationScale,
      bottom:
          presentationTopCrop +
          (baseTop + maximumFormationY + renderedSize + verticalAmplitude) *
              presentationScale,
    );
  }

  /// Maps canonical Bird formation geometry into the presentation coordinate
  /// system. A compact Dashboard must reduce its body and its separation by
  /// the same factor; the canonical Sandbox continues to use the default 1x.
  static double crossingPixelsPerMs(
    double stageWidth, {
    double presentationScale = 1,
  }) =>
      (stageWidth + (renderedSize + entryExitGap * 2) * presentationScale) /
      crossingDuration.inMilliseconds;

  static int launchDelayFor({
    required double stageWidth,
    required BirdV1ProductionInstance instance,
    double presentationScale = 1,
  }) =>
      (instance.launchSpacingPx *
              presentationScale /
              crossingPixelsPerMs(
                stageWidth,
                presentationScale: presentationScale,
              ))
          .round();

  static int eventDurationMs({
    required double stageWidth,
    required List<BirdV1ProductionInstance> values,
    double presentationScale = 1,
  }) =>
      crossingDuration.inMilliseconds +
      values
          .map(
            (value) => launchDelayFor(
              stageWidth: stageWidth,
              instance: value,
              presentationScale: presentationScale,
            ),
          )
          .reduce(math.max);

  static double progressFor({
    required double stageWidth,
    required int elapsedMs,
    required BirdV1ProductionInstance instance,
    double presentationScale = 1,
  }) =>
      ((elapsedMs -
                  launchDelayFor(
                    stageWidth: stageWidth,
                    instance: instance,
                    presentationScale: presentationScale,
                  )) /
              crossingDuration.inMilliseconds)
          .clamp(0, 1);

  static double leftFor({
    required double stageWidth,
    required double progress,
    required bool leftToRight,
    double presentationScale = 1,
  }) {
    final entry = -(renderedSize + entryExitGap) * presentationScale;
    final exit = stageWidth + entryExitGap * presentationScale;
    final left = entry + (exit - entry) * progress;
    return leftToRight ? left : entry + exit - left;
  }

  static bool isInstanceComplete({
    required double stageWidth,
    required int elapsedMs,
    required BirdV1ProductionInstance instance,
    double presentationScale = 1,
  }) =>
      elapsedMs >=
      crossingDuration.inMilliseconds +
          launchDelayFor(
            stageWidth: stageWidth,
            instance: instance,
            presentationScale: presentationScale,
          );

  static bool hasFullyExited({
    required double stageWidth,
    required int elapsedMs,
    required bool leftToRight,
    required BirdV1ProductionInstance instance,
    double presentationScale = 1,
  }) {
    final left = leftFor(
      stageWidth: stageWidth,
      progress: progressFor(
        stageWidth: stageWidth,
        elapsedMs: elapsedMs,
        instance: instance,
        presentationScale: presentationScale,
      ),
      leftToRight: leftToRight,
      presentationScale: presentationScale,
    );
    return leftToRight
        ? left >= stageWidth + entryExitGap * presentationScale
        : left + renderedSize * presentationScale <=
              -entryExitGap * presentationScale;
  }

  static BirdV1ProductionFrame frameFor({
    required double stageWidth,
    required int elapsedMs,
    required BirdV1ProductionInstance instance,
    double presentationScale = 1,
  }) {
    final localElapsed =
        math.max(
          0,
          elapsedMs -
              launchDelayFor(
                stageWidth: stageWidth,
                instance: instance,
                presentationScale: presentationScale,
              ),
        ) +
        instance.phaseOffsetMs;
    var remaining = localElapsed % cycleDurationMs;
    for (var index = 0; index < holds.length; index++) {
      final hold = holds[index];
      if (remaining < hold) {
        return BirdV1ProductionFrame(
          frame: frameSet[index],
          previousFrame:
              frameSet[(index - 1 + frameSet.length) % frameSet.length],
          transitionElapsedMs: remaining,
          motionElapsedMs: localElapsed,
        );
      }
      remaining -= hold;
    }
    throw StateError('Bird V1 cruise timing must resolve a source frame.');
  }
}

class BirdV1ProductionFrame {
  const BirdV1ProductionFrame({
    required this.frame,
    required this.previousFrame,
    required this.transitionElapsedMs,
    required this.motionElapsedMs,
  });

  final int frame;
  final int previousFrame;
  final int transitionElapsedMs;
  final int motionElapsedMs;
}

class BirdV1ProductionInstance {
  const BirdV1ProductionInstance({
    required this.identifier,
    required this.phaseOffsetMs,
    required this.launchSpacingPx,
    required this.formationY,
  });

  final int identifier;
  final int phaseOffsetMs;
  final double launchSpacingPx;
  final double formationY;
}

/// Bird-specific selection after the normal Ambient species picker. It mirrors
/// the established 5% rare-event boundary without changing CAT/BAT/FOX RNG.
abstract final class BirdV1ProductionEventPolicy {
  static const glitchProbability = .05;
  static const normalOneProbability = .50;
  static const normalTwoProbability = .30;
  static const normalThreeProbability = .20;

  static bool isGlitchRoll(int roll) {
    if (roll < 0 || roll >= 20) throw ArgumentError.value(roll, 'roll');
    return roll == 0;
  }

  static int normalCountForRoll(int roll) {
    if (roll < 0 || roll >= 100) throw ArgumentError.value(roll, 'roll');
    if (roll < 50) return 1;
    if (roll < 80) return 2;
    return 3;
  }

  static List<BirdV1ProductionInstance> instancesFor({
    required int eventRoll,
    required int countRoll,
  }) => isGlitchRoll(eventRoll)
      ? BirdV1ProductionFlight.glitchInstances
      : BirdV1ProductionFlight.instances
            .take(normalCountForRoll(countRoll))
            .toList(growable: false);
}

enum AmbientWildlifeV2FoxPack { one, two, three, gricthTen }

/// Fixed once a FOX spawn has already been selected by Ambient's existing
/// species picker. This result never participates in species selection.
@immutable
class AmbientWildlifeV2FoxSpawn {
  const AmbientWildlifeV2FoxSpawn({required this.pattern, required this.pack});

  static const patternProbability = .80;
  static const abnormalPackProbability = .05;

  final FoxRunV1Pattern pattern;
  final AmbientWildlifeV2FoxPack pack;

  int get juvenileCount => switch (pack) {
    AmbientWildlifeV2FoxPack.one => 0,
    AmbientWildlifeV2FoxPack.two => 1,
    AmbientWildlifeV2FoxPack.three => 2,
    AmbientWildlifeV2FoxPack.gricthTen => 9,
  };

  static AmbientWildlifeV2FoxSpawn sample({
    required int Function(int max) nextInt,
  }) {
    final pattern = nextInt(100) < 80
        ? FoxRunV1Pattern.fox
        : FoxRunV1Pattern.off;
    final pack = nextInt(100) >= 95
        ? AmbientWildlifeV2FoxPack.gricthTen
        : _normalPackForRoll(nextInt(100));
    return AmbientWildlifeV2FoxSpawn(pattern: pattern, pack: pack);
  }

  static AmbientWildlifeV2FoxPack _normalPackForRoll(int roll) {
    assert(roll >= 0 && roll < 100);
    if (roll < 55) return AmbientWildlifeV2FoxPack.one;
    if (roll < 85) return AmbientWildlifeV2FoxPack.two;
    return AmbientWildlifeV2FoxPack.three;
  }
}

/// FOX's V2 renderer owns a 48px torso authority. The canonical FOX cels are
/// mapped into that production footprint; the Sandbox 1x canvas size is not
/// used here.
abstract final class AmbientWildlifeV2Fox {
  /// Sandbox/canonical V2 speed, equivalent to FOX RUN's FASTEST selection.
  static const crossingDuration = Duration(milliseconds: 1600);

  /// Dashboard-only production speed, equivalent to FOX RUN's FASTER option.
  static const dashboardCrossingDuration = Duration(milliseconds: 1800);
  static const frameDuration = Duration(milliseconds: 80);
  static const selectedFrames = <int>[0, 2, 4, 5, 6];
  static const neutralFrame = 4;
  static const verticalFlutterAmplitude = 1.0;
  static const bodyFlexAmplitude = 2.0;
  static const ambientTorsoLength = 48.0;
  static const juvenileTorsoLength =
      FoxRunV1ProductionGeometry.juvenileTorsoLength;
  static const displayScale =
      ambientTorsoLength / FoxRunV1ProductionGeometry.torsoLength;
  static final canvasSize = Size(
    FoxRunV1ProductionGeometry.canvasSize.width * displayScale,
    FoxRunV1ProductionGeometry.canvasSize.height * displayScale,
  );
  static double get juvenileBodyScale =>
      juvenileTorsoLength / ambientTorsoLength;
  static Size canvasSizeFor(double bodyScale) =>
      Size(canvasSize.width * bodyScale, canvasSize.height * bodyScale);

  static const _bodyOrigin = FoxRunV1ProductionGeometry.bodyOrigin;
  static const _virtualGround = FoxRunV1ProductionGeometry.virtualGround;
  static const _visibleBounds =
      FoxRunV1ProductionGeometry.visibleBoundsCanonical;
  static double get juvenileVisibleWidth =>
      _visibleBounds.width * displayScale * juvenileBodyScale;
  static double get juvenileFollowerSpacing =>
      juvenileVisibleWidth + FoxRunV1ProductionGeometry.crossingSafetyGap;

  static String assetForFrame(int frame) =>
      'assets/animations/sandbox/fox_v1/canonical/'
      'frame_${(frame + 1).toString().padLeft(2, '0')}.png';

  static int frameAtElapsed(Duration elapsed) =>
      FoxRunV1Motion.frameAtElapsed(elapsed, selectedFrames: selectedFrames);

  static double flutterAtElapsed(Duration elapsed) =>
      FoxRunV1Motion.verticalFlutterOffset(
        phase: FoxRunV1Motion.flutterPhaseAtElapsed(elapsed),
        amplitude: verticalFlutterAmplitude,
      );

  static double bodyFlexAtElapsed(Duration elapsed) =>
      FoxRunV1Motion.bodyFlexOffsetAtElapsed(
        elapsed: elapsed,
        amplitude: bodyFlexAmplitude,
        motion: FoxRunV1BodyFlexMotion.smooth,
        shrinkEnabled: false,
      );

  static double bodyFlexScale(double bodyFlexOffset, {double bodyScale = 1}) {
    final torsoToGround =
        (_virtualGround - _bodyOrigin.dy) * displayScale * bodyScale;
    return 1 + bodyFlexOffset / torsoToGround;
  }

  static Offset imageTopLeft({
    required double bodyCenterX,
    required double stageGroundY,
    double verticalFlutterOffset = 0,
    double bodyScale = 1,
  }) => Offset(
    bodyCenterX - _bodyOrigin.dx * displayScale * bodyScale,
    stageGroundY -
        _virtualGround * displayScale * bodyScale +
        verticalFlutterOffset,
  );

  static Rect visibleBoundsFor({
    required double bodyCenterX,
    required double stageGroundY,
    required bool leftToRight,
    double verticalFlutterOffset = 0,
    double bodyScale = 1,
  }) {
    final image = imageTopLeft(
      bodyCenterX: bodyCenterX,
      stageGroundY: stageGroundY,
      verticalFlutterOffset: verticalFlutterOffset,
      bodyScale: bodyScale,
    );
    final relativeLeft =
        (_visibleBounds.left - _bodyOrigin.dx) * displayScale * bodyScale;
    final relativeRight =
        (_visibleBounds.right - _bodyOrigin.dx) * displayScale * bodyScale;
    final renderedLeft = leftToRight ? relativeLeft : -relativeRight;
    final renderedRight = leftToRight ? relativeRight : -relativeLeft;
    return Rect.fromLTRB(
      bodyCenterX + renderedLeft,
      image.dy + _visibleBounds.top * displayScale * bodyScale,
      bodyCenterX + renderedRight,
      image.dy + _visibleBounds.bottom * displayScale * bodyScale,
    );
  }

  static double bodyCenterForProgress({
    required double stageWidth,
    required double progress,
    required bool leftToRight,
    double trailingDistance = 0,
    double presentationScale = 1,
  }) {
    final relativeLeft =
        (_visibleBounds.left - _bodyOrigin.dx) *
        displayScale *
        presentationScale;
    final relativeRight =
        (_visibleBounds.right - _bodyOrigin.dx) *
        displayScale *
        presentationScale;
    final renderedLeft = leftToRight ? relativeLeft : -relativeRight;
    final renderedRight = leftToRight ? relativeRight : -relativeLeft;
    final safetyGap =
        FoxRunV1ProductionGeometry.crossingSafetyGap * presentationScale;
    final leftExit = -safetyGap - renderedRight;
    final rightExit = stageWidth + safetyGap - renderedLeft;
    return leftToRight
        ? leftExit + (rightExit + trailingDistance - leftExit) * progress
        : rightExit - (rightExit + trailingDistance - leftExit) * progress;
  }

  static Duration durationForPack({
    required double stageWidth,
    required bool leftToRight,
    required int juvenileCount,
    Duration baseDuration = crossingDuration,
    double presentationScale = 1,
  }) {
    if (juvenileCount == 0) return baseDuration;
    final baseDistance = _crossingDistance(
      stageWidth: stageWidth,
      leftToRight: leftToRight,
      presentationScale: presentationScale,
    );
    final packDistance = _crossingDistance(
      stageWidth: stageWidth,
      leftToRight: leftToRight,
      trailingDistance:
          juvenileCount * juvenileFollowerSpacing * presentationScale,
      presentationScale: presentationScale,
    );
    return Duration(
      microseconds: (baseDuration.inMicroseconds * packDistance / baseDistance)
          .round(),
    );
  }

  /// The single horizontal completion contract for every FOX pack. At progress
  /// 1 the adult (×1) or final juvenile (all other packs) has crossed the
  /// same safety-gap boundary used to build its event duration.
  static bool lastActiveFoxHasFullyExited({
    required double stageWidth,
    required double progress,
    required bool leftToRight,
    required int juvenileCount,
    double presentationScale = 1,
  }) {
    final isAdult = juvenileCount == 0;
    final bodyScale = isAdult ? 1.0 : juvenileBodyScale;
    final trailingDistance =
        juvenileCount * juvenileFollowerSpacing * presentationScale;
    final leaderCenter = bodyCenterForProgress(
      stageWidth: stageWidth,
      progress: progress,
      leftToRight: leftToRight,
      trailingDistance: trailingDistance,
      presentationScale: presentationScale,
    );
    final lastCenter =
        leaderCenter +
        (isAdult ? 0 : (leftToRight ? -1 : 1) * trailingDistance);
    final bounds = visibleBoundsFor(
      bodyCenterX: lastCenter,
      stageGroundY: 0,
      leftToRight: leftToRight,
      bodyScale: bodyScale * presentationScale,
    );
    final safetyGap =
        FoxRunV1ProductionGeometry.crossingSafetyGap * presentationScale;
    const numericalTolerance = .001;
    return leftToRight
        ? bounds.left >= stageWidth + safetyGap - numericalTolerance
        : bounds.right <= -safetyGap + numericalTolerance;
  }

  static double _crossingDistance({
    required double stageWidth,
    required bool leftToRight,
    double trailingDistance = 0,
    double presentationScale = 1,
  }) =>
      (bodyCenterForProgress(
                stageWidth: stageWidth,
                progress: 1,
                leftToRight: leftToRight,
                trailingDistance: trailingDistance,
                presentationScale: presentationScale,
              ) -
              bodyCenterForProgress(
                stageWidth: stageWidth,
                progress: 0,
                leftToRight: leftToRight,
                trailingDistance: trailingDistance,
                presentationScale: presentationScale,
              ))
          .abs();

  static Alignment get groundAnchor => Alignment(
    (_bodyOrigin.dx / FoxRunV1ProductionGeometry.canvasSize.width) * 2 - 1,
    (_virtualGround / FoxRunV1ProductionGeometry.canvasSize.height) * 2 - 1,
  );
}

/// Shared V2 event renderer. It owns just one event controller and consumes
/// the existing CAT and BAT production painters/canonical cels unchanged.
class AmbientWildlifeV2Stage extends StatefulWidget {
  const AmbientWildlifeV2Stage({
    required this.plan,
    required this.requestId,
    required this.neutral,
    required this.neutralSpecies,
    required this.paused,
    required this.leftToRight,
    this.visualGroundLineOffset = 0,
    this.foxCrossingDuration = AmbientWildlifeV2Fox.crossingDuration,
    this.speciesPresentationScale = 1,
    this.catPresentationOffsetY = 0,
    this.batPresentationVerticalAnchor =
        AirbornePresentationVerticalAnchor.bottom,
    this.batPresentationTopCrop = 0,
    this.batPresentationAltitudeOffsetY = 0,
    this.birdPresentationTopCrop = 0,
    this.birdPresentationScaleMultiplier = 1,
    this.birdTravelSpeedMultiplier = 1,
    this.catFollowerSpacingMultiplier = 1,
    this.foxFollowerSpacingMultiplier = 1,
    this.catMotionProfile = AmbientWildlifeV2CatMotionProfile.current,
    super.key,
    this.onCompleted,
  });

  final AmbientWildlifeV2EventPlan? plan;
  final int requestId;
  final bool neutral;
  final AmbientWildlifeV2Species neutralSpecies;
  final bool paused;
  final bool leftToRight;
  final double visualGroundLineOffset;
  final Duration foxCrossingDuration;
  final double speciesPresentationScale;
  final double catPresentationOffsetY;
  final AirbornePresentationVerticalAnchor batPresentationVerticalAnchor;
  final double batPresentationTopCrop;
  final double batPresentationAltitudeOffsetY;

  /// Maps BIRD's canonical airspace into a vertically cropped Dashboard lane.
  /// This mirrors the existing BAT crop mapping without changing the lane.
  final double birdPresentationTopCrop;
  final double birdPresentationScaleMultiplier;
  final double birdTravelSpeedMultiplier;
  final double catFollowerSpacingMultiplier;
  final double foxFollowerSpacingMultiplier;
  final AmbientWildlifeV2CatMotionProfile catMotionProfile;
  final VoidCallback? onCompleted;

  /// Shared stage authority: wildlife renderers never own the environment.
  static const environmentBackground = Color(0xFF101010);
  static const groundLineColor = Color(0xFF383838);
  static const groundInset = 5.0;
  static const productionGroundLineOffset = -8.0;

  /// Visual-only diagnostic relative to the production ground baseline. FOX
  /// and every species keep using [groundInset] for placement.
  static double visualGroundLineY({
    required double stageHeight,
    double offset = 0,
  }) => stageHeight - groundInset + productionGroundLineOffset + offset;

  /// Compatibility reference for the prior diagnostic coordinate system.
  static double legacyVisualGroundLineY({
    required double stageHeight,
    double offset = 0,
  }) => stageHeight - groundInset + offset;

  @override
  State<AmbientWildlifeV2Stage> createState() => _AmbientWildlifeV2StageState();
}

/// Production consumer for surfaces such as Dashboard. It owns scheduling
/// only; species, FOX packs/patterns, motion, and ground all stay in the V2
/// authority above.
class AmbientWildlifeV2ProductionStage extends StatefulWidget {
  const AmbientWildlifeV2ProductionStage({
    super.key,
    this.nextInt,
    this.minimumInterval = const Duration(seconds: 45),
    this.maximumInterval = const Duration(seconds: 150),
    this.speciesPresentationScale = 1,
    this.catPresentationOffsetY = 0,
    this.batPresentationVerticalAnchor =
        AirbornePresentationVerticalAnchor.bottom,
    this.batPresentationTopCrop = 0,
    this.batPresentationAltitudeOffsetY = 0,
    this.birdPresentationTopCrop = 0,
    this.birdPresentationScaleMultiplier = 1,
    this.birdTravelSpeedMultiplier = 1,
    this.catFollowerSpacingMultiplier = 1,
    this.foxFollowerSpacingMultiplier = 1,
    this.catMotionProfile = AmbientWildlifeV2CatMotionProfile.current,
    this.forcedPlan,
    this.forcedRequestId = 0,
    this.paused = false,
    this.onCompleted,
  });

  static const height = BatV3ProductionFlight.stageHeight;

  final int Function(int max)? nextInt;
  final Duration minimumInterval;
  final Duration maximumInterval;
  final double speciesPresentationScale;

  /// Dashboard-only visual clearance. The canonical/sandbox default is zero.
  final double catPresentationOffsetY;
  final AirbornePresentationVerticalAnchor batPresentationVerticalAnchor;
  final double batPresentationTopCrop;
  final double batPresentationAltitudeOffsetY;
  final double birdPresentationTopCrop;
  final double birdPresentationScaleMultiplier;
  final double birdTravelSpeedMultiplier;
  final double catFollowerSpacingMultiplier;
  final double foxFollowerSpacingMultiplier;
  final AmbientWildlifeV2CatMotionProfile catMotionProfile;
  final AmbientWildlifeV2EventPlan? forcedPlan;
  final int forcedRequestId;
  final bool paused;
  final VoidCallback? onCompleted;

  @override
  AmbientWildlifeV2ProductionStageState createState() =>
      AmbientWildlifeV2ProductionStageState();
}

class AmbientWildlifeV2ProductionStageState
    extends State<AmbientWildlifeV2ProductionStage> {
  final math.Random _random = math.Random();
  AmbientWildlifeV2EventPlan? _plan;
  Timer? _timer;
  var _requestId = 0;
  var _reducedMotion = false;
  var _manualSequenceQueued = false;

  bool get isActive => _plan != null;
  bool get hasQueuedManualSequence => _manualSequenceQueued;

  int _next(int max) => widget.nextInt?.call(max) ?? _random.nextInt(max);

  @override
  void initState() {
    super.initState();
    _plan = widget.forcedPlan;
    _requestId = widget.forcedPlan == null ? 0 : widget.forcedRequestId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reducedMotion) {
      _timer?.cancel();
      _timer = null;
      if (_plan != null) {
        _plan = null;
      }
      _manualSequenceQueued = false;
    } else if (widget.forcedPlan == null) {
      _schedule();
    }
  }

  @override
  void didUpdateWidget(covariant AmbientWildlifeV2ProductionStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forcedRequestId != widget.forcedRequestId ||
        oldWidget.forcedPlan != widget.forcedPlan) {
      _timer?.cancel();
      _timer = null;
      _manualSequenceQueued = false;
      setState(() {
        _plan = widget.forcedPlan;
        _requestId = widget.forcedRequestId;
      });
    }
  }

  void _schedule() {
    if (!mounted ||
        _reducedMotion ||
        widget.forcedPlan != null ||
        _plan != null ||
        _timer != null)
      return;
    final minimum = widget.minimumInterval.inMilliseconds;
    final maximum = widget.maximumInterval.inMilliseconds;
    final delta = maximum - minimum;
    _timer = Timer(
      Duration(milliseconds: minimum + (delta == 0 ? 0 : _next(delta + 1))),
      () {
        _timer = null;
        if (!mounted || _reducedMotion) return;
        _startSequence();
      },
    );
  }

  /// Starts a V2 plan immediately when idle. While a crossing is active this
  /// records exactly one follow-up request, preserving the active plan.
  bool triggerManualSequence() {
    if (!mounted || _reducedMotion || widget.forcedPlan != null) return false;
    _timer?.cancel();
    _timer = null;
    if (_plan != null) {
      if (_manualSequenceQueued) return false;
      _manualSequenceQueued = true;
      return true;
    }
    _startSequence();
    return true;
  }

  void _startSequence() {
    if (!mounted ||
        _reducedMotion ||
        widget.forcedPlan != null ||
        _plan != null)
      return;
    final species =
        AmbientWildlifeV2Registry.availableSpecies[_next(
          AmbientWildlifeV2Registry.availableSpecies.length,
        )];
    setState(() {
      _plan = AmbientWildlifeV2EventPlan.resolve(
        species: species,
        leftToRight: _next(2) == 0,
        nextInt: _next,
      );
      _requestId++;
    });
  }

  void _complete() {
    if (!mounted || _plan == null) return;
    setState(() => _plan = null);
    if (widget.forcedPlan == null && _manualSequenceQueued) {
      _manualSequenceQueued = false;
      _startSequence();
    } else if (widget.forcedPlan == null) {
      _schedule();
    }
    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AmbientWildlifeV2Stage(
    plan: _reducedMotion ? null : _plan,
    requestId: _requestId,
    neutral: false,
    neutralSpecies: AmbientWildlifeV2Species.fox,
    paused: widget.paused,
    leftToRight: _plan?.leftToRight ?? true,
    foxCrossingDuration: AmbientWildlifeV2Fox.dashboardCrossingDuration,
    speciesPresentationScale: widget.speciesPresentationScale,
    catPresentationOffsetY: widget.catPresentationOffsetY,
    batPresentationVerticalAnchor: widget.batPresentationVerticalAnchor,
    batPresentationTopCrop: widget.batPresentationTopCrop,
    batPresentationAltitudeOffsetY: widget.batPresentationAltitudeOffsetY,
    birdPresentationTopCrop: widget.birdPresentationTopCrop,
    birdPresentationScaleMultiplier: widget.birdPresentationScaleMultiplier,
    birdTravelSpeedMultiplier: widget.birdTravelSpeedMultiplier,
    catFollowerSpacingMultiplier: widget.catFollowerSpacingMultiplier,
    foxFollowerSpacingMultiplier: widget.foxFollowerSpacingMultiplier,
    catMotionProfile: widget.catMotionProfile,
    onCompleted: _complete,
  );
}

class _AmbientWildlifeV2StageState extends State<AmbientWildlifeV2Stage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double? _stageWidth;
  bool _waitingForFoxStageWidth = false;
  bool _waitingForBirdStageWidth = false;
  Duration? _activeFoxDuration;
  bool _foxCompletionEmitted = false;
  int? _preloadRequestId;
  Future<void>? _preloadFuture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..addListener(_advanceCat)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          if (widget.plan?.isFox ?? false) {
            assert(_lastActiveFoxHasFullyExited());
            if (_foxCompletionEmitted) return;
            _foxCompletionEmitted = true;
          }
          if (widget.plan?.isBird ?? false) {
            assert(_lastActiveBirdHasFullyExited());
          }
          setState(() {});
          widget.onCompleted?.call();
        }
      });
  }

  @override
  void didUpdateWidget(covariant AmbientWildlifeV2Stage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId) {
      _start();
    } else if (oldWidget.paused != widget.paused) {
      if (widget.paused) {
        _controller.stop();
      } else {
        _resume();
      }
    }
  }

  void _start() {
    final plan = widget.plan;
    _activeFoxDuration = null;
    _foxCompletionEmitted = false;
    if (plan == null || widget.neutral || widget.paused) {
      _controller.stop();
      return;
    }
    // Warm only the source cels that can be selected by this event. CAT is
    // painter-only; FOX, BAT, and BIRD retain their current visible frame
    // while a new cel resolves via gaplessPlayback in their renderers.
    unawaited(_ensureFramesReady(plan));
    if (plan.isCat) {
      _controller.value = 0;
      _continueCat();
      return;
    }
    if (plan.isFox) {
      if (_stageWidth == null) {
        _waitingForFoxStageWidth = true;
        return;
      }
      _controller.value = 0;
      _continueFox();
      return;
    }
    if (plan.isBird) {
      if (_stageWidth == null) {
        _waitingForBirdStageWidth = true;
        return;
      }
      _controller.value = 0;
      _continueBird(_birdDuration);
      return;
    }
    final duration = Duration(
      milliseconds: BatV3ProductionFlight.eventDurationMsFor(
        instances: plan.batInstances,
        presentationScale: widget.speciesPresentationScale,
      ),
    );
    _controller.value = 0;
    _continueBat(duration);
  }

  Future<void> _ensureFramesReady(AmbientWildlifeV2EventPlan plan) {
    final requestId = widget.requestId;
    final existing = _preloadFuture;
    if (_preloadRequestId == requestId && existing != null) return existing;
    final assets = switch (plan.species) {
      AmbientWildlifeV2Species.cat => const <String>[],
      AmbientWildlifeV2Species.fox => [
        for (final frame in AmbientWildlifeV2Fox.selectedFrames)
          AmbientWildlifeV2Fox.assetForFrame(frame),
      ],
      AmbientWildlifeV2Species.bat => [
        for (final pose in BatV3SourceSet.poses) pose.canonicalAsset,
      ],
      AmbientWildlifeV2Species.birds => BirdV1SourceSet.assets,
    };
    _preloadRequestId = requestId;
    return _preloadFuture = Future.wait<void>([
      for (final asset in assets)
        precacheImage(AssetImage(asset), context).catchError((_) {}),
    ]);
  }

  void _resume() {
    final plan = widget.plan;
    if (plan == null || widget.neutral || _controller.isCompleted) return;
    if (plan.isCat) {
      _continueCat();
    } else if (plan.isFox) {
      _continueFox();
    } else if (plan.isBird) {
      _continueBird(_birdDuration);
    } else {
      _continueBat(
        Duration(
          milliseconds: BatV3ProductionFlight.eventDurationMsFor(
            instances: plan.batInstances,
            presentationScale: widget.speciesPresentationScale,
          ),
        ),
      );
    }
  }

  void _continueBat(Duration eventDuration) {
    final remaining = (1 - _controller.value).clamp(0.0, 1.0);
    _controller.animateTo(
      1,
      duration: Duration(
        microseconds: (eventDuration.inMicroseconds * remaining).round(),
      ),
      curve: Curves.linear,
    );
  }

  void _continueBird(Duration eventDuration) {
    final remaining = (1 - _controller.value).clamp(0.0, 1.0);
    _controller.animateTo(
      1,
      duration: Duration(
        microseconds: (eventDuration.inMicroseconds * remaining).round(),
      ),
      curve: Curves.linear,
    );
  }

  void _continueFox() {
    final width = _stageWidth;
    final spawn = widget.plan?.foxSpawn;
    if (width == null || spawn == null) return;
    _activeFoxDuration ??= AmbientWildlifeV2Fox.durationForPack(
      stageWidth: width,
      leftToRight: widget.plan!.leftToRight,
      juvenileCount: spawn.juvenileCount,
      baseDuration: widget.foxCrossingDuration,
      presentationScale: widget.speciesPresentationScale,
    );
    final remaining = (1 - _controller.value).clamp(0.0, 1.0);
    _controller.animateTo(
      1,
      duration: Duration(
        microseconds: (_foxDuration.inMicroseconds * remaining).round(),
      ),
      curve: Curves.linear,
    );
  }

  Duration get _foxDuration {
    final activeDuration = _activeFoxDuration;
    if (activeDuration != null) return activeDuration;
    final spawn = widget.plan?.foxSpawn;
    final width = _stageWidth;
    if (spawn == null || width == null) {
      return AmbientWildlifeV2Fox.crossingDuration;
    }
    return AmbientWildlifeV2Fox.durationForPack(
      stageWidth: width,
      leftToRight: widget.plan!.leftToRight,
      juvenileCount: spawn.juvenileCount,
      baseDuration: widget.foxCrossingDuration,
      presentationScale: widget.speciesPresentationScale,
    );
  }

  Duration get _birdMotionDuration {
    final instances = widget.plan?.birdInstances;
    if (instances == null || instances.isEmpty) {
      return BirdV1ProductionFlight.crossingDuration;
    }
    return Duration(
      milliseconds: BirdV1ProductionFlight.eventDurationMs(
        stageWidth: _stageWidth ?? 0,
        values: instances,
        presentationScale: widget.speciesPresentationScale,
      ),
    );
  }

  Duration get _birdDuration => Duration(
    microseconds:
        (_birdMotionDuration.inMicroseconds / widget.birdTravelSpeedMultiplier)
            .round(),
  );

  void _recordStageWidth(double width) {
    if (_stageWidth == width) return;
    _stageWidth = width;
    if (!_waitingForFoxStageWidth && !_waitingForBirdStageWidth) return;
    _waitingForFoxStageWidth = false;
    _waitingForBirdStageWidth = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  /// FOX completes only after the final active individual has cleared the
  /// viewport and its safety gap. The controller endpoint does not act as an
  /// independent lifecycle authority.
  bool _lastActiveFoxHasFullyExited() {
    final plan = widget.plan;
    final spawn = plan?.foxSpawn;
    final width = _stageWidth;
    if (plan == null || spawn == null || width == null) return false;

    return AmbientWildlifeV2Fox.lastActiveFoxHasFullyExited(
      stageWidth: width,
      progress: _controller.value,
      leftToRight: plan.leftToRight,
      juvenileCount: spawn.juvenileCount,
      presentationScale: widget.speciesPresentationScale,
    );
  }

  bool _lastActiveBirdHasFullyExited() {
    final plan = widget.plan;
    final width = _stageWidth;
    if (plan == null || width == null || plan.birdInstances.isEmpty) {
      return false;
    }
    final elapsed = (_birdMotionDuration.inMilliseconds * _controller.value)
        .round();
    return plan.birdInstances.every(
      (instance) => BirdV1ProductionFlight.hasFullyExited(
        stageWidth: width,
        elapsedMs: elapsed,
        leftToRight: plan.leftToRight,
        instance: instance,
        presentationScale: widget.speciesPresentationScale,
      ),
    );
  }

  void _continueCat() {
    final executor = widget.plan?.catExecutor;
    if (executor == null) return;
    final remaining = (executor.finalProgress - _controller.value).clamp(
      0.0,
      1e9,
    );
    _controller.animateTo(
      executor.finalProgress,
      duration: Duration(
        microseconds:
            (CatRunV23Travel.crossingDuration.inMicroseconds * remaining)
                .round(),
      ),
      curve: ambientWildlifeV2CatMotionCurve(widget.catMotionProfile),
    );
  }

  void _advanceCat() {
    final plan = widget.plan;
    if (plan == null || !plan.isCat || widget.neutral) return;
    if (plan.catExecutor!.advance(_controller.value)) {
      setState(() {});
      _continueCat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return SizedBox(
      key: const ValueKey('ambient-wildlife-v2-stage'),
      height: BatV3ProductionFlight.stageHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _recordStageWidth(constraints.maxWidth);
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  key: ValueKey('ambient-wildlife-v2-environment'),
                  painter: const _AmbientWildlifeV2EnvironmentPainter(),
                ),
              ),
              // The visual ground belongs behind the species artwork. Ambient
              // CAT opts out of its opaque painter background below so this
              // shared line remains visible without a local duplicate.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('ambient-wildlife-v2-ground-line'),
                    painter: _AmbientWildlifeV2GroundLinePainter(
                      visualGroundLineOffset: widget.visualGroundLineOffset,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: widget.neutral
                    ? _AmbientWildlifeV2NeutralArt(
                        species: widget.neutralSpecies,
                        leftToRight: plan?.leftToRight ?? widget.leftToRight,
                      )
                    : AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          if (plan == null || _controller.isCompleted) {
                            return const SizedBox.expand(
                              key: ValueKey('ambient-wildlife-preview-idle'),
                            );
                          }
                          if (plan.isCat) {
                            final catPlan = plan.catPlan!;
                            return Transform.translate(
                              offset: Offset(0, widget.catPresentationOffsetY),
                              child: CustomPaint(
                                key: const ValueKey(
                                  'ambient-wildlife-v2-cat-stage',
                                ),
                                painter: CatRunV23StagePainter(
                                  progress: _controller.value,
                                  direction: catPlan.direction,
                                  coatVariant:
                                      catPlan.crossings.first.coatVariant,
                                  crossings: [
                                    for (final crossing
                                        in plan.catExecutor!.crossings)
                                      CatRunV23Crossing(
                                        progress:
                                            ambientWildlifeV2CatCrossingProgress(
                                              eventProgress: _controller.value,
                                              startedAtProgress:
                                                  crossing.startedAtProgress,
                                              isGlitch: plan.isGlitch,
                                              normalFollowerSpacingMultiplier:
                                                  widget
                                                      .catFollowerSpacingMultiplier,
                                            ),
                                        direction: catPlan.direction,
                                        coatVariant: crossing.coatVariant,
                                      ),
                                  ],
                                  catUnit:
                                      CatRunV23Travel.catUnit *
                                      widget.speciesPresentationScale,
                                  showGroundLine: false,
                                  paintBackground: false,
                                  smoothTuning:
                                      ambientWildlifeV2CatSmoothTuning(
                                        widget.catMotionProfile,
                                      ),
                                ),
                              ),
                            );
                          }
                          if (plan.isFox) {
                            final elapsed = Duration(
                              microseconds:
                                  (_foxDuration.inMicroseconds *
                                          _controller.value)
                                      .round(),
                            );
                            return _AmbientWildlifeV2FoxMotion(
                              progress: _controller.value,
                              elapsed: elapsed,
                              leftToRight: plan.leftToRight,
                              spawn: plan.foxSpawn!,
                              presentationScale:
                                  widget.speciesPresentationScale,
                              followerSpacingMultiplier:
                                  widget.foxFollowerSpacingMultiplier,
                            );
                          }
                          if (plan.isBird) {
                            final elapsed =
                                (_birdMotionDuration.inMilliseconds *
                                        _controller.value)
                                    .round();
                            return _AmbientWildlifeV2BirdMotion(
                              elapsedMs: elapsed,
                              leftToRight: plan.leftToRight,
                              instances: plan.birdInstances,
                              presentationScale:
                                  widget.speciesPresentationScale,
                              presentationTopCrop:
                                  widget.birdPresentationTopCrop,
                              bodyScaleMultiplier:
                                  widget.birdPresentationScaleMultiplier,
                            );
                          }
                          final eventDurationMs =
                              BatV3ProductionFlight.fullSpeedDurationMs +
                              plan.batInstances.last.startDelayMs;
                          final elapsed = (_controller.value * eventDurationMs)
                              .round();
                          return BatV3ProductionStage(
                            leftToRight: plan.leftToRight,
                            cycleIndex:
                                (elapsed ~/
                                    BatV3ProductionFlight.poseDurationMs) %
                                8,
                            crossingElapsed: elapsed,
                            crossingDuration:
                                BatV3ProductionFlight.fullSpeedDurationMs,
                            instances: plan.batInstances
                                .where(
                                  (instance) =>
                                      !BatV3ProductionFlight.isInstanceComplete(
                                        elapsedMs: elapsed,
                                        durationMs: BatV3ProductionFlight
                                            .fullSpeedDurationMs,
                                        instance: instance,
                                        presentationScale:
                                            widget.speciesPresentationScale,
                                      ),
                                )
                                .toList(growable: false),
                            flutterOn: true,
                            presentationScale: widget.speciesPresentationScale,
                            presentationVerticalAnchor:
                                widget.batPresentationVerticalAnchor,
                            presentationTopCrop: widget.batPresentationTopCrop,
                            presentationAltitudeOffsetY:
                                widget.batPresentationAltitudeOffsetY,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AmbientWildlifeV2EnvironmentPainter extends CustomPainter {
  const _AmbientWildlifeV2EnvironmentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AmbientWildlifeV2Stage.environmentBackground,
    );
  }

  @override
  bool shouldRepaint(_AmbientWildlifeV2EnvironmentPainter oldDelegate) => false;
}

class _AmbientWildlifeV2GroundLinePainter extends CustomPainter {
  const _AmbientWildlifeV2GroundLinePainter({
    required this.visualGroundLineOffset,
  });

  final double visualGroundLineOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = AmbientWildlifeV2Stage.visualGroundLineY(
      stageHeight: size.height,
      offset: visualGroundLineOffset,
    );
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = AmbientWildlifeV2Stage.groundLineColor
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_AmbientWildlifeV2GroundLinePainter oldDelegate) =>
      oldDelegate.visualGroundLineOffset != visualGroundLineOffset;
}

class _AmbientWildlifeV2NeutralArt extends StatelessWidget {
  const _AmbientWildlifeV2NeutralArt({
    required this.species,
    required this.leftToRight,
  });

  final AmbientWildlifeV2Species species;
  final bool leftToRight;

  @override
  Widget build(BuildContext context) => switch (species) {
    AmbientWildlifeV2Species.cat => CustomPaint(
      key: const ValueKey('ambient-wildlife-v2-neutral-cat'),
      painter: CatRunV23StagePainter(
        progress: 0,
        direction: leftToRight
            ? CatRunV23Direction.leftToRight
            : CatRunV23Direction.rightToLeft,
        coatVariant: CatRunCoatVariant.normal,
        catUnit: CatRunV23Travel.catUnit,
        showGroundLine: false,
        paintBackground: false,
        neutralFrame02: true,
      ),
    ),
    AmbientWildlifeV2Species.bat => Center(
      child: SizedBox(
        key: const ValueKey('ambient-wildlife-v2-neutral-bat'),
        width: BatV3ProductionFlight.batWidth,
        height: BatV3ProductionFlight.batHeight,
        child: BatV3CanonicalFrame(
          pose: BatV3SourceSet.poses[1],
          leftToRight: leftToRight,
          inspectionScale: 1,
          flutterY: 0,
          bodyOverlay: false,
          viewportHeight: BatV3ProductionFlight.batHeight,
        ),
      ),
    ),
    AmbientWildlifeV2Species.fox => _AmbientWildlifeV2FoxNeutral(
      leftToRight: leftToRight,
    ),
    AmbientWildlifeV2Species.birds => Center(
      child: BirdV1Frame(
        key: const ValueKey('ambient-wildlife-v2-neutral-bird'),
        frame: BirdV1SourceSet.cycle.first,
        leftToRight: leftToRight,
        height: BirdV1ProductionFlight.renderedSize,
      ),
    ),
  };
}

class _AmbientWildlifeV2BirdMotion extends StatelessWidget {
  const _AmbientWildlifeV2BirdMotion({
    required this.elapsedMs,
    required this.leftToRight,
    required this.instances,
    required this.presentationScale,
    required this.presentationTopCrop,
    required this.bodyScaleMultiplier,
  });

  final int elapsedMs;
  final bool leftToRight;
  final List<BirdV1ProductionInstance> instances;
  final double presentationScale;
  final double presentationTopCrop;
  final double bodyScaleMultiplier;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final instance in instances)
          if (!BirdV1ProductionFlight.isInstanceComplete(
            stageWidth: constraints.maxWidth,
            elapsedMs: elapsedMs,
            instance: instance,
            presentationScale: presentationScale,
          ))
            _AmbientWildlifeV2BirdCel(
              key: ValueKey(
                'ambient-wildlife-v2-bird-instance-${instance.identifier}',
              ),
              elapsedMs: elapsedMs,
              stageWidth: constraints.maxWidth,
              leftToRight: leftToRight,
              instance: instance,
              presentationScale: presentationScale,
              presentationTopCrop: presentationTopCrop,
              bodyScaleMultiplier: bodyScaleMultiplier,
              verticalMotionScale:
                  BirdV1ProductionFlight.verticalMotionScaleFor(instances),
            ),
      ],
    ),
  );
}

class _AmbientWildlifeV2BirdCel extends StatelessWidget {
  const _AmbientWildlifeV2BirdCel({
    super.key,
    required this.elapsedMs,
    required this.stageWidth,
    required this.leftToRight,
    required this.instance,
    required this.presentationScale,
    required this.presentationTopCrop,
    required this.verticalMotionScale,
    required this.bodyScaleMultiplier,
  });

  final int elapsedMs;
  final double stageWidth;
  final bool leftToRight;
  final BirdV1ProductionInstance instance;
  final double presentationScale;
  final double presentationTopCrop;
  final double verticalMotionScale;
  final double bodyScaleMultiplier;

  @override
  Widget build(BuildContext context) {
    final frame = BirdV1ProductionFlight.frameFor(
      stageWidth: stageWidth,
      elapsedMs: elapsedMs,
      instance: instance,
      presentationScale: presentationScale,
    );
    final bob =
        BirdV1FlightTuning.bobForElapsed(
          frame.motionElapsedMs,
          BirdV1ProductionFlight.cadence,
        ) *
        verticalMotionScale;
    final flutterY =
        BirdV1FlightTuning.flutterYForElapsed(
          frame.motionElapsedMs,
          BirdV1ProductionFlight.cadence,
        ) *
        verticalMotionScale;
    final flutterRotation = BirdV1FlightTuning.flutterRotationForElapsed(
      frame.motionElapsedMs,
      BirdV1ProductionFlight.cadence,
    );
    final transitionElapsed = frame.transitionElapsedMs;
    final blending = transitionElapsed < BirdV1ProductionFlight.transitionMs;
    final opacity = BirdV1FlightTuning.transitionOpacities(
      BirdV1ProductionFlight.transition,
      transitionElapsed,
    );
    final size =
        BirdV1ProductionFlight.renderedSize *
        presentationScale *
        bodyScaleMultiplier;
    return Positioned(
      left: BirdV1ProductionFlight.leftFor(
        stageWidth: stageWidth,
        progress: BirdV1ProductionFlight.progressFor(
          stageWidth: stageWidth,
          elapsedMs: elapsedMs,
          instance: instance,
          presentationScale: presentationScale,
        ),
        leftToRight: leftToRight,
        presentationScale: presentationScale,
      ),
      top:
          presentationTopCrop +
          (BirdV1ProductionFlight.baseTop +
                  instance.formationY +
                  bob +
                  flutterY) *
              presentationScale,
      width: size,
      height: size,
      child: Stack(
        children: [
          if (blending)
            Opacity(
              opacity: opacity.outgoing,
              child: BirdV1Frame(
                frame: frame.previousFrame,
                leftToRight: leftToRight,
                height: size,
                rotationRadians: flutterRotation,
              ),
            ),
          Opacity(
            opacity: opacity.incoming,
            child: BirdV1Frame(
              frame: frame.frame,
              leftToRight: leftToRight,
              height: size,
              rotationRadians: flutterRotation,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientWildlifeV2FoxMotion extends StatelessWidget {
  const _AmbientWildlifeV2FoxMotion({
    required this.progress,
    required this.elapsed,
    required this.leftToRight,
    required this.spawn,
    required this.presentationScale,
    required this.followerSpacingMultiplier,
  });

  final double progress;
  final Duration elapsed;
  final bool leftToRight;
  final AmbientWildlifeV2FoxSpawn spawn;
  final double presentationScale;
  final double followerSpacingMultiplier;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stageGroundY =
          constraints.maxHeight - AmbientWildlifeV2Stage.groundInset;
      final flutter = AmbientWildlifeV2Fox.flutterAtElapsed(elapsed);
      final bodyCenter = AmbientWildlifeV2Fox.bodyCenterForProgress(
        stageWidth: constraints.maxWidth,
        progress: progress,
        leftToRight: leftToRight,
        trailingDistance:
            spawn.juvenileCount *
            AmbientWildlifeV2Fox.juvenileFollowerSpacing *
            presentationScale *
            (spawn.pack == AmbientWildlifeV2FoxPack.gricthTen
                ? 1
                : followerSpacingMultiplier),
        presentationScale: presentationScale,
      );
      final frame = AmbientWildlifeV2Fox.frameAtElapsed(elapsed);
      final bodyFlex = AmbientWildlifeV2Fox.bodyFlexAtElapsed(elapsed);
      return Stack(
        children: [
          _AmbientWildlifeV2FoxCel(
            key: const ValueKey('ambient-wildlife-v2-fox-motion'),
            frame: frame,
            bodyCenterX: bodyCenter,
            stageGroundY: stageGroundY,
            leftToRight: leftToRight,
            verticalFlutterOffset: flutter * presentationScale,
            bodyFlexOffset: bodyFlex * presentationScale,
            bodyScale: presentationScale,
            pattern: spawn.pattern,
          ),
          for (var index = 0; index < spawn.juvenileCount; index++)
            _AmbientWildlifeV2FoxCel(
              key: ValueKey('ambient-wildlife-v2-fox-juvenile-${index + 1}'),
              frame: frame,
              bodyCenterX:
                  bodyCenter +
                  (leftToRight ? -1 : 1) *
                      AmbientWildlifeV2Fox.juvenileFollowerSpacing *
                      presentationScale *
                      (index + 1),
              stageGroundY: stageGroundY,
              leftToRight: leftToRight,
              verticalFlutterOffset: flutter * presentationScale,
              bodyFlexOffset: bodyFlex * presentationScale,
              bodyScale:
                  AmbientWildlifeV2Fox.juvenileBodyScale * presentationScale,
              pattern: spawn.pattern,
            ),
        ],
      );
    },
  );
}

class _AmbientWildlifeV2FoxNeutral extends StatelessWidget {
  const _AmbientWildlifeV2FoxNeutral({required this.leftToRight});

  final bool leftToRight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Stack(
        children: [
          _AmbientWildlifeV2FoxCel(
            key: const ValueKey('ambient-wildlife-v2-neutral-fox'),
            frame: AmbientWildlifeV2Fox.neutralFrame,
            bodyCenterX: constraints.maxWidth / 2,
            stageGroundY:
                constraints.maxHeight - AmbientWildlifeV2Stage.groundInset,
            leftToRight: leftToRight,
            bodyFlexOffset: 0,
          ),
        ],
      );
    },
  );
}

class _AmbientWildlifeV2FoxCel extends StatelessWidget {
  const _AmbientWildlifeV2FoxCel({
    super.key,
    required this.frame,
    required this.bodyCenterX,
    required this.stageGroundY,
    required this.leftToRight,
    required this.bodyFlexOffset,
    this.verticalFlutterOffset = 0,
    this.bodyScale = 1,
    this.pattern = FoxRunV1Pattern.off,
  });

  final int frame;
  final double bodyCenterX;
  final double stageGroundY;
  final bool leftToRight;
  final double bodyFlexOffset;
  final double verticalFlutterOffset;
  final double bodyScale;
  final FoxRunV1Pattern pattern;

  @override
  Widget build(BuildContext context) {
    final image = AmbientWildlifeV2Fox.imageTopLeft(
      bodyCenterX: bodyCenterX,
      stageGroundY: stageGroundY,
      verticalFlutterOffset: verticalFlutterOffset,
      bodyScale: bodyScale,
    );
    final canvas = AmbientWildlifeV2Fox.canvasSizeFor(bodyScale);
    return Positioned(
      left: image.dx,
      top: image.dy,
      width: canvas.width,
      height: canvas.height,
      child: Transform(
        key: bodyScale == 1
            ? const ValueKey('ambient-wildlife-v2-fox-body-flex')
            : null,
        alignment: AmbientWildlifeV2Fox.groundAnchor,
        transform: Matrix4.diagonal3Values(
          leftToRight ? 1 : -1,
          AmbientWildlifeV2Fox.bodyFlexScale(
            bodyFlexOffset,
            bodyScale: bodyScale,
          ),
          1,
        ),
        child: _AmbientWildlifeV2FoxPatternCel(frame: frame, pattern: pattern),
      ),
    );
  }
}

class _AmbientWildlifeV2FoxPatternCel extends StatelessWidget {
  const _AmbientWildlifeV2FoxPatternCel({
    required this.frame,
    required this.pattern,
  });

  final int frame;
  final FoxRunV1Pattern pattern;

  String get _asset => AmbientWildlifeV2Fox.assetForFrame(frame);

  @override
  Widget build(BuildContext context) {
    final base = _colored(FoxRunV1ProductionStage.silhouetteColor);
    if (pattern == FoxRunV1Pattern.off) return base;
    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        _region('tail', FoxRunV1ProductionStage.patternLightColor),
        _region('jaw', FoxRunV1ProductionStage.patternLightColor),
        _region('feet', FoxRunV1ProductionStage.patternDarkColor),
      ],
    );
  }

  Widget _region(String part, Color color) => ClipPath(
    clipper: _AmbientWildlifeV2FoxPatternClipper(frame: frame + 1, part: part),
    child: _colored(color),
  );

  Widget _colored(Color color) => ColorFiltered(
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    child: Image.asset(
      _asset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
    ),
  );
}

class _AmbientWildlifeV2FoxPatternClipper extends CustomClipper<Path> {
  const _AmbientWildlifeV2FoxPatternClipper({
    required this.frame,
    required this.part,
  });

  final int frame;
  final String part;

  @override
  Path getClip(Size size) =>
      FoxPatternProductionGeometry.path(frame: frame, part: part, size: size);

  @override
  bool shouldReclip(_AmbientWildlifeV2FoxPatternClipper oldClipper) =>
      oldClipper.frame != frame || oldClipper.part != part;
}
