import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'cat_run_v2_registration.dart';
import 'cat_run_v2_trace_data.dart';
import 'cat_run_coat_patterns.dart';
import 'cat_run_v24_presentation.dart';

/// Presentation-only travel model for V2.2's frozen registered HIGH frames.
/// It does not alter source geometry, registration, contact metadata, or timing.
class CatRunV23Travel {
  CatRunV23Travel._();

  static const stageHeight = CatRunV24Travel.stageHeight;
  static const catUnit = CatRunV24Travel.catUnit;
  static const offstagePadding = CatRunV24Travel.offstagePadding;
  static const crossingDuration = CatRunV24Travel.crossingDuration;

  static double horizontalPosition({
    required double stageWidth,
    required double progress,
  }) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();
    return -offstagePadding +
        (stageWidth + (offstagePadding * 2)) * safeProgress;
  }

  static double velocityFor(double stageWidth) =>
      (stageWidth + (offstagePadding * 2)) /
      crossingDuration.inMilliseconds *
      1000;

  static int frameAtTravelProgress(double progress) {
    final safeProgress = progress.clamp(0.0, 0.999999).toDouble();
    final elapsedMicroseconds = (crossingDuration.inMicroseconds * safeProgress)
        .round();
    final cycleMicroseconds = CatRunV2Registration.cycleDuration.inMicroseconds;
    final cycleProgress =
        (elapsedMicroseconds % cycleMicroseconds) / cycleMicroseconds;
    return CatRunV2Registration.frameAtCycleProgress(cycleProgress);
  }

  static List<Offset> registeredPointsAt(double progress) =>
      CatRunV24Travel.pointsAt(progress);
}

/// One complete, frozen-vector CAT crossing. The dashboard may paint multiple
/// instances when a same-direction production chain is active; each instance
/// still owns one coat and one immutable traversal progress value.
class CatRunV23Crossing {
  const CatRunV23Crossing({
    required this.progress,
    required this.direction,
    required this.coatVariant,
  });

  final double progress;
  final CatRunV23Direction direction;
  final CatRunCoatVariant coatVariant;
}

/// Sandbox-only 48px travel inspection for direct sequential HIGH vectors.
class CatRunV23ProductionPreview extends StatefulWidget {
  const CatRunV23ProductionPreview({super.key, this.random});

  final math.Random? random;

  @override
  State<CatRunV23ProductionPreview> createState() =>
      _CatRunV23ProductionPreviewState();
}

