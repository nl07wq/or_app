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
  static const bootDuration = Duration(milliseconds: 860);
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
    const opticalCyan = Color(0xFF68E7F2);
    const titleWhite = Color(0xFFEAFBFF);

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
            final titleReveal = _interval(progress, .60, .90);
            return CustomPaint(
              key: CommandCenterHudSign.opticalLayerKey,
              painter: _OpticalHudPainter(
                progress: progress,
                cyan: opticalCyan,
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
                          color: opticalCyan,
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
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: titleReveal,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'COMMANDER CENTER',
                                maxLines: 1,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: .8,
                                      color: titleWhite,
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
  const _OpticalHudPainter({required this.progress, required this.cyan});

  final double progress;
  final Color cyan;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(math.min(76, size.width * .24), size.height * .5);
    final acquire = _interval(progress, .0, .18);
    final lock = _interval(progress, .14, .48);
    final scan = _interval(progress, .42, .74);
    final material = _interval(progress, .55, .92);
    final ringFade = 1 - _interval(progress, .66, .92);
    final plane = Paint()
      ..color = cyan.withValues(alpha: .035 * material)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(8, 7, math.max(0, size.width - 16), size.height - 14),
      plane,
    );

    final acquisitionPaint = Paint()
      ..color = cyan.withValues(alpha: .95 * acquire)
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
      ringPaint.color = cyan.withValues(
        alpha: ringAlpha * (radius == 38 ? .55 : .8),
      );
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        rotation,
        math.pi * 1.15,
        false,
        ringPaint,
      );
    }

    final scanX = origin.dx + (size.width - origin.dx - 14) * scan;
    final scanPaint = Paint()
      ..color = cyan.withValues(
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
          ..color = cyan.withValues(
            alpha: .36 * (1 - _interval(progress, .78, 1)),
          ),
      );
    }

    final structure = Paint()
      ..color = cyan.withValues(alpha: .64 * material)
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
      structure..color = cyan.withValues(alpha: .42 * material),
    );
    _line(
      canvas,
      Offset(size.width - 10, 20),
      Offset(size.width - 10, 35),
      structure,
    );

    final tick = Paint()..color = cyan.withValues(alpha: .72 * material);
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
      oldDelegate.progress != progress || oldDelegate.cyan != cyan;
}
