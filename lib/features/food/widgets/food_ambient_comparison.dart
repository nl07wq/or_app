import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';

enum FoodAmbientVariant {
  chromaticFluid('CHROMATIC FLUID'),
  metabolicCells('METABOLIC CELLS'),
  thermalCurrent('THERMAL CURRENT');

  const FoodAmbientVariant(this.label);
  final String label;
}

enum ChromaticFluidDropSize { large, medium, small }

@immutable
class ChromaticFluidDrop {
  const ChromaticFluidDrop({
    required this.id,
    required this.center,
    required this.radius,
    required this.color,
    required this.size,
    required this.surfacePhase,
  });

  final int id;
  final Offset center;
  final double radius;
  final Color color;
  final ChromaticFluidDropSize size;
  final double surfacePhase;
}

@immutable
class ChromaticFluidBridge {
  const ChromaticFluidBridge({
    required this.first,
    required this.second,
    required this.strength,
    required this.neckWidth,
    required this.path,
  });

  final ChromaticFluidDrop first;
  final ChromaticFluidDrop second;
  final double strength;
  final double neckWidth;
  final Path path;

  Color get mixedColor => Color.lerp(first.color, second.color, .5)!;
}

@immutable
class ChromaticFluidFrame {
  const ChromaticFluidFrame({required this.drops, required this.bridges});

  final List<ChromaticFluidDrop> drops;
  final List<ChromaticFluidBridge> bridges;
}

/// Deterministic, bounded geometry for the lightweight Phase 1 metaballs.
///
/// Three scheduled pairs travel through separation, contact, fusion and
/// pinch-off at different phases. Six independent droplets keep the field
/// alive without adding an unbounded all-pairs solver.
abstract final class ChromaticFluidMetaballs {
  static const dropCount = 12;
  static const maximumBridgeCount = 3;
  static const cycleSeconds = 18.0;
  static const _palette = <Color>[
    Color(0xff32ddd0),
    Color(0xff438cff),
    Color(0xff9368ff),
    Color(0xffed5fbb),
    Color(0xffff9b55),
    Color(0xff58d58a),
  ];

  static ChromaticFluidFrame frame(Size size, double seconds) {
    final shortest = size.shortestSide;
    final drops = <ChromaticFluidDrop>[];
    const pairAnchors = <Offset>[
      Offset(.33, .20),
      Offset(.68, .49),
      Offset(.36, .78),
    ];
    const pairRadii = <(double, double)>[
      (.145, .086),
      (.122, .072),
      (.132, .078),
    ];
    const pairAngles = <double>[-.18, 2.82, .34];

    for (var pair = 0; pair < 3; pair++) {
      final phase = seconds / cycleSeconds * math.pi * 2 + pair * 2.07;
      final approach = .5 + .5 * math.sin(phase);
      final easedApproach = _smoothStep(approach);
      final firstRadius = shortest * pairRadii[pair].$1;
      final secondRadius = shortest * pairRadii[pair].$2;
      final distanceFactor = 1.52 - easedApproach * .91;
      final distance = (firstRadius + secondRadius) * distanceFactor;
      final angle = pairAngles[pair] + math.sin(seconds * .075 + pair) * .22;
      final direction = Offset.fromDirection(angle);
      final anchor = pairAnchors[pair];
      final midpoint = Offset(
        size.width * anchor.dx + math.sin(seconds * .11 + pair * 1.7) * 13,
        size.height * anchor.dy + math.cos(seconds * .09 + pair * 2.1) * 17,
      );
      final radiusSum = firstRadius + secondRadius;
      final firstCenter =
          midpoint - direction * distance * (secondRadius / radiusSum);
      final secondCenter =
          midpoint + direction * distance * (firstRadius / radiusSum);
      drops.add(
        ChromaticFluidDrop(
          id: pair * 2,
          center: firstCenter,
          radius: firstRadius,
          color: _palette[pair * 2],
          size: ChromaticFluidDropSize.large,
          surfacePhase: seconds * (.34 + pair * .025) + pair * 1.3,
        ),
      );
      drops.add(
        ChromaticFluidDrop(
          id: pair * 2 + 1,
          center: secondCenter,
          radius: secondRadius,
          color: _palette[pair * 2 + 1],
          size: ChromaticFluidDropSize.medium,
          surfacePhase: seconds * (.41 + pair * .021) + pair * 1.8,
        ),
      );
    }

    const smallAnchors = <Offset>[
      Offset(.09, .10),
      Offset(.80, .16),
      Offset(.12, .43),
      Offset(.89, .67),
      Offset(.16, .91),
      Offset(.76, .90),
    ];
    for (var i = 0; i < smallAnchors.length; i++) {
      final phase = seconds * (.15 + i * .012) + i * 1.47;
      final anchor = smallAnchors[i];
      drops.add(
        ChromaticFluidDrop(
          id: 6 + i,
          center: Offset(
            size.width * anchor.dx + math.sin(phase * .83) * (13 + i % 3 * 4),
            size.height * anchor.dy + math.cos(phase * .67) * (16 + i % 2 * 5),
          ),
          radius: shortest * (.020 + (i % 3) * .008),
          color: _palette[(i + 1) % _palette.length],
          size: ChromaticFluidDropSize.small,
          surfacePhase: phase,
        ),
      );
    }

    final bridges = <ChromaticFluidBridge>[];
    for (var pair = 0; pair < 3; pair++) {
      final first = drops[pair * 2];
      final second = drops[pair * 2 + 1];
      final normalizedDistance =
          (second.center - first.center).distance /
          (first.radius + second.radius);
      final strength = contactStrength(normalizedDistance);
      if (strength <= .005) continue;
      final bridge = bridgePath(first, second, strength);
      bridges.add(
        ChromaticFluidBridge(
          first: first,
          second: second,
          strength: strength,
          neckWidth:
              math.min(first.radius, second.radius) *
              (.025 + .36 * math.pow(strength, 1.18)),
          path: bridge,
        ),
      );
    }
    return ChromaticFluidFrame(
      drops: List.unmodifiable(drops),
      bridges: List.unmodifiable(bridges),
    );
  }

