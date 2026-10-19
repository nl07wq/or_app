import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';

enum FoodAmbientVariant {
  gravityFlip('GRAVITY FLIP'),
  continuousCirculation('CONTINUOUS CIRCULATION'),
  metabolicCells('METABOLIC CELLS'),
  thermalCurrent('THERMAL CURRENT');

  const FoodAmbientVariant(this.label);
  final String label;
}

@immutable
class OilTimerDrop {
  const OilTimerDrop({
    required this.id,
    required this.center,
    required this.radius,
    required this.color,
    required this.surfacePhase,
    required this.squashDirection,
    required this.squashStrength,
  });

  final int id;
  final Offset center;
  final double radius;
  final Color color;
  final double surfacePhase;
  final Offset squashDirection;
  final double squashStrength;
}

@immutable
class OilTimerFrame {
  const OilTimerFrame({required this.drops, required this.rotationRadians});

  final List<OilTimerDrop> drops;
  final double rotationRadians;
}

class _RawOilDrop {
  const _RawOilDrop({
    required this.id,
    required this.center,
    required this.radius,
    required this.color,
    required this.surfacePhase,
  });

  final int id;
  final Offset center;
  final double radius;
  final Color color;
  final double surfacePhase;
}

/// A bounded, deterministic oil-timer model. Droplets remain separate and
/// only compress and slide at contact, avoiding the former implicit field,
/// shared contour, and pigment mixing computation.
abstract final class OilTimerMotion {
  static const cycleSeconds = 48.0;
  static const dropCount = 11;
  static const maximumContactCount = 18;
  static const _palette = <Color>[
    Color(0xff32ddd0),
    Color(0xff438cff),
    Color(0xff8f70ff),
    Color(0xffed5fbb),
    Color(0xffff8db5),
  ];

  static OilTimerFrame gravityFlipFrame(Size size, double seconds) {
    final local = seconds % cycleSeconds;
    final rotation = _gravityRotation(local);
    final firstFall = local <= 10 ? _ease(local / 10) : 1.0;
    final secondFall = local < 20
        ? 0.0
        : local <= 30
        ? _ease((local - 20) / 10)
        : 1.0;
    final isSecondHalf = local >= 20;
    final raw = <_RawOilDrop>[];
    final viewportCenter = Offset(size.width / 2, size.height / 2);
    final min = size.shortestSide;
    for (var index = 0; index < dropCount; index++) {
      final seed = _hash(index, 17);
      final delay = .035 + _hash(index, 23) * .19;
      final progress = isSecondHalf
          ? _stagger(secondFall, delay)
          : _stagger(firstFall, delay);
      final startY = size.height * -.36 + seed * size.height * .12;
      final endY = size.height * .34 - seed * size.height * .08;
      final localY = isSecondHalf
          ? endY + (startY - endY) * progress
          : startY + (endY - startY) * progress;
      final localX =
          (seed - .5) * size.width * .75 +
          math.sin(index * 1.71) * size.width * .045;
      raw.add(
        _RawOilDrop(
          id: index,
          center: _rotate(
            viewportCenter + Offset(localX, localY),
            viewportCenter,
            rotation,
          ),
          radius: min * (.040 + _hash(index, 31) * .061),
          color: _colorFor(index),
          surfacePhase: local / cycleSeconds * math.pi * 2 + index * .71,
        ),
      );
    }
    return OilTimerFrame(
      drops: _resolveContacts(raw),
      rotationRadians: rotation,
    );
  }

  static OilTimerFrame continuousCirculationFrame(Size size, double seconds) {
    final raw = <_RawOilDrop>[];
    final min = size.shortestSide;
    for (var index = 0; index < dropCount; index++) {
      final seed = _hash(index, 43);
      final speed = .030 + _hash(index, 47) * .015;
      final progress =
          (seconds * speed + index / dropCount + _hash(index, 53) * .04) % 1;
      final travel = progress < .72
          ? _ease(progress / .72) * .84
          : .84 + (progress - .72) / .28 * .55;
      raw.add(
        _RawOilDrop(
          id: index,
          center: Offset(
            size.width * (.12 + seed * .76) +
                math.sin(progress * math.pi * 2 + index) * size.width * .025,
            size.height * (-.18 + travel),
          ),
          radius: min * (.038 + _hash(index, 59) * .056),
          color: _colorFor(index + 2),
          surfacePhase: progress * math.pi * 2 + index * .89,
        ),
      );
    }
    return OilTimerFrame(drops: _resolveContacts(raw), rotationRadians: 0);
  }

