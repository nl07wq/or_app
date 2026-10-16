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
    for (var i = 0; i < 5; i++) {
      final q = t * (.16 + i * .035) + i * 1.7;
      final o = Offset(
        s.width * (.5 + .36 * math.sin(q * .7 + i)),
        s.height * (.48 + .34 * math.cos(q * .53 + i)),
      );
      final p = _blob(o, s.shortestSide * (.22 + i * .018), q, i, 18, .3);
      final col = _cool[i % 4];
      c.drawPath(
        p,
        Paint()
          ..color = col.withValues(alpha: .07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      c.drawPath(p, Paint()..color = col.withValues(alpha: .10));
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = col.withValues(alpha: .27),
      );
    }
    for (var i = 0; i < 8; i++) {
      final q = t * (.2 + i * .012) + i;
      final y = s.height * (.1 + .11 * i);
      final p = Path()
        ..moveTo(-20, y)
        ..cubicTo(
          s.width * .28,
          y + 70 * math.sin(q),
          s.width * .7,
          y - 85 * math.cos(q * .8),
          s.width + 20,
          y + 30 * math.sin(q * .7),
        );
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.2 + i % 3
          ..color = _cool[i % 4].withValues(alpha: .13),
      );
    }
  }

  void _cells(Canvas c, Size s) {
    for (var i = 0; i < 17; i++) {
      final seed = _h(i, 9);
      final q = t * (.23 + seed * .18) + i;
      final o = Offset(
        s.width * (.06 + .88 * _h(i, 11)) + 18 * math.sin(q * .7),
        s.height * (.05 + .9 * _h(i, 13)) + 20 * math.cos(q * .63),
      );
      final r = s.shortestSide * (.052 + seed * .072);
      final split = i % 5 == 0 ? math.sin(q * .36).abs() : 0.0;
      final col = _cool[i % 3];
      final p = _blob(
        o,
        r,
        q,
        i + 30,
        14,
        .22,
        x: 1 + split * .55,
        y: 1 - split * .18,
      );
      c.drawPath(p, Paint()..color = col.withValues(alpha: .055));
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + seed
          ..color = col.withValues(alpha: .32),
      );
      c.drawCircle(
        o,
        r * .26,
        Paint()
          ..color = col.withValues(alpha: .17)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      c.drawCircle(o, r * .14, Paint()..color = col.withValues(alpha: .42));
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

  Path _blob(
    Offset o,
    double r,
    double q,
    int seed,
    int n,
    double d, {
    double x = 1,
    double y = 1,
  }) {
    final p = Path();
    for (var i = 0; i <= n; i++) {
      final a = i / n * math.pi * 2;
      final w =
          1 +
          d *
              (.58 * math.sin(a * 3 + q + seed) +
                  .3 * math.sin(a * 7 - q * .7));
      final z = Offset(
        o.dx + math.cos(a) * r * w * x,
        o.dy + math.sin(a) * r * w * y,
      );
      i == 0 ? p.moveTo(z.dx, z.dy) : p.lineTo(z.dx, z.dy);
    }
    return p..close();
  }

  double _h(int a, int b) =>
      (math.sin(a * 12.9898 + b * 78.233) * 43758.5453).abs() % 1;
  @override
  bool shouldRepaint(covariant _FoodAmbientPainter old) =>
      old.variant != variant || old.t != t;
}
