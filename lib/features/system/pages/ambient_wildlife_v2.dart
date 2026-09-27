import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bat_v3_flight_motion_poc.dart';
import 'cat_run_v23_production_preview.dart';
import 'cat_run_v24_presentation.dart';

enum AmbientWildlifeV2Species { cat, bat, fox, birds }

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
      available: false,
    ),
    AmbientWildlifeV2SpeciesDefinition(
      species: AmbientWildlifeV2Species.birds,
      available: false,
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
    required this.batInstances,
  });

  final AmbientWildlifeV2Species species;
  final bool leftToRight;
  final bool isGlitch;
  final CatRunProductionEventPlan? catPlan;
  final List<BatV3ProductionInstance> batInstances;

  bool get isCat => species == AmbientWildlifeV2Species.cat;
  bool get isBat => species == AmbientWildlifeV2Species.bat;

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
      AmbientWildlifeV2Species.fox || AmbientWildlifeV2Species.birds =>
        throw ArgumentError.value(species, 'species', 'not available'),
    };
  }

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
      batInstances: const [],
    );
  }

  static AmbientWildlifeV2EventPlan _batPlan({
    required bool leftToRight,
    required int Function(int max) nextInt,
  }) {
    final glitch = nextInt(20) == 0;
    final count = 1 + nextInt(3);
    return AmbientWildlifeV2EventPlan._(
      species: AmbientWildlifeV2Species.bat,
      leftToRight: leftToRight,
      isGlitch: glitch,
      catPlan: null,
      batInstances: glitch
          ? BatV3ProductionFlight.glitchInstances
          : BatV3ProductionFlight.instances.take(count).toList(growable: false),
    );
  }
}

/// Shared V2 event renderer. It owns just one event controller and consumes
/// the existing CAT and BAT production painters/canonical cels unchanged.
class AmbientWildlifeV2Stage extends StatefulWidget {
  const AmbientWildlifeV2Stage({
    required this.plan,
    required this.requestId,
    required this.neutral,
    super.key,
    this.onCompleted,
  });

  final AmbientWildlifeV2EventPlan? plan;
  final int requestId;
  final bool neutral;
  final VoidCallback? onCompleted;

  @override
  State<AmbientWildlifeV2Stage> createState() => _AmbientWildlifeV2StageState();
}

class _AmbientWildlifeV2StageState extends State<AmbientWildlifeV2Stage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {});
        widget.onCompleted?.call();
      }
    });

  @override
  void didUpdateWidget(covariant AmbientWildlifeV2Stage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId) _start();
  }

  void _start() {
    final plan = widget.plan;
    if (plan == null || widget.neutral) {
      _controller.stop();
      return;
    }
    final duration = plan.isCat
        ? Duration(
            microseconds:
                (CatRunV23Travel.crossingDuration.inMicroseconds *
                        (plan.catPlan!.crossings.last.startedAtProgress + 1))
                    .round(),
          )
        : Duration(
            milliseconds:
                BatV3ProductionFlight.fullSpeedDurationMs +
                plan.batInstances.last.startDelayMs,
          );
    _controller
      ..duration = duration
      ..forward(from: 0);
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (plan == null || widget.neutral || _controller.isCompleted) {
            return const SizedBox.expand();
          }
          if (plan.isCat) {
            final catPlan = plan.catPlan!;
            return CustomPaint(
              key: const ValueKey('ambient-wildlife-v2-cat-stage'),
              painter: CatRunV23StagePainter(
                progress: _controller.value,
                direction: catPlan.direction,
                coatVariant: catPlan.crossings.first.coatVariant,
                crossings: [
                  for (final crossing in catPlan.crossings)
                    CatRunV23Crossing(
                      progress: _controller.value - crossing.startedAtProgress,
                      direction: catPlan.direction,
                      coatVariant: crossing.coatVariant,
                    ),
                ],
                catUnit: CatRunV23Travel.catUnit * .75,
                showGroundLine: true,
              ),
            );
          }
          final elapsed =
              (_controller.value * _controller.duration!.inMilliseconds)
                  .round();
          return BatV3ProductionStage(
            leftToRight: plan.leftToRight,
            cycleIndex: (elapsed ~/ BatV3ProductionFlight.poseDurationMs) % 8,
            crossingElapsed: elapsed,
            crossingDuration: BatV3ProductionFlight.fullSpeedDurationMs,
            instances: plan.batInstances
                .where(
                  (instance) => !BatV3ProductionFlight.isInstanceComplete(
                    elapsedMs: elapsed,
                    durationMs: BatV3ProductionFlight.fullSpeedDurationMs,
                    instance: instance,
                  ),
                )
                .toList(growable: false),
            flutterOn: true,
          );
        },
      ),
    );
  }
}