class _CatRunV23ProductionPreviewState extends State<CatRunV23ProductionPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _direction = CatRunV23Direction.leftToRight;
  var _speed = 1.0;
  var _playing = true;
  var _randomSelection = false;
  var _coatVariant = CatRunCoatVariant.normal;
  var _lastProgress = 0.0;
  late final math.Random _random = widget.random ?? math.Random();

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: CatRunV23Travel.crossingDuration,
        )..addListener(() {
          if (!mounted || !_playing) return;
          if (_randomSelection && _controller.value < _lastProgress) {
            _coatVariant = CatRunCoatPatterns.chooseRandom(_random);
          }
          _lastProgress = _controller.value;
          setState(() {});
        });
    _controller.repeat();
  }

  void _restart() {
    setState(() {
      _playing = true;
      _lastProgress = 0;
      if (_randomSelection) {
        _coatVariant = CatRunCoatPatterns.chooseRandom(_random);
      }
      _controller
        ..value = 0
        ..repeat();
    });
  }

  void _setSpeed(double speed) {
    setState(() {
      _speed = speed;
      _controller.duration = Duration(
        microseconds: (CatRunV23Travel.crossingDuration.inMicroseconds / speed)
            .round(),
      );
      if (_playing) _controller.repeat();
    });
  }

  void _selectCoat(CatRunCoatVariant variant) {
    setState(() {
      _randomSelection = false;
      _coatVariant = variant;
    });
  }

  void _selectRandomCoat() {
    setState(() {
      _randomSelection = true;
      _coatVariant = CatRunCoatPatterns.chooseRandom(_random);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.directions_run,
          title: 'CAT RUN V2.10 — PRODUCTION PREVIEW',
        ),
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('cat-run-v23-production-preview'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: CatRunV23Travel.stageHeight,
                    child: CustomPaint(
                      key: const ValueKey('cat-run-v23-stage'),
                      painter: CatRunV23StagePainter(
                        progress: _controller.value,
                        direction: _direction,
                        coatVariant: _coatVariant,
                      ),
                    ),
                  );
                },
              ),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('cat-run-v23-play-restart'),
                    onPressed: _restart,
                    child: const Text('PLAY / RESTART'),
                  ),
                  for (final direction in CatRunV23Direction.values)
                    OutlinedButton(
                      key: ValueKey('cat-run-v23-direction-${direction.name}'),
                      onPressed: () => setState(() => _direction = direction),
                      child: Text(
                        direction == CatRunV23Direction.leftToRight
                            ? 'L→R'
                            : 'R→L',
                      ),
                    ),
                  for (final speed in [0.5, 1.0])
                    OutlinedButton(
                      key: ValueKey('cat-run-v23-speed-$speed'),
                      onPressed: () => _setSpeed(speed),
                      child: Text('$speed×'),
                    ),
                  for (final variant in CatRunCoatPatterns.visualVariants)
                    OutlinedButton(
                      key: ValueKey('cat-run-v23-coat-${variant.name}'),
                      onPressed: () => _selectCoat(variant),
                      child: Text(variant.label),
                    ),
                  OutlinedButton(
                    key: const ValueKey('cat-run-v23-coat-random'),
                    onPressed: _selectRandomCoat,
                    child: const Text('RANDOM'),
                  ),
                ],
              ),
              AppSpacing.gapSM,
              LayoutBuilder(
                builder: (context, constraints) {
                  final frame = CatRunV24Travel.frameAtTravelProgress(
                    _controller.value,
                  );
                  return Text(
                    '48PX STAGE · FRAME ${(frame + 1).toString().padLeft(2, '0')} · '
                    '${CatRunV23Travel.crossingDuration.inSeconds.toStringAsFixed(1)}s crossing · '
                    '${CatRunV23Travel.velocityFor(constraints.maxWidth).toStringAsFixed(0)}px/s · $_speed× · '
                    '${_randomSelection ? 'RANDOM: ' : ''}${_coatVariant.label}',
                  );
                },
              ),
              const Text(
                'V2.10: NEW POSE 01 HIGH TRACE + 25MS CONTACT + STANCE-FOOT ROOT LOCK · FROZEN V2.2 HIGH / REGISTRATION / '
                'CONTACT / TIMING · NO MORPH / RESAMPLING / ARTICULATION',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared vector painter for the frozen V2.10 production-scale CAT crossing.
/// Dashboard scheduling supplies appearance state; this painter owns no timer
/// and does not alter geometry, timing, registration, or coat data.
class CatRunV23StagePainter extends CustomPainter {
  const CatRunV23StagePainter({
    required this.progress,
    required this.direction,
    required this.coatVariant,
    this.crossings,
    this.catUnit = CatRunV23Travel.catUnit,
    this.showGroundLine = false,
    this.groundInset = 5,
    this.groundLineColor = const Color(0xFF383838),
  });

  final double progress;
  final CatRunV23Direction direction;
  final CatRunCoatVariant coatVariant;
  final List<CatRunV23Crossing>? crossings;
  final double catUnit;
  final bool showGroundLine;
  final double groundInset;
  final Color groundLineColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
    if (showGroundLine) {
      canvas.drawLine(
        Offset(0, size.height - groundInset),
        Offset(size.width, size.height - groundInset),
        Paint()
          ..color = groundLineColor
          ..strokeWidth = 1,
      );
    }
    final activeCrossings =
        crossings ??
        [
          CatRunV23Crossing(
            progress: progress,
            direction: direction,
            coatVariant: coatVariant,
          ),
        ];

    for (final crossing in activeCrossings) {
      _paintCrossing(canvas, size, crossing);
    }
  }

  void _paintCrossing(Canvas canvas, Size size, CatRunV23Crossing crossing) {
    final frame = CatRunV24Travel.frameAtTravelProgress(crossing.progress);
    final trace = catRunV2HighTraces[frame];
    final points = CatRunV24Travel.pointsAt(crossing.progress);
    final path = Path()..addPolygon(points, true);
    final travelX = CatRunV24Travel.horizontalPosition(
      stageWidth: size.width,
      progress: crossing.progress,
    );
    final groundY =
        size.height - 5 - CatRunV2Registration.virtualGround * catUnit;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (crossing.direction == CatRunV23Direction.leftToRight) {
      canvas.translate(travelX, groundY);
      canvas.scale(catUnit);
    } else {
      canvas.translate(size.width - travelX, groundY);
      canvas.scale(-catUnit, catUnit);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = CatRunCoatPatterns.baseColor
        ..isAntiAlias = true,
    );
    CatRunCoatPatterns.paint(
      canvas: canvas,
      silhouette: path,
      trace: trace,
      variant: crossing.coatVariant,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CatRunV23StagePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.direction != direction ||
      oldDelegate.coatVariant != coatVariant ||
      oldDelegate.crossings != crossings ||
      oldDelegate.catUnit != catUnit ||
      oldDelegate.showGroundLine != showGroundLine ||
      oldDelegate.groundInset != groundInset ||
      oldDelegate.groundLineColor != groundLineColor;
}