  static double contactStrength(double normalizedDistance) {
    final raw = ((1.43 - normalizedDistance) / .82).clamp(0.0, 1.0);
    return _smoothStep(raw);
  }

  static Path dropPath(ChromaticFluidDrop drop) {
    final samples = switch (drop.size) {
      ChromaticFluidDropSize.large => 30,
      ChromaticFluidDropSize.medium => 24,
      ChromaticFluidDropSize.small => 18,
    };
    final amplitude = switch (drop.size) {
      ChromaticFluidDropSize.large => .065,
      ChromaticFluidDropSize.medium => .078,
      ChromaticFluidDropSize.small => .032,
    };
    final points = <Offset>[];
    for (var index = 0; index < samples; index++) {
      final angle = index / samples * math.pi * 2;
      final deformation =
          1 +
          amplitude *
              (.62 * math.sin(angle * 3 + drop.surfacePhase) +
                  .25 * math.sin(angle * 5 - drop.surfacePhase * .71) +
                  .13 * math.sin(angle * 2 + drop.id * 1.31));
      points.add(
        drop.center + Offset.fromDirection(angle, drop.radius * deformation),
      );
    }
    return _closedSmoothPath(points);
  }

  static Path bridgePath(
    ChromaticFluidDrop first,
    ChromaticFluidDrop second,
    double strength,
  ) {
    final delta = second.center - first.center;
    final distance = math.max(delta.distance, .001);
    final direction = delta / distance;
    final normal = Offset(-direction.dy, direction.dx);
    final smallerRadius = math.min(first.radius, second.radius);
    final shoulder = smallerRadius * (.10 + strength * .24);
    final neck = smallerRadius * (.025 + .36 * math.pow(strength, 1.18));
    final firstRoot =
        first.center + direction * first.radius * (1 - strength * .24);
    final secondRoot =
        second.center - direction * second.radius * (1 - strength * .24);
    final midpoint = Offset.lerp(firstRoot, secondRoot, .5)!;
    final path = Path()
      ..moveTo(
        (firstRoot + normal * shoulder).dx,
        (firstRoot + normal * shoulder).dy,
      )
      ..cubicTo(
        firstRoot.dx + direction.dx * distance * .18,
        firstRoot.dy + direction.dy * distance * .18,
        midpoint.dx - direction.dx * distance * .10 + normal.dx * neck,
        midpoint.dy - direction.dy * distance * .10 + normal.dy * neck,
        (midpoint + normal * neck).dx,
        (midpoint + normal * neck).dy,
      )
      ..cubicTo(
        midpoint.dx + direction.dx * distance * .10 + normal.dx * neck,
        midpoint.dy + direction.dy * distance * .10 + normal.dy * neck,
        secondRoot.dx - direction.dx * distance * .18,
        secondRoot.dy - direction.dy * distance * .18,
        (secondRoot + normal * shoulder).dx,
        (secondRoot + normal * shoulder).dy,
      )
      ..lineTo(
        (secondRoot - normal * shoulder).dx,
        (secondRoot - normal * shoulder).dy,
      )
      ..cubicTo(
        secondRoot.dx - direction.dx * distance * .18,
        secondRoot.dy - direction.dy * distance * .18,
        midpoint.dx + direction.dx * distance * .10 - normal.dx * neck,
        midpoint.dy + direction.dy * distance * .10 - normal.dy * neck,
        (midpoint - normal * neck).dx,
        (midpoint - normal * neck).dy,
      )
      ..cubicTo(
        midpoint.dx - direction.dx * distance * .10 - normal.dx * neck,
        midpoint.dy - direction.dy * distance * .10 - normal.dy * neck,
        firstRoot.dx + direction.dx * distance * .18,
        firstRoot.dy + direction.dy * distance * .18,
        (firstRoot - normal * shoulder).dx,
        (firstRoot - normal * shoulder).dy,
      )
      ..close();
    return path;
  }

