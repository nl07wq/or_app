import 'dart:math' as math;
import 'package:flutter/material.dart';

enum FoodAmbientVariant {
  chromaticFluid('CHROMATIC FLUID'),
  metabolicCells('METABOLIC CELLS'),
  thermalCurrent('THERMAL CURRENT');

  const FoodAmbientVariant(this.label);
  final String label;
}

class FoodAmbientComparison extends StatefulWidget {
  const FoodAmbientComparison({required this.variant, super.key});
  final FoodAmbientVariant variant;
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
          painter: _FoodAmbientPainter(widget.variant, _clock.value * 48),
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
                ChoiceChip(
                  key: ValueKey('food-ambient-${v.name}'),
                  label: Text(v.label),
                  selected: v == selected,
                  onSelected: (_) => onChanged(v),
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
    // Each mass has a slow advective drift and a separate, faster surface
    // current.  The closed paths are cubic through their sampled anchors so
    // no polygon edges survive on a small phone display.
    final bodies =
        <({Offset center, double radius, double phase, Color color})>[];
    for (var i = 0; i < 5; i++) {
      final q = t * (.105 + i * .021) + i * 2.13;
      final center = Offset(
        s.width * (.50 + .34 * math.sin(q * .63 + i * .7)),
        s.height * (.48 + .31 * math.cos(q * .49 + i * 1.1)),
      );
      final radius = s.shortestSide * (.235 + (i % 3) * .028);
      bodies.add((
        center: center,
        radius: radius,
        phase: q,
        color: _cool[i % _cool.length],
      ));
      final path = _smoothOrganicPath(center, radius, q, i, 16, .25);
      final color = _cool[i % _cool.length];
      c.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .09)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
      c.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              math.sin(q * 1.7) * .32,
              math.cos(q * 1.31) * .32,
            ),
            radius: 1.05,
            colors: [
              Color.lerp(color, Colors.white, .32)!.withValues(alpha: .24),
              color.withValues(alpha: .105),
              color.withValues(alpha: .018),
            ],
            stops: const [.0, .57, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2)),
      );
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15
          ..color = Color.lerp(
            color,
            Colors.white,
            .42,
          )!.withValues(alpha: .22),
      );
      // Moving internal caustic; it gives the mass thickness rather than a
      // flat gradient-circle appearance.
      c.drawCircle(
        center + Offset(math.cos(q * 1.4), math.sin(q * 1.1)) * radius * .28,
        radius * .22,
        Paint()
          ..color = Colors.white.withValues(alpha: .035)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
      );
    }
    // Contact bridges narrow and relax continuously. They visually join bodies
    // only while their surfaces approach, producing necking/pinch-off instead
    // of five unrelated translated blobs.
    for (var i = 0; i < bodies.length; i++) {
      final a = bodies[i];
      final b = bodies[(i + 1) % bodies.length];
      final distance = (b.center - a.center).distance;
      final reach = (a.radius + b.radius) * 1.12;
      final contact = ((reach - distance) / (reach * .42)).clamp(0.0, 1.0);
      if (contact <= .02) continue;
      final direction = (b.center - a.center) / math.max(distance, 1);
      final normal = Offset(-direction.dy, direction.dx);
      final root = math.min(a.radius, b.radius) * (.10 + contact * .17);
      final neck = Path()
        ..moveTo(
          (a.center + direction * a.radius * .68 + normal * root).dx,
          (a.center + direction * a.radius * .68 + normal * root).dy,
        )
        ..cubicTo(
          a.center.dx + direction.dx * a.radius,
          a.center.dy + direction.dy * a.radius,
          b.center.dx - direction.dx * b.radius,
          b.center.dy - direction.dy * b.radius,
          (b.center - direction * b.radius * .68 + normal * root).dx,
          (b.center - direction * b.radius * .68 + normal * root).dy,
        )
        ..lineTo(
          (b.center - direction * b.radius * .68 - normal * root).dx,
          (b.center - direction * b.radius * .68 - normal * root).dy,
        )
        ..cubicTo(
          b.center.dx - direction.dx * b.radius,
          b.center.dy - direction.dy * b.radius,
          a.center.dx + direction.dx * a.radius,
          a.center.dy + direction.dy * a.radius,
          (a.center + direction * a.radius * .68 - normal * root).dx,
          (a.center + direction * a.radius * .68 - normal * root).dy,
        )
        ..close();
      c.drawPath(
        neck,
        Paint()
          ..shader = LinearGradient(
            colors: [
              a.color.withValues(alpha: .12 * contact),
              b.color.withValues(alpha: .15 * contact),
            ],
          ).createShader(Rect.fromPoints(a.center, b.center)),
      );
    }
    // Bound droplets follow separate trajectories and periodically approach a
    // parent mass, reading as pinch-off and re-merging without unbounded state.
    for (var i = 0; i < 11; i++) {
      final parent = bodies[i % bodies.length];
      final phase = t * (.24 + _h(i, 93) * .11) + i * 1.73;
      final orbit = parent.radius * (.82 + .42 * math.sin(phase * .37).abs());
      final center = parent.center + Offset.fromDirection(phase, orbit);
      final radius = s.shortestSide * (.012 + _h(i, 97) * .018);
      final droplet = _smoothOrganicPath(
        center,
        radius,
        phase,
        i + 90,
        10,
        .09,
      );
      c.drawPath(
        droplet,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(
                parent.color,
                Colors.white,
                .38,
              )!.withValues(alpha: .28),
              parent.color.withValues(alpha: .08),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    for (var i = 0; i < 7; i++) {
      final q = t * (.18 + i * .017) + i * 1.91;
      final left = Offset(-18, s.height * (.12 + i * .125));
      final right = Offset(s.width + 18, s.height * (.18 + i * .115));
      final filament = Path()
        ..moveTo(left.dx, left.dy)
        ..cubicTo(
          s.width * .22,
          left.dy + s.height * .19 * math.sin(q),
          s.width * .72,
          right.dy - s.height * .21 * math.cos(q * .83),
          right.dx,
          right.dy,
        );
      c.drawPath(
        filament,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.1 + (i % 3) * .72
          ..color = _cool[i % 4].withValues(alpha: .17),
      );
    }
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
      final reaction = Offset.lerp(a.center, b.center, exchange)! +
          Offset(0, math.sin(exchange * math.pi * 2 + a.phase) * 7);
      c.drawCircle(
        reaction,
        2.2 + math.sin(exchange * math.pi).abs() * 1.8,
        Paint()
          ..color = Color.lerp(a.color, b.color, exchange)!
              .withValues(alpha: .48)
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
