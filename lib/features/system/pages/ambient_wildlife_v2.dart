import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bat_v3_flight_motion_poc.dart';
import 'bat_v3_source_data.dart';
import 'cat_run_coat_patterns.dart';
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
    required this.catExecutor,
    required this.batInstances,
  });

  final AmbientWildlifeV2Species species;
  final bool leftToRight;
  final bool isGlitch;
  final CatRunProductionEventPlan? catPlan;
  final CatRunProductionEventExecutor? catExecutor;
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
      catExecutor: CatRunProductionEventExecutor(plan: catPlan, random: random),
      batInstances: const [],
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
    required this.neutralSpecies,
    required this.paused,
    required this.leftToRight,
    super.key,
    this.onCompleted,
  });

  final AmbientWildlifeV2EventPlan? plan;
  final int requestId;
  final bool neutral;
  final AmbientWildlifeV2Species neutralSpecies;
  final bool paused;
  final bool leftToRight;
  final VoidCallback? onCompleted;

  /// Shared stage authority: wildlife renderers never own the environment.
  static const environmentBackground = Color(0xFF101010);
  static const groundLineColor = Color(0xFF383838);
  static const groundInset = 5.0;

  @override
  State<AmbientWildlifeV2Stage> createState() => _AmbientWildlifeV2StageState();
}

class _AmbientWildlifeV2StageState extends State<AmbientWildlifeV2Stage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..addListener(_advanceCat)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
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
    if (plan == null || widget.neutral || widget.paused) {
      _controller.stop();
      return;
    }
    if (plan.isCat) {
      _controller.value = 0;
      _continueCat();
      return;
    }
    final duration = Duration(
      milliseconds:
          BatV3ProductionFlight.fullSpeedDurationMs +
          plan.batInstances.last.startDelayMs,
    );
    _controller.value = 0;
    _continueBat(duration);
  }

  void _resume() {
    final plan = widget.plan;
    if (plan == null || widget.neutral || _controller.isCompleted) return;
    if (plan.isCat) {
      _continueCat();
    } else {
      _continueBat(
        Duration(
          milliseconds:
              BatV3ProductionFlight.fullSpeedDurationMs +
              plan.batInstances.last.startDelayMs,
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
      curve: Curves.linear,
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: CustomPaint(
              key: ValueKey('ambient-wildlife-v2-environment'),
              painter: _AmbientWildlifeV2EnvironmentPainter(),
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
                        return CustomPaint(
                          key: const ValueKey('ambient-wildlife-v2-cat-stage'),
                          painter: CatRunV23StagePainter(
                            progress: _controller.value,
                            direction: catPlan.direction,
                            coatVariant: catPlan.crossings.first.coatVariant,
                            crossings: [
                              for (final crossing
                                  in plan.catExecutor!.crossings)
                                CatRunV23Crossing(
                                  progress:
                                      _controller.value -
                                      crossing.startedAtProgress,
                                  direction: catPlan.direction,
                                  coatVariant: crossing.coatVariant,
                                ),
                            ],
                            catUnit: CatRunV23Travel.catUnit,
                            showGroundLine: true,
                          ),
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
                            (elapsed ~/ BatV3ProductionFlight.poseDurationMs) %
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
                                  ),
                            )
                            .toList(growable: false),
                        flutterOn: true,
                      );
                    },
                  ),
          ),
        ],
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
    canvas.drawLine(
      Offset(0, size.height - AmbientWildlifeV2Stage.groundInset),
      Offset(size.width, size.height - AmbientWildlifeV2Stage.groundInset),
      Paint()
        ..color = AmbientWildlifeV2Stage.groundLineColor
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_AmbientWildlifeV2EnvironmentPainter oldDelegate) => false;
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
        showGroundLine: true,
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
    AmbientWildlifeV2Species.fox ||
    AmbientWildlifeV2Species.birds => const SizedBox.shrink(),
  };
}
