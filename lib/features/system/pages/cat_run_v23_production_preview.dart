import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'cat_run_v2_registration.dart';
import 'cat_run_v2_trace_data.dart';

enum CatRunV23Direction { leftToRight, rightToLeft }

/// Presentation-only travel model for V2.2's frozen registered HIGH frames.
/// It does not alter source geometry, registration, contact metadata, or timing.
class CatRunV23Travel {
  CatRunV23Travel._();

  static const stageHeight = 48.0;
  static const catUnit = 110.0;
  static const offstagePadding = 96.0;
  static const crossingDuration = Duration(seconds: 3);

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
      CatRunV2Registration.registeredPoints(
        catRunV2HighTraces[frameAtTravelProgress(progress)],
      );
}

/// Sandbox-only 48px travel inspection for direct sequential HIGH vectors.
class CatRunV23ProductionPreview extends StatefulWidget {
  const CatRunV23ProductionPreview({super.key});

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

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: CatRunV23Travel.crossingDuration,
        )..addListener(() {
          if (mounted && _playing) setState(() {});
        });
    _controller.repeat();
  }

  void _restart() {
    setState(() {
      _playing = true;
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
          title: 'CAT RUN V2.3 — PRODUCTION PREVIEW',
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
                      painter: _CatRunV23StagePainter(
                        progress: _controller.value,
                        direction: _direction,
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
                ],
              ),
              AppSpacing.gapSM,
              LayoutBuilder(
                builder: (context, constraints) {
                  final frame = CatRunV23Travel.frameAtTravelProgress(
                    _controller.value,
                  );
                  return Text(
                    '48PX STAGE · FRAME ${(frame + 1).toString().padLeft(2, '0')} · '
                    '${CatRunV23Travel.crossingDuration.inSeconds.toStringAsFixed(1)}s crossing · '
                    '${CatRunV23Travel.velocityFor(constraints.maxWidth).toStringAsFixed(0)}px/s · $_speed×',
                  );
                },
              ),
              const Text(
                'SANDBOX ONLY · FROZEN V2.2 HIGH / REGISTRATION / CONTACT / TIMING · '
                'NO MORPH / RESAMPLING / ARTICULATION',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatRunV23StagePainter extends CustomPainter {
  const _CatRunV23StagePainter({
    required this.progress,
    required this.direction,
  });

  final double progress;
  final CatRunV23Direction direction;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
    final points = CatRunV23Travel.registeredPointsAt(progress);
    final path = Path()..addPolygon(points, true);
    final travelX = CatRunV23Travel.horizontalPosition(
      stageWidth: size.width,
      progress: progress,
    );
    final groundY =
        size.height -
        5 -
        CatRunV2Registration.virtualGround * CatRunV23Travel.catUnit;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (direction == CatRunV23Direction.leftToRight) {
      canvas.translate(travelX, groundY);
      canvas.scale(CatRunV23Travel.catUnit);
    } else {
      canvas.translate(size.width - travelX, groundY);
      canvas.scale(-CatRunV23Travel.catUnit, CatRunV23Travel.catUnit);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB8B8B8)
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CatRunV23StagePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.direction != direction;
}