  static List<OilTimerDrop> _resolveContacts(List<_RawOilDrop> raw) {
    final displacement = List<Offset>.filled(raw.length, Offset.zero);
    final squash = List<double>.filled(raw.length, 0);
    for (var first = 0; first < raw.length - 1; first++) {
      for (var second = first + 1; second < raw.length; second++) {
        final a = raw[first];
        final b = raw[second];
        final delta = b.center - a.center;
        final distance = delta.distance;
        final limit = a.radius + b.radius;
        if (distance >= limit * 1.04) continue;
        final direction = distance < .001
            ? const Offset(1, 0)
            : delta / distance;
        final strength = _ease(
          ((limit * 1.04 - distance) / (limit * .26)).clamp(0.0, 1.0),
        );
        displacement[first] -= direction * a.radius * strength * .14;
        displacement[second] += direction * b.radius * strength * .14;
        squash[first] += strength;
        squash[second] += strength;
      }
    }
    return List<OilTimerDrop>.generate(raw.length, (index) {
      final direction = displacement[index].distanceSquared < .0001
          ? const Offset(1, 0)
          : displacement[index] / displacement[index].distance;
      return OilTimerDrop(
        id: raw[index].id,
        center: raw[index].center + displacement[index],
        radius: raw[index].radius,
        color: raw[index].color,
        surfacePhase: raw[index].surfacePhase,
        squashDirection: direction,
        squashStrength: squash[index].clamp(0.0, .58),
      );
    });
  }

  static double _gravityRotation(double time) {
    if (time < 14) return 0;
    if (time < 20) return math.pi * _ease((time - 14) / 6);
    if (time < 34) return math.pi;
    if (time < 40) return math.pi + math.pi * _ease((time - 34) / 6);
    return math.pi * 2;
  }

  static double _stagger(double value, double delay) =>
      _ease(((value - delay) / (1 - delay)).clamp(0.0, 1.0));

  static double _ease(double value) => value * value * (3 - 2 * value);

  static Offset _rotate(Offset point, Offset center, double radians) {
    final translated = point - center;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return center +
        Offset(
          translated.dx * cos - translated.dy * sin,
          translated.dx * sin + translated.dy * cos,
        );
  }

  static double _hash(int a, int b) =>
      (math.sin(a * 12.9898 + b * 78.233) * 43758.5453).abs() % 1;

  static Color _colorFor(int index) => Color.lerp(
    _palette[index % _palette.length],
    Colors.white,
    .025 * (index % 4),
  )!;
}

class FoodAmbientComparison extends StatefulWidget {
  const FoodAmbientComparison({
    required this.variant,
    this.debugTime,
    super.key,
  });
  final FoodAmbientVariant variant;
  final double? debugTime;
  static double motionSignatureFor(FoodAmbientVariant v, double t) =>
      math.sin(t * (v.index + 1.17)) + math.cos(t * (v.index + .43));
  @override
  State<FoodAmbientComparison> createState() => _FoodAmbientComparisonState();
}

