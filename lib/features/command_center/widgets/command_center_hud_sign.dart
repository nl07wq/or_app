import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// A route-aware optical console header for the command center.
///
/// The visual boot sequence is purely presentational. Navigation continues to
/// be owned by the enclosing [Navigator] through the caller-provided action.
class CommandCenterHudSign extends StatefulWidget {
  const CommandCenterHudSign({super.key, required this.canPop, this.onBack});

  static const height = 58.0;
  static const bootDuration = Duration(milliseconds: 1200);
  static const backKey = ValueKey('command-center-hud-back');
  static const signKey = ValueKey('command-center-hud-sign');
  static const opticalLayerKey = ValueKey('command-center-hud-optical-layer');

  final bool canPop;
  final VoidCallback? onBack;

  @override
  State<CommandCenterHudSign> createState() => _CommandCenterHudSignState();
}

class _CommandCenterHudSignState extends State<CommandCenterHudSign>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bootController = AnimationController(
    vsync: this,
    duration: CommandCenterHudSign.bootDuration,
  );
  bool _reducedMotionApplied = false;

  @override
  void initState() {
    super.initState();
    _bootController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _reducedMotionApplied = true;
      _bootController.value = 1;
    }
  }

  @override
  void dispose() {
    _bootController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const opticalGreen = Color(0xFF71F5A0);
    const titleGreenWhite = Color(0xFFE3FFE9);

    return Semantics(
      container: true,
      label: 'COMMANDER CENTER optical HUD',
      child: SizedBox(
        key: CommandCenterHudSign.signKey,
        height: CommandCenterHudSign.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _bootController,
          builder: (context, _) {
            final progress = _reducedMotionApplied
                ? 1.0
                : _bootController.value;
            final titleReveal = _interval(progress, .68, .97);
            final finalLock = _interval(progress, .90, 1);
            return CustomPaint(
              key: CommandCenterHudSign.opticalLayerKey,
              painter: _OpticalHudPainter(
                progress: progress,
                green: opticalGreen,
              ),
              child: Stack(
                children: [
                  if (widget.canPop)
                    Positioned(
                      left: 4,
                      top: 5,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          key: CommandCenterHudSign.backKey,
                          tooltip: 'Back',
                          onPressed: widget.onBack,
                          color: opticalGreen,
                          icon: const Icon(Symbols.chevron_left),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    left: widget.canPop ? 62 : 16,
                    right: 14,
                    child: Semantics(
                      header: true,
                      child: Center(
                        child: ClipPath(
                          clipper: _TitleSliceClipper(titleReveal),
                          child: Transform.scale(
                            alignment: Alignment.centerLeft,
                            scaleX: 1.035,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'COMMANDER CENTER',
                                maxLines: 1,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 25,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.15,
                                      color: Color.lerp(
                                        titleGreenWhite,
                                        opticalGreen,
                                        .22 * (1 - finalLock),
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

double _interval(double value, double begin, double end) =>
    ((value - begin) / (end - begin)).clamp(0.0, 1.0);

class _OpticalHudPainter extends CustomPainter {
  const _OpticalHudPainter({required this.progress, required this.green});

  final double progress;
  final Color green;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(math.min(76, size.width * .24), size.height * .5);
    final acquire = _interval(progress, .0, .20);
    final lock = _interval(progress, .16, .52);
    final lockEvent = _interval(progress, .46, .60);
    final scan = _interval(progress, .54, .80);
    final secondaryScan = _interval(progress, .64, .88);
    final material = _interval(progress, .68, .96);
    final ringFade = 1 - _interval(progress, .62, .90);
    final plane = Paint()
      ..color = green.withValues(alpha: .032 * material)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(8, 7, math.max(0, size.width - 16), size.height - 14),
      plane,
    );

    final acquisitionPaint = Paint()
      ..color = green.withValues(alpha: .95 * acquire)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(origin, 1.8 + acquire * 1.2, acquisitionPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1;
    final ringAlpha = lock * (.78 * ringFade + .14);
    for (final ring in [
      (18.0, -.7, 1.9),
      (27.0, 1.1, 1.55),
      (38.0, 2.5, 1.15),
    ]) {
      final radius = ring.$1;
      final rotation = ring.$2 + (lock - .5) * ring.$3;
      ringPaint.color = green.withValues(
        alpha: ringAlpha * (radius == 38 ? .55 : .8),
      );
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        rotation,
        math.pi * 1.15,
        false,
        ringPaint,
      );
      final tickPaint = Paint()
        ..color = green.withValues(alpha: ringAlpha * .55)
        ..strokeWidth = 1;
      for (var tick = 0; tick < 4; tick++) {
        final angle = rotation + tick * math.pi / 2;
        final start =
            origin + Offset(math.cos(angle), math.sin(angle)) * (radius + 2);
        final end =
            origin + Offset(math.cos(angle), math.sin(angle)) * (radius + 5);
        canvas.drawLine(start, end, tickPaint);
      }
    }

    final crosshairAlpha = lockEvent * (1 - _interval(progress, .59, .70));
    final reticle = Paint()
      ..color = green.withValues(alpha: crosshairAlpha)
      ..strokeWidth = 1;
    canvas.drawLine(
      origin - const Offset(11, 0),
      origin - const Offset(3, 0),
      reticle,
    );
    canvas.drawLine(
      origin + const Offset(3, 0),
      origin + const Offset(11, 0),
      reticle,
    );
    canvas.drawLine(
      origin - const Offset(0, 11),
      origin - const Offset(0, 3),
      reticle,
    );
    canvas.drawLine(
      origin + const Offset(0, 3),
      origin + const Offset(0, 11),
      reticle,
    );
    canvas.drawCircle(
      origin,
      6 + 8 * lockEvent,
      reticle..style = PaintingStyle.stroke,
    );

    final scanX = origin.dx + (size.width - origin.dx - 14) * scan;
    final scanPaint = Paint()
      ..color = green.withValues(
        alpha: .18 + .55 * scan * (1 - _interval(progress, .78, 1)),
      )
      ..strokeWidth = 1;
    if (scan > 0) {
      canvas.drawLine(
        Offset(origin.dx, size.height * .5),
        Offset(scanX, size.height * .5),
        scanPaint,
      );
      canvas.drawLine(
        Offset(scanX, 13),
        Offset(scanX, size.height - 13),
        scanPaint
          ..color = green.withValues(
            alpha: .36 * (1 - _interval(progress, .78, 1)),
          ),
      );
    }
    if (secondaryScan > 0) {
      final delayedX =
          origin.dx + (size.width - origin.dx - 22) * secondaryScan;
      final delayedPaint = Paint()
        ..color = green.withValues(
          alpha: .24 * (1 - _interval(progress, .90, 1)),
        )
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(origin.dx + 10, size.height * .32),
        Offset(delayedX, size.height * .32),
        delayedPaint,
      );
      canvas.drawLine(
        Offset(origin.dx + 20, size.height * .68),
        Offset(delayedX, size.height * .68),
        delayedPaint,
      );
    }

    final structure = Paint()
      ..color = green.withValues(alpha: .64 * material)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final fragment = size.width * material;
    _line(
      canvas,
      const Offset(60, 10),
      Offset(math.min(fragment * .42, size.width * .42), 10),
      structure,
    );
    _line(
      canvas,
      Offset(size.width * .64, 10),
      Offset(math.min(size.width - 12, fragment), 10),
      structure,
    );
    _line(
      canvas,
      Offset(16, size.height - 10),
      Offset(math.min(size.width * .32, fragment), size.height - 10),
      structure,
    );
    _line(
      canvas,
      Offset(size.width * .72, size.height - 10),
      Offset(math.min(size.width - 20, fragment), size.height - 10),
      structure,
    );
    _line(
      canvas,
      const Offset(10, 21),
      const Offset(10, 37),
      structure..color = green.withValues(alpha: .42 * material),
    );
    _line(
      canvas,
      Offset(size.width - 10, 20),
      Offset(size.width - 10, 35),
      structure,
    );

    final tick = Paint()..color = green.withValues(alpha: .72 * material);
    for (final point in [
      const Offset(56, 15),
      Offset(size.width * .52, 15),
      Offset(size.width * .59, size.height - 15),
      Offset(size.width - 28, size.height - 15),
    ]) {
      canvas.drawCircle(point, 1.35, tick);
    }
  }

  void _line(Canvas canvas, Offset start, Offset end, Paint paint) {
    if (end.dx > start.dx) canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _OpticalHudPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.green != green;
}

class _TitleSliceClipper extends CustomClipper<Path> {
  const _TitleSliceClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final path = Path();
    const slices = 12;
    final width = size.width / slices;
    for (var index = 0; index < slices; index++) {
      final stagger = (index % 3) * .12;
      final resolved = ((progress - stagger) / (1 - stagger)).clamp(0.0, 1.0);
      path.addRect(
        Rect.fromLTWH(index * width, 0, width * resolved, size.height),
      );
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _TitleSliceClipper oldClipper) =>
      oldClipper.progress != progress;
}
