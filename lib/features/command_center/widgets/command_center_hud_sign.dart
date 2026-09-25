import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// A route-aware optical console header for the command center.
///
/// The visual boot sequence is purely presentational. Navigation continues to
/// be owned by the enclosing [Navigator] through the caller-provided action.
class CommandCenterHudSign extends StatefulWidget {
  const CommandCenterHudSign({super.key, required this.canPop, this.onBack});

  static const height = 58.0;
  static const bootDuration = Duration(milliseconds: 2050);
  static const exitDuration = Duration(milliseconds: 780);
  static const backKey = ValueKey('command-center-hud-back');
  static const signKey = ValueKey('command-center-hud-sign');
  static const opticalLayerKey = ValueKey('command-center-hud-optical-layer');
  static const titleKey = ValueKey('command-center-hud-title');
  static const titleSemanticsLabel = 'COMMANDER CENTER';

  static ValueKey<String> glyphKey(int visibleIndex) =>
      ValueKey('command-center-hud-glyph-$visibleIndex');

  static ValueKey<String> glyphTransformKey(int visibleIndex) =>
      ValueKey('command-center-hud-glyph-transform-$visibleIndex');

  final bool canPop;
  final VoidCallback? onBack;

  @override
  State<CommandCenterHudSign> createState() => _CommandCenterHudSignState();
}