  static Path _closedSmoothPath(List<Offset> points) {
    final path = Path();
    final firstMidpoint = Offset.lerp(points.last, points.first, .5)!;
    path.moveTo(firstMidpoint.dx, firstMidpoint.dy);
    for (var index = 0; index < points.length; index++) {
      final previous = points[(index - 1 + points.length) % points.length];
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final midpoint = Offset.lerp(current, next, .5)!;
      final tangent = next - previous;
      path.cubicTo(
        current.dx - tangent.dx * .12,
        current.dy - tangent.dy * .12,
        current.dx + tangent.dx * .12,
        current.dy + tangent.dy * .12,
        midpoint.dx,
        midpoint.dy,
      );
    }
    return path..close();
  }

  static double _smoothStep(double value) => value * value * (3 - 2 * value);
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
  static const _cool = [
    Color(0xff36d8ca),
    Color(0xffdc5bb3),
    Color(0xff886fff),
    Color(0xffffad61),
  ];
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xff05080d));
    switch (variant) {
      case FoodAmbientVariant.chromaticFluid:
        _fluid(c, s);
      case FoodAmbientVariant.metabolicCells:
        _cells(c, s);
      case FoodAmbientVariant.thermalCurrent:
        _thermal(c, s);
    }
  }

  void _fluid(Canvas c, Size s) {
    final frame = ChromaticFluidMetaballs.frame(s, t);
    final dropPaths = <int, Path>{
      for (final drop in frame.drops)
        drop.id: ChromaticFluidMetaballs.dropPath(drop),
    };
    final silhouette = Path();
    for (final path in dropPaths.values) {
      silhouette.addPath(path, Offset.zero);
    }
    for (final bridge in frame.bridges) {
      silhouette.addPath(bridge.path, Offset.zero);
    }

    // A single filled silhouette means intersecting drops and their necks have
    // no internal seam. The restrained exterior bloom softens only the outer
    // liquid boundary rather than blurring the entire viewport.
    c.drawPath(
      silhouette,
      Paint()
        ..color = const Color(0xff49bad4).withValues(alpha: .075)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
    c.save();
    c.clipPath(silhouette);
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x20102b48), Color(0x2813092f), Color(0x1c07372e)],
        ).createShader(Offset.zero & s),
    );

    for (final drop in frame.drops) {
      final highlightCenter =
          drop.center +
          Offset(
                math.cos(drop.surfacePhase * .73),
                math.sin(drop.surfacePhase * .61),
              ) *
              drop.radius *
              .27;
      c.drawCircle(
        drop.center,
        drop.radius * 1.52,
        Paint()
          ..shader =
              RadialGradient(
                center: const Alignment(-.28, -.32),
                radius: 1.0,
                colors: [
                  Color.lerp(
                    drop.color,
                    Colors.white,
                    .34,
                  )!.withValues(alpha: .43),
                  drop.color.withValues(alpha: .28),
                  Color.lerp(
                    drop.color,
                    const Color(0xff091523),
                    .52,
                  )!.withValues(alpha: .10),
                  drop.color.withValues(alpha: 0),
                ],
                stops: const [0, .42, .78, 1],
              ).createShader(
                Rect.fromCircle(
                  center: drop.center,
                  radius: drop.radius * 1.52,
                ),
              ),
      );
      c.drawCircle(
        highlightCenter,
        drop.radius * .24,
        Paint()
          ..color = Colors.white.withValues(
            alpha: drop.size == ChromaticFluidDropSize.small ? .09 : .055,
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            math.max(2, drop.radius * .16),
          ),
      );
    }

    // Explicit bridge gradients create a local intermediate colour. Their
    // area shrinks with the same continuous contact strength as the geometry,
    // so no mixed colour remains after pinch-off.
    for (final bridge in frame.bridges) {
      final rect = Rect.fromPoints(
        bridge.first.center,
        bridge.second.center,
      ).inflate(bridge.neckWidth * 1.5);
      c.drawPath(
        bridge.path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              bridge.first.color.withValues(alpha: .18 + bridge.strength * .15),
              Color.lerp(
                bridge.mixedColor,
                Colors.white,
                .12,
              )!.withValues(alpha: .28 + bridge.strength * .17),
              bridge.second.color.withValues(
                alpha: .18 + bridge.strength * .15,
              ),
            ],
            stops: const [0, .5, 1],
          ).createShader(rect),
      );
    }
    c.restore();
  }

  void _cells(Canvas c, Size s) {
    final cells =
        <({Offset center, double radius, double phase, Color color})>[];
    for (var i = 0; i < 15; i++) {
      final seed = _h(i, 9);
      final q = t * (.23 + seed * .18) + i;
      final o = Offset(
        s.width * (.06 + .88 * _h(i, 11)) + 18 * math.sin(q * .7),
        s.height * (.05 + .9 * _h(i, 13)) + 20 * math.cos(q * .63),
      );
      final r = s.shortestSide * (.052 + seed * .072);
      final split = i % 5 == 0 ? math.sin(q * .36).abs() : 0.0;
      final col = _cool[i % 3];
      cells.add((center: o, radius: r, phase: q, color: col));
      final membrane = _smoothOrganicPath(
        o,
        r,
        q,
        i + 30,
        14,
        .16 + split * .09,
        x: 1 + split * .62,
        y: 1 - split * .24,
      );
      c.drawPath(membrane, Paint()..color = col.withValues(alpha: .07));
      c.drawPath(
        membrane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 + seed * .8
          ..color = Color.lerp(col, Colors.white, .30)!.withValues(alpha: .35),
      );
      c.drawPath(
        _smoothOrganicPath(o, r * .76, q + .55, i + 60, 14, .11),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .75
          ..color = col.withValues(alpha: .15),
      );
      c.drawCircle(
        o + Offset(math.cos(q * .8), math.sin(q * .67)) * r * .12,
        r * .30,
        Paint()
          ..color = Color.lerp(col, Colors.white, .22)!.withValues(alpha: .21)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      c.drawCircle(
        o + Offset(math.cos(q * .8), math.sin(q * .67)) * r * .12,
        r * .15,
        Paint()..color = col.withValues(alpha: .44),
      );
      for (var organelle = 0; organelle < 3; organelle++) {
        final a = q * (1.1 + organelle * .13) + organelle * 2.1;
        c.drawCircle(
          o + Offset(math.cos(a), math.sin(a)) * r * (.35 + organelle * .08),
          r * (.045 + organelle * .012),
          Paint()..color = col.withValues(alpha: .30),
        );
      }
      if (split > .45) {
        final d = Offset(math.cos(q), math.sin(q)) * r * split * .55;
        c.drawCircle(
          o - d,
          r * .13,
          Paint()..color = col.withValues(alpha: .4),
        );
        c.drawCircle(
          o + d,
          r * .13,
          Paint()..color = col.withValues(alpha: .4),
        );
      }
    }
    // Short-lived membrane bridges make local contacts read as a living
    // environment, instead of a uniform field of isolated outlines.
    for (var i = 0; i < cells.length - 1; i += 4) {
      final a = cells[i], b = cells[i + 1];
      final bridge = Path()
        ..moveTo(a.center.dx, a.center.dy)
        ..cubicTo(
          a.center.dx + (b.center.dx - a.center.dx) * .32,
          a.center.dy + 18 * math.sin(a.phase),
          b.center.dx - (b.center.dx - a.center.dx) * .30,
          b.center.dy - 18 * math.cos(b.phase),
          b.center.dx,
          b.center.dy,
        );
      c.drawPath(
        bridge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 + math.sin(t * .41 + i).abs() * 1.8
          ..color = Color.lerp(a.color, b.color, .5)!.withValues(alpha: .12),
      );
      final exchange = (t * (.18 + i * .006) + i * .17) % 1;
      final reaction =
          Offset.lerp(a.center, b.center, exchange)! +
          Offset(0, math.sin(exchange * math.pi * 2 + a.phase) * 7);
      c.drawCircle(
        reaction,
        2.2 + math.sin(exchange * math.pi).abs() * 1.8,
        Paint()
          ..color = Color.lerp(
            a.color,
            b.color,
            exchange,
          )!.withValues(alpha: .48)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    for (var i = 0; i < 30; i++) {
      final q = t * (.32 + _h(i, 33) * .2) + i;
      c.drawCircle(
        Offset(
          s.width * (.5 + .48 * math.sin(q)),
          s.height * (.5 + .46 * math.cos(q * .81)),
        ),
        1 + _h(i, 41) * 1.6,
        Paint()..color = _cool[i % 3].withValues(alpha: .26),
      );
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
  }) {
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final w =
          1 +
          d *
              (.58 * math.sin(a * 3 + q + seed) +
                  .3 * math.sin(a * 7 - q * .7));
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