class _FoodAmbientComparisonState extends State<FoodAmbientComparison>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 48),
  )..repeat();
  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, child) => CustomPaint(
          painter: _FoodAmbientPainter(
            widget.variant,
            widget.debugTime ?? _clock.value * 48,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class FoodAmbientComparisonSelector extends StatelessWidget {
  const FoodAmbientComparisonSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });
  final FoodAmbientVariant selected;
  final ValueChanged<FoodAmbientVariant> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      label: 'FOOD ambient comparison',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.outline.withValues(alpha: .35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in FoodAmbientVariant.values)
                ActionableFeedbackRegion(
                  role: ActionableFeedbackRole.silent,
                  child: ChoiceChip(
                    key: ValueKey('food-ambient-${v.name}'),
                    label: Text(v.label),
                    selected: v == selected,
                    onSelected: (_) {
                      if (v == selected) return;
                      GlobalTouchRipple.previewFeedback(
                        TouchFeedbackSound.cursor,
                      );
                      onChanged(v);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodAmbientPainter extends CustomPainter {
  const _FoodAmbientPainter(this.variant, this.t);
  final FoodAmbientVariant variant;
  final double t;

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xff05080d));
    switch (variant) {
      case FoodAmbientVariant.gravityFlip:
        _oilTimer(c, s, OilTimerMotion.gravityFlipFrame(s, t));
      case FoodAmbientVariant.continuousCirculation:
        _oilTimer(c, s, OilTimerMotion.continuousCirculationFrame(s, t));
      case FoodAmbientVariant.metabolicCells:
        _restoredCells(c, s);
      case FoodAmbientVariant.thermalCurrent:
        _thermal(c, s);
    }
  }

  void _oilTimer(Canvas c, Size s, OilTimerFrame frame) {
    _waterParticles(c, s);
    final viewport = (Offset.zero & s).inflate(s.shortestSide * .12);
    for (final drop in frame.drops) {
      if (!viewport.contains(drop.center)) continue;
      final path = _smoothOrganicPath(
        drop.center,
        drop.radius,
        drop.surfacePhase,
        drop.id,
        16,
        .050,
        contactDirection: drop.squashDirection,
        contactStrength: drop.squashStrength,
      );
      final bounds = path.getBounds();
      c.drawPath(
        path,
        Paint()
          ..color = drop.color.withValues(alpha: .11)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      c.save();
      c.clipPath(path);
      c.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              -.24 + math.sin(drop.surfacePhase) * .08,
              -.30 + math.cos(drop.surfacePhase * .7) * .06,
            ),
            radius: 1.05,
            colors: [
              Color.lerp(drop.color, Colors.white, .42)!.withValues(alpha: .48),
              drop.color.withValues(alpha: .36),
              Color.lerp(
                drop.color,
                const Color(0xff071522),
                .58,
              )!.withValues(alpha: .26),
              drop.color.withValues(alpha: .08),
            ],
            stops: const [0, .30, .70, 1],
          ).createShader(bounds),
      );
      c.restore();
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .9
          ..color = Color.lerp(
            drop.color,
            Colors.white,
            .42,
          )!.withValues(alpha: .42),
      );
    }
  }

  void _waterParticles(Canvas c, Size s) {
    for (var index = 0; index < 14; index++) {
      final seed = _h(index, 67);
      final travel = (t * (.018 + seed * .012) + seed) % 1;
      final center = Offset(
        s.width * (.06 + seed * .88) +
            math.sin(travel * math.pi * 2 + index) * 5,
        s.height * (1.10 - travel * 1.22),
      );
      final radius = 1.6 + seed * 3.5;
      final opacity = math.sin(math.pi * travel) * (.13 + seed * .13);
      c.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65
          ..color = const Color(0xffa6f7ff).withValues(alpha: opacity),
      );
      c.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -2.6,
        1.0,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: opacity * .8),
      );
    }

    // Sparse light points remain a separate, quieter support layer from the
    // transparent bubbles above.
    for (var index = 0; index < 18; index++) {
      final seed = _h(index, 173);
      final travel = (t * (.026 + seed * .018) + seed * .73) % 1;
      final position = Offset(
        s.width * (.04 + seed * .92) +
            math.sin(travel * math.pi * 2 + seed) * 5,
        s.height * (1.08 - travel * 1.16),
      );
      final edgeFade = math.sin(math.pi * travel).clamp(0.0, 1.0);
      final color = Color.lerp(const Color(0xFF78E8FF), Colors.white, seed)!;
      c.drawCircle(
        position,
        .45 + seed * .75,
        Paint()..color = color.withValues(alpha: .12 * edgeFade),
      );
    }
  }

  void _restoredCells(Canvas c, Size s) {
    // Restored from f8d5faf3: a cell-specific grid population and palette.
    // V4 adds anatomy but deliberately avoids oil paths or merged fields.
    const palette = [Color(0xff55d5c0), Color(0xff74a4ff), Color(0xffd184c7)];
    final columns = math.max(4, (s.width / 96).floor());
    final rows = math.max(7, (s.height / 92).floor());
    final cellWidth = s.width / columns;
    final cellHeight = s.height / rows;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final seed = _h(column, row);
        final phase = t * (.34 + seed * .15) + seed * math.pi * 2;
        final pulse = .78 + .12 * math.sin(phase);
        final center = Offset(
          (column + .5 + .075 * math.sin(phase * .7)) * cellWidth,
          (row + .5 + .062 * math.cos(phase * .8)) * cellHeight,
        );
        final radius = (cellWidth + cellHeight) * (.16 + seed * .09) * pulse;
        final color = palette[(seed * palette.length).floor() % palette.length];
        final membrane = _smoothOrganicPath(
          center,
          radius,
          phase,
          row * 7 + column,
          14,
          .035,
        );
        final bounds = membrane.getBounds();
        c.drawPath(
          membrane,
          Paint()
            ..color = color.withValues(alpha: .055)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        c.save();
        c.clipPath(membrane);
        c.drawRect(
          bounds,
          Paint()
            ..shader = RadialGradient(
              center: Alignment(
                -.25 + math.sin(phase) * .07,
                -.25 + math.cos(phase * .8) * .06,
              ),
              colors: [
                Color.lerp(color, Colors.white, .36)!.withValues(alpha: .25),
                color.withValues(alpha: .15),
                Color.lerp(
                  color,
                  const Color(0xff08101e),
                  .56,
                )!.withValues(alpha: .10),
                color.withValues(alpha: 0),
              ],
              stops: const [0, .34, .76, 1],
            ).createShader(bounds),
        );
        final nucleusCenter =
            center +
            Offset(math.cos(phase * .58), math.sin(phase * .72)) * radius * .18;
        final nucleus = Rect.fromCircle(
          center: nucleusCenter,
          radius: radius * .27,
        );
        c.drawOval(
          nucleus,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.25, -.22),
              colors: [
                Color.lerp(color, Colors.white, .22)!.withValues(alpha: .28),
                Color.lerp(
                  color,
                  const Color(0xff11152b),
                  .72,
                )!.withValues(alpha: .34),
                const Color(0xff050914).withValues(alpha: .25),
              ],
              stops: const [0, .56, 1],
            ).createShader(nucleus),
        );
        c.drawCircle(
          nucleusCenter + Offset(radius * .05, -radius * .04),
          radius * .07,
          Paint()..color = Colors.white.withValues(alpha: .31),
        );
        c.restore();
        c.drawPath(
          membrane,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .85 + seed * .35
            ..color = Color.lerp(
              color,
              Colors.white,
              .34,
            )!.withValues(alpha: .34),
        );
      }
    }
  }

  void _thermal(Canvas c, Size s) {
    for (var i = 0; i < 7; i++) {
      final seed = _h(i, 77), q = t * (.28 + seed * .14) + i;
      final x = s.width * (.05 + .9 * _h(i, 81));
      final pts = <Offset>[];
      for (var j = 0; j < 17; j++) {
        final u = j / 16;
        pts.add(
          Offset(
            x + s.width * (.07 + seed * .06) * math.sin(q + u * 5),
            s.height * (1.04 - u * (.62 + seed * .2)),
          ),
        );
      }
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final z in pts) {
        p.lineTo(z.dx + 18 * (1 - z.dy / s.height), z.dy);
      }
      for (final z in pts.reversed) {
        p.lineTo(z.dx - 18 * (1 - z.dy / s.height), z.dy);
      }
      p.close();
      final col = [
        const Color(0xffffb45f),
        const Color(0xffff704e),
        const Color(0xffe94d70),
      ][i % 3];
      c.drawPath(
        p,
        Paint()
          ..color = col.withValues(alpha: .055)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      final core = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final z in pts.skip(1)) {
        core.lineTo(z.dx, z.dy);
      }
      c.drawPath(
        core,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.5 + seed
          ..color = col.withValues(alpha: .3),
      );
      for (var k = 0; k < 4; k++) {
        final u = (t * (.24 + seed * .14) + k * .27) % 1;
        final z = pts[(u * 16).floor()];
        c.drawCircle(z, 1.5, Paint()..color = col.withValues(alpha: .5));
      }
    }
  }

  Path _smoothOrganicPath(
    Offset o,
    double r,
    double q,
    int seed,
    int n,
    double d, {
    double x = 1,
    double y = 1,
    Offset? contactDirection,
    double contactStrength = 0,
  }) {
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final w =
          1 +
          d *
              (.58 * math.sin(a * 3 + q + seed) +
                  .3 * math.sin(a * 7 - q * .7)) -
          contactStrength *
              math.max(
                0,
                math.cos(
                  a -
                      math.atan2(
                        contactDirection?.dy ?? 0,
                        contactDirection?.dx ?? 1,
                      ),
                ),
              );
      points.add(
        Offset(o.dx + math.cos(a) * r * w * x, o.dy + math.sin(a) * r * w * y),
      );
    }
    final p = Path();
    final start = Offset(
      (points.last.dx + points.first.dx) / 2,
      (points.last.dy + points.first.dy) / 2,
    );
    p.moveTo(start.dx, start.dy);
    for (var i = 0; i < points.length; i++) {
      final previous = points[(i - 1 + points.length) % points.length];
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      final tangent = next - previous;
      p.cubicTo(
        current.dx - tangent.dx * .12,
        current.dy - tangent.dy * .12,
        current.dx + tangent.dx * .12,
        current.dy + tangent.dy * .12,
        mid.dx,
        mid.dy,
      );
    }
    return p..close();
  }

  double _h(int a, int b) =>
      (math.sin(a * 12.9898 + b * 78.233) * 43758.5453).abs() % 1;
  @override
  bool shouldRepaint(covariant _FoodAmbientPainter old) =>
      old.variant != variant || old.t != t;
}