class _CommandCenterHudSignState extends State<CommandCenterHudSign>
    with TickerProviderStateMixin {
  late final AnimationController _bootController = AnimationController(
    vsync: this,
    duration: CommandCenterHudSign.bootDuration,
  );
  bool _reducedMotionApplied = false;
  bool _exiting = false;
  late final AnimationController _exitController = AnimationController(
    vsync: this,
    duration: CommandCenterHudSign.exitDuration,
  );

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
    _exitController.dispose();
    super.dispose();
  }

  void _requestBack() {
    if (_exiting || widget.onBack == null) return;
    if (_reducedMotionApplied) {
      widget.onBack!.call();
      return;
    }
    setState(() => _exiting = true);
    _bootController.stop();
    _exitController.forward(from: 0);
    Future<void>.delayed(CommandCenterHudSign.exitDuration, () {
      if (mounted && _exiting) widget.onBack?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    const opticalBlue = Color(0xFF53C3FF);
    const structureBlue = Color(0xFF2C78A8);
    const titleBlue = Color(0xFF75D7FF);
    const titleLockBlue = Color(0xFFE3F7FF);

    return Semantics(
      container: true,
      label: 'COMMANDER CENTER optical HUD',
      child: SizedBox(
        key: CommandCenterHudSign.signKey,
        height: CommandCenterHudSign.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: Listenable.merge([_bootController, _exitController]),
          builder: (context, _) {
            final progress = _reducedMotionApplied
                ? 1.0
                : _bootController.value;
            final titleReveal = _interval(progress, .63, .99);
            final finalLock = _interval(progress, .96, 1);
            final exit = _exiting ? _exitController.value : 0.0;
            return CustomPaint(
              key: CommandCenterHudSign.opticalLayerKey,
              painter: _OpticalHudPainter(
                progress: progress,
                exitProgress: exit,
                primaryBlue: opticalBlue,
                structureBlue: structureBlue,
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
                          onPressed: _exiting ? null : _requestBack,
                          color: opticalBlue,
                          icon: const Icon(Symbols.chevron_left),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    left: widget.canPop ? 62 : 16,
                    right: 14,
                    child: Semantics(
                      header: true,
                      label: CommandCenterHudSign.titleSemanticsLabel,
                      child: ExcludeSemantics(
                        child: Center(
                          child: _GlyphLockTitle(
                            entry: titleReveal,
                            exit: exit,
                            style:
                                Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontFamily: 'ShareTechMono',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 1.0,
                                  color: Color.lerp(
                                    titleBlue,
                                    titleLockBlue,
                                    .18 * (1 - finalLock),
                                  ),
                                ) ??
                                const TextStyle(),
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

class _GlyphLockTitle extends StatelessWidget {
  const _GlyphLockTitle({
    required this.entry,
    required this.exit,
    required this.style,
  });
  final double entry;
  final double exit;
  final TextStyle style;
  static const _glyphs = [
    'C',
    'O',
    'M',
    'M',
    'A',
    'N',
    'D',
    'E',
    'R',
    'C',
    'E',
    'N',
    'T',
    'E',
    'R',
  ];

  @override
  Widget build(BuildContext context) => FittedBox(
    key: CommandCenterHudSign.titleKey,
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < _glyphs.length; index++) ...[
          if (index == 9)
            Text(' ', style: style.copyWith(color: Colors.transparent)),
          Padding(
            padding: EdgeInsets.only(
              right: index == _glyphs.length - 1 ? 0 : style.letterSpacing ?? 0,
            ),
            child: _OpticalGlyph(
              key: CommandCenterHudSign.glyphKey(index),
              glyph: _glyphs[index],
              entry: entry,
              exit: exit,
              visibleIndex: index,
              style: style.copyWith(letterSpacing: 0),
            ),
          ),
        ],
      ],
    ),
  );
}

class _OpticalGlyph extends StatelessWidget {
  const _OpticalGlyph({
    super.key,
    required this.glyph,
    required this.entry,
    required this.exit,
    required this.visibleIndex,
    required this.style,
  });

  final String glyph;
  final double entry;
  final double exit;
  final int visibleIndex;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // A 0.0625 entry phase offset is 46.1ms at the 738ms title-acquisition
    // window. Each independent unit therefore becomes readable in sequence.
    final acquire = ((entry - visibleIndex * .0625) / .10).clamp(0.0, 1.0);
    // Exit starts with an acknowledge pulse, then releases the rightmost
    // glyph first. It remains deliberately faster than the entry lock.
    final reverseIndex = 14 - visibleIndex;
    final unlock = ((exit - (.12 + reverseIndex * .035)) / .13).clamp(0.0, 1.0);
    final entryFlash = math.sin(acquire * math.pi) * .82 * (1 - unlock);
    final unlockFlash = math.sin(unlock * math.pi) * .60;
    final flash = math.max(entryFlash, unlockFlash);
    final visible = acquire * (1 - unlock);
    final fragmentOpacity = (1 - acquire) * (1 - unlock) * .34;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: fragmentOpacity,
          child: Container(
            width: 1.5,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF2C78A8),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        Opacity(
          key: ValueKey('command-center-hud-glyph-opacity-$visibleIndex'),
          opacity: visible,
          child: Transform.scale(
            key: CommandCenterHudSign.glyphTransformKey(visibleIndex),
            scale: 1 + .055 * flash,
            child: Text(
              glyph,
              style: style.copyWith(
                color: Color.lerp(style.color, const Color(0xFFE3F7FF), flash),
                shadows: flash == 0
                    ? null
                    : [
                        Shadow(
                          color: const Color(
                            0xFFE3F7FF,
                          ).withValues(alpha: .46 * flash),
                          blurRadius: 3.5 * flash,
                        ),
                      ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpticalHudPainter extends CustomPainter {
  const _OpticalHudPainter({
    required this.progress,
    required this.exitProgress,
    required this.primaryBlue,
    required this.structureBlue,
  });

  final double progress;
  final double exitProgress;
  final Color primaryBlue;
  final Color structureBlue;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(math.min(76, size.width * .24), size.height * .5);
    if (exitProgress > 0) {
      _paintDisengage(canvas, size, origin);
      return;
    }
    canvas.save();
    final acquire = _interval(progress, .0, .20);
    final lock = _interval(progress, .16, .52);
    final lockEvent = _interval(progress, .46, .60);
    final scan = _interval(progress, .54, .80);
    final secondaryScan = _interval(progress, .64, .88);
    final material = _interval(progress, .68, .96);
    final ringFade = 1 - _interval(progress, .62, .90);
    final plane = Paint()
      ..color = structureBlue.withValues(alpha: .032 * material)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(8, 7, math.max(0, size.width - 16), size.height - 14),
      plane,
    );

    final acquisitionPaint = Paint()
      ..color = primaryBlue.withValues(alpha: .95 * acquire)
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
      ringPaint.color = primaryBlue.withValues(
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
        ..color = structureBlue.withValues(alpha: ringAlpha * .55)
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
      ..color = primaryBlue.withValues(alpha: crosshairAlpha)
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
      ..color = primaryBlue.withValues(
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
          ..color = primaryBlue.withValues(
            alpha: .36 * (1 - _interval(progress, .78, 1)),
          ),
      );
    }
    if (secondaryScan > 0) {
      final delayedX =
          origin.dx + (size.width - origin.dx - 22) * secondaryScan;
      final delayedPaint = Paint()
        ..color = structureBlue.withValues(
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
      ..color = structureBlue.withValues(alpha: .64 * material)
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
      structure..color = structureBlue.withValues(alpha: .42 * material),
    );
    _line(
      canvas,
      Offset(size.width - 10, 20),
      Offset(size.width - 10, 35),
      structure,
    );

    final tick = Paint()
      ..color = structureBlue.withValues(alpha: .72 * material);
    for (final point in [
      const Offset(56, 15),
      Offset(size.width * .52, 15),
      Offset(size.width * .59, size.height - 15),
      Offset(size.width - 28, size.height - 15),
    ]) {
      canvas.drawCircle(point, 1.35, tick);
    }
    canvas.restore();
  }

  void _paintDisengage(Canvas canvas, Size size, Offset origin) {
    final trigger = _interval(exitProgress, 0, .12);
    final reverseScan = _interval(exitProgress, .30, .62);
    final planeCollapse = _interval(exitProgress, .38, .72);
    final ringUnlock = _interval(exitProgress, .62, .90);
    final pointCollapse = _interval(exitProgress, .85, 1);

    final plane = Paint()
      ..color = structureBlue.withValues(
        alpha: .045 * trigger * (1 - planeCollapse),
      )
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(8, 7, math.max(0, size.width - 16), size.height - 14),
      plane,
    );

    final acknowledge = Paint()
      ..color = const Color(0xFFE3F7FF).withValues(alpha: .62 * trigger)
      ..strokeWidth = 1.3;
    canvas.drawLine(
      Offset(56, size.height * .5),
      Offset(size.width - 16, size.height * .5),
      acknowledge,
    );

    if (reverseScan > 0) {
      final scanX =
          size.width - 14 - (size.width - 14 - origin.dx) * reverseScan;
      final scan = Paint()
        ..color = primaryBlue.withValues(alpha: .68 * (1 - reverseScan * .35))
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(scanX, size.height * .5),
        Offset(size.width - 14, size.height * .5),
        scan,
      );
      canvas.drawLine(Offset(scanX, 12), Offset(scanX, size.height - 12), scan);
    }

    final structure = Paint()
      ..color = structureBlue.withValues(alpha: .64 * (1 - planeCollapse))
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final retract = 1 - planeCollapse;
    _line(
      canvas,
      const Offset(60, 10),
      Offset(60 + (size.width * .42 - 60) * retract, 10),
      structure,
    );
    _line(
      canvas,
      Offset(size.width * .64, 10),
      Offset(
        size.width * .64 + (size.width - 12 - size.width * .64) * retract,
        10,
      ),
      structure,
    );
    _line(
      canvas,
      const Offset(16, 48),
      Offset(16 + (size.width * .32 - 16) * retract, 48),
      structure,
    );
    _line(
      canvas,
      Offset(size.width * .72, 48),
      Offset(
        size.width * .72 + (size.width - 20 - size.width * .72) * retract,
        48,
      ),
      structure,
    );

    final ringAlpha = ringUnlock * (1 - pointCollapse) * .72;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1;
    for (final values in [(19.0, .9), (29.0, -1.2), (39.0, 2.1)]) {
      ring.color = primaryBlue.withValues(alpha: ringAlpha);
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: values.$1),
        values.$2 - ringUnlock * 1.15,
        math.pi * 1.02,
        false,
        ring,
      );
    }

    final reticle = Paint()
      ..color = primaryBlue.withValues(alpha: ringAlpha * .8)
      ..strokeWidth = 1;
    canvas.drawLine(
      origin - const Offset(10, 0),
      origin - const Offset(3, 0),
      reticle,
    );
    canvas.drawLine(
      origin + const Offset(3, 0),
      origin + const Offset(10, 0),
      reticle,
    );
    canvas.drawCircle(
      origin,
      5 + ringUnlock * 4,
      reticle..style = PaintingStyle.stroke,
    );

    final point = Paint()
      ..color = primaryBlue.withValues(alpha: 1 - pointCollapse)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(origin, 2.8 * (1 - pointCollapse), point);
  }

  void _line(Canvas canvas, Offset start, Offset end, Paint paint) {
    if (end.dx > start.dx) canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _OpticalHudPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.exitProgress != exitProgress ||
      oldDelegate.primaryBlue != primaryBlue ||
      oldDelegate.structureBlue != structureBlue;
}
