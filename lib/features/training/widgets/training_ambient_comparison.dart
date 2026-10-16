import 'dart:math' as math;

import 'package:flutter/material.dart';

enum TrainingAmbientVariant {
  magneticFlux('MAGNETIC FLUX'),
  kineticEngine('KINETIC ENGINE'),
  vectorImpulse('VECTOR IMPULSE');

  const TrainingAmbientVariant(this.label);
  final String label;
}

class TrainingAmbientComparison extends StatefulWidget {
  const TrainingAmbientComparison({super.key, required this.variant});
  final TrainingAmbientVariant variant;

  static double motionSignatureFor(
    TrainingAmbientVariant variant,
    double time,
  ) {
    switch (variant) {
      case TrainingAmbientVariant.magneticFlux:
        return math.sin(time * .31) + math.cos(time * .17 + .8);
      case TrainingAmbientVariant.kineticEngine:
        return math.sin(time * .74) + math.cos(time * .29 + 1.7);
      case TrainingAmbientVariant.vectorImpulse:
        return math.sin(time * 1.19) + math.cos(time * .41 + .35);
    }
  }

  @override
  State<TrainingAmbientComparison> createState() =>
      _TrainingAmbientComparisonState();
}

class _TrainingAmbientComparisonState extends State<TrainingAmbientComparison>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _TrainingAmbientPainter(
            variant: widget.variant,
            time: _controller.value * 48,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class TrainingAmbientComparisonSelector extends StatelessWidget {
  const TrainingAmbientComparisonSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final TrainingAmbientVariant selected;
  final ValueChanged<TrainingAmbientVariant> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xdd07121d),
      border: Border.all(color: const Color(0x664db8ff)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.all(5),
      child: Wrap(
        spacing: 4,
        children: [
          for (final value in TrainingAmbientVariant.values)
            Semantics(
              selected: value == selected,
              child: ChoiceChip(
                    key: ValueKey('training-ambient-${value.name}'),
                label: Text(value.label),
                selected: value == selected,
                onSelected: (_) => onChanged(value),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    ),
  );
}

class _TrainingAmbientPainter extends CustomPainter {
  const _TrainingAmbientPainter({required this.variant, required this.time});
  final TrainingAmbientVariant variant;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff030914),
    );
    switch (variant) {
      case TrainingAmbientVariant.magneticFlux:
        _flux(canvas, size);
      case TrainingAmbientVariant.kineticEngine:
        _engine(canvas, size);
      case TrainingAmbientVariant.vectorImpulse:
        _vectors(canvas, size);
    }
  }

  void _flux(Canvas canvas, Size size) {
    final centers = [
      Offset(
        size.width * (.24 + .07 * math.sin(time * .19)),
        size.height * (.27 + .08 * math.cos(time * .14)),
      ),
      Offset(
        size.width * (.73 + .06 * math.cos(time * .17 + 1)),
        size.height * (.46 + .10 * math.sin(time * .13 + .6)),
      ),
      Offset(
        size.width * (.47 + .09 * math.sin(time * .11 + 2)),
        size.height * (.77 + .05 * math.cos(time * .21)),
      ),
    ];
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 22; i++) {
      final y = (i + .5) / 22;
      final start = Offset(-20, y * size.height);
      final end = Offset(size.width + 20, (1 - y) * size.height);
      final bend =
          (centers[0].dy - centers[1].dy) * (.1 + .03 * i) +
          math.sin(time * .55 + i) * 28;
      final c1 = Offset(size.width * .28, start.dy + bend);
      final c2 = Offset(size.width * .70, end.dy - bend);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
      stroke
        ..color = Color.lerp(
          const Color(0x334be9ff),
          const Color(0x665c5cff),
          i / 22,
        )!
        ..strokeWidth = i % 5 == 0 ? 1.65 : .75;
      canvas.drawPath(path, stroke);
      if (i % 3 == 0) {
        final u = (time * .14 + i * .09) % 1;
        canvas.drawCircle(
          _bezier(start, c1, c2, end, u),
          2.2,
          Paint()..color = const Color(0xff8cf5ff),
        );
      }
    }
    for (var i = 0; i < centers.length; i++) {
      final c = centers[i];
      canvas.drawCircle(
        c,
        26 + math.sin(time * .7 + i) * 5,
        Paint()
          ..color = const Color(0x224fddff)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      canvas.drawCircle(c, 4.5, Paint()..color = const Color(0xffb7faff));
    }
  }

  void _engine(Canvas canvas, Size size) {
    final centers = [
      Offset(size.width * .29, size.height * .36),
      Offset(size.width * .67, size.height * .50),
      Offset(size.width * .43, size.height * .75),
    ];
    final radii = [48.0, 64.0, 37.0];
    final link = Paint()
      ..strokeWidth = 1.3
      ..color = const Color(0x555fc9ff);
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(centers[i], centers[(i + 1) % 3], link);
    }
    for (var i = 0; i < 3; i++) {
      _wheel(
        canvas,
        centers[i],
        radii[i],
        time * (i == 1 ? -.53 : .72 + i * .13),
        i,
      );
    }
    final phase = (math.sin(time * .95) + 1) / 2;
    for (final c in centers) {
      canvas.drawCircle(
        c,
        12 + phase * 7,
        Paint()
          ..color = const Color(0x4478dfff)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(c, 3, Paint()..color = const Color(0xffffca78));
    }
  }

  void _wheel(Canvas canvas, Offset c, double radius, double angle, int index) {
    final metal = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x9983c8ed);
    canvas.drawCircle(c, radius, metal);
    canvas.drawCircle(c, radius * .57, metal..color = const Color(0x557e54ff));
    final node = Paint()..color = const Color(0xff98edff);
    for (var n = 0; n < 12; n++) {
      final a = angle + n * math.pi * 2 / 12;
      final inner = c + Offset(math.cos(a), math.sin(a)) * radius * .58;
      final outer = c + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawLine(inner, outer, metal..strokeWidth = n % 3 == 0 ? 2 : .8);
      if (n % 3 == 0) canvas.drawCircle(outer, 3, node);
    }
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius + 5),
      angle + index,
      math.pi * .46,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xffffb86c),
    );
  }

  void _vectors(Canvas canvas, Size size) {
    for (var i = 0; i < 11; i++) {
      final seed = _h(i + 31);
      final phase = (time * (.13 + seed * .07) + seed) % 1;
      final origin = Offset(
        size.width * (.08 + _h(i + 51) * .84),
        size.height * (.10 + _h(i + 71) * .80),
      );
      final angle = _h(i + 97) * math.pi * 2 + math.sin(time * .2 + i) * .2;
      final length = 60 + _h(i + 119) * 140;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final head = origin + direction * length * phase;
      final alpha = phase < .16 ? phase / .16 : (1 - phase) / .84;
      final streak = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.2 + _h(i + 139) * 2
        ..shader = LinearGradient(
          colors: const [
            Color(0x0087ecff),
            Color(0xdd5ce5ff),
            Color(0x00de5fff),
          ],
        ).createShader(Rect.fromPoints(origin, head));
      canvas.drawLine(
        origin + direction * length * math.max(0, phase - .24),
        head,
        streak,
      );
      canvas.drawCircle(
        head,
        2.5 + alpha * 3,
        Paint()
          ..color = const Color(0xffc6f7ff).withValues(alpha: alpha.clamp(0, 1))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      if (phase > .72) {
        final r = (phase - .72) / .28 * 32;
        canvas.drawArc(
          Rect.fromCircle(center: head, radius: r),
          angle - .85,
          1.7,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(
              0x884f8fff,
            ).withValues(alpha: 1 - (phase - .72) / .28),
        );
      }
    }
  }

  Offset _bezier(Offset a, Offset b, Offset c, Offset d, double t) {
    final u = 1 - t;
    return Offset(
      u * u * u * a.dx +
          3 * u * u * t * b.dx +
          3 * u * t * t * c.dx +
          t * t * t * d.dx,
      u * u * u * a.dy +
          3 * u * u * t * b.dy +
          3 * u * t * t * c.dy +
          t * t * t * d.dy,
    );
  }

  double _h(int value) {
    final x = math.sin(value * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _TrainingAmbientPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.time != time;
}
