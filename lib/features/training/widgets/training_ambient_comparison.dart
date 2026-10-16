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

  /// External gears use the tooth-count ratio and turn in opposite directions.
  /// Kept public so the mechanical relationship is regression-tested without
  /// coupling a test to painter pixels.
  static double meshedAngularVelocity({
    required double driveVelocity,
    required int driveTeeth,
    required int drivenTeeth,
  }) => -driveVelocity * driveTeeth / drivenTeeth;

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
    const polarities = [1.0, -1.0, .72];
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 36; i++) {
      final source =
          centers[i % centers.length] +
          Offset.fromDirection(
            i * math.pi * 2 / 12 + time * (.025 + (i % 3) * .006),
            12 + (i % 6) * 4,
          );
      final points = _integrateField(
        source,
        centers,
        polarities,
        size,
        i.isEven ? 1 : -1,
      );
      if (points.length < 3) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      final middle = points[points.length ~/ 2];
      final concentration = _fieldAt(middle, centers, polarities).distance;
      final intensity = (concentration / 20).clamp(.18, 1.0);
      stroke
        ..color = Color.lerp(
          const Color(0x334be9ff),
          const Color(0x775c5cff),
          (i % 18) / 18,
        )!
        ..color = stroke.color.withValues(alpha: .18 + intensity * .42)
        ..strokeWidth = i % 6 == 0 ? 1.55 : .52 + intensity * .48;
      canvas.drawPath(path, stroke);
      if (i % 3 == 0) {
        final u = (time * (.12 + (i % 5) * .012) + i * .09) % 1;
        final pointIndex = (u * (points.length - 1)).floor();
        final point = points[pointIndex];
        final next = points[math.min(pointIndex + 1, points.length - 1)];
        final tangent = next - point;
        canvas.drawLine(
          point - tangent * .8,
          point + tangent * .8,
          Paint()
            ..strokeWidth = 1.1
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xaa8cf5ff),
        );
        canvas.drawCircle(
          point,
          2.2,
          Paint()
            ..color = const Color(0xff8cf5ff)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
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
    final unit = size.shortestSide;
    final drive = _Gear(
      center: Offset(size.width * .48, size.height * .55),
      radius: unit * .185,
      teeth: 28,
    );
    final upper = _Gear(
      center:
          drive.center + Offset.fromDirection(-.54, drive.radius + unit * .127),
      radius: unit * .127,
      teeth: 20,
    );
    final lower = _Gear(
      center:
          drive.center + Offset.fromDirection(2.18, drive.radius + unit * .102),
      radius: unit * .102,
      teeth: 16,
    );
    final transfer = _Gear(
      center:
          upper.center + Offset.fromDirection(.22, upper.radius + unit * .075),
      radius: unit * .075,
      teeth: 12,
    );
    final output = _Gear(
      center:
          lower.center + Offset.fromDirection(2.68, lower.radius + unit * .088),
      radius: unit * .088,
      teeth: 14,
    );
    final gears = [drive, upper, lower, transfer, output];
    final driveVelocity = .72 + .11 * math.sin(time * .17);
    final velocities = [
      driveVelocity,
      TrainingAmbientComparison.meshedAngularVelocity(
        driveVelocity: driveVelocity,
        driveTeeth: drive.teeth,
        drivenTeeth: upper.teeth,
      ),
      TrainingAmbientComparison.meshedAngularVelocity(
        driveVelocity: driveVelocity,
        driveTeeth: drive.teeth,
        drivenTeeth: lower.teeth,
      ),
      TrainingAmbientComparison.meshedAngularVelocity(
        driveVelocity: TrainingAmbientComparison.meshedAngularVelocity(
          driveVelocity: driveVelocity,
          driveTeeth: drive.teeth,
          drivenTeeth: upper.teeth,
        ),
        driveTeeth: upper.teeth,
        drivenTeeth: transfer.teeth,
      ),
      TrainingAmbientComparison.meshedAngularVelocity(
        driveVelocity: TrainingAmbientComparison.meshedAngularVelocity(
          driveVelocity: driveVelocity,
          driveTeeth: drive.teeth,
          drivenTeeth: lower.teeth,
        ),
        driveTeeth: lower.teeth,
        drivenTeeth: output.teeth,
      ),
    ];
    // Rear frame and genuine shafts sit behind all rotating parts.
    final frame = Paint()..color = const Color(0xff091421);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: drive.center,
          width: unit * .82,
          height: unit * .62,
        ),
        Radius.circular(unit * .06),
      ),
      frame,
    );
    final links = [
      (drive, upper),
      (drive, lower),
      (upper, transfer),
      (lower, output),
    ];
    for (final link in links) {
      canvas.drawLine(
        link.$1.center,
        link.$2.center,
        Paint()
          ..strokeWidth = unit * .035
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xff27394a),
      );
      canvas.drawLine(
        link.$1.center,
        link.$2.center,
        Paint()
          ..strokeWidth = unit * .010
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x886de4ff),
      );
    }
    for (var i = 0; i < gears.length; i++) {
      _gear(canvas, gears[i], time * velocities[i], i);
    }
    // The final shaft drives a constrained slider through a real crank radius.
    final outputAngle = time * velocities[4];
    final crankPin =
        output.center + Offset.fromDirection(outputAngle, output.radius * .56);
    final sliderY = output.center.dy + output.radius * 1.72;
    final sliderX =
        output.center.dx + math.cos(outputAngle) * output.radius * .56;
    final slider = Offset(sliderX, sliderY);
    canvas.drawLine(
      crankPin,
      slider,
      Paint()
        ..strokeWidth = unit * .018
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff8cb8ca),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: slider, width: unit * .13, height: unit * .055),
        Radius.circular(unit * .014),
      ),
      Paint()..color = const Color(0xff314d60),
    );
    canvas.drawCircle(
      crankPin,
      unit * .012,
      Paint()..color = const Color(0xffffbd70),
    );
  }

  void _gear(Canvas canvas, _Gear gear, double angle, int index) {
    final toothDepth = gear.radius * .13;
    final profile = Path();
    for (var tooth = 0; tooth < gear.teeth; tooth++) {
      final base = angle + tooth * math.pi * 2 / gear.teeth;
      for (final (fraction, radius) in [
        (-.48, gear.radius),
        (-.29, gear.radius + toothDepth),
        (.29, gear.radius + toothDepth),
        (.48, gear.radius),
      ]) {
        final point =
            gear.center +
            Offset.fromDirection(
              base + fraction * math.pi * 2 / gear.teeth,
              radius,
            );
        if (tooth == 0 && fraction == -.48) {
          profile.moveTo(point.dx, point.dy);
        } else {
          profile.lineTo(point.dx, point.dy);
        }
      }
    }
    profile.close();
    canvas.drawPath(profile, Paint()..color = const Color(0xff2c4253));
    canvas.drawPath(
      profile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xff7acdf0).withValues(alpha: .62),
    );
    canvas.drawCircle(
      gear.center,
      gear.radius * .72,
      Paint()..color = const Color(0xff162634),
    );
    canvas.drawCircle(
      gear.center,
      gear.radius * .61,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = gear.radius * .07
        ..color = const Color(0xff46687e),
    );
    for (var spoke = 0; spoke < 6; spoke++) {
      final a = angle + spoke * math.pi / 3;
      canvas.drawLine(
        gear.center + Offset.fromDirection(a, gear.radius * .18),
        gear.center + Offset.fromDirection(a, gear.radius * .58),
        Paint()
          ..strokeWidth = gear.radius * .07
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xff38566a),
      );
    }
    canvas.drawCircle(
      gear.center,
      gear.radius * .22,
      Paint()
        ..color = const Color(0xff68dfff)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      gear.center,
      gear.radius * .12,
      Paint()..color = const Color(0xffffbe74),
    );
    canvas.drawArc(
      Rect.fromCircle(center: gear.center, radius: gear.radius * .82),
      angle + index,
      math.pi * .36,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = gear.radius * .035
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xffc1f8ff).withValues(alpha: .62),
    );
  }

  List<Offset> _integrateField(
    Offset start,
    List<Offset> centers,
    List<double> polarities,
    Size size,
    int direction,
  ) {
    final points = <Offset>[start];
    var point = start;
    for (var step = 0; step < 58; step++) {
      final vector = _fieldAt(point, centers, polarities);
      if (vector.distance < .0001) {
        break;
      }
      point += vector / vector.distance * direction.toDouble() * 7;
      if (point.dx < -30 ||
          point.dx > size.width + 30 ||
          point.dy < -30 ||
          point.dy > size.height + 30) {
        break;
      }
      points.add(point);
    }
    return points;
  }

  Offset _fieldAt(Offset point, List<Offset> centers, List<double> polarities) {
    var vector = Offset.zero;
    for (var i = 0; i < centers.length; i++) {
      final delta = point - centers[i];
      final squared = math.max(180.0, delta.distanceSquared);
      vector +=
          delta / math.pow(squared, 1.35).toDouble() * polarities[i] * 26000;
    }
    return vector;
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

  double _h(int value) {
    final x = math.sin(value * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _TrainingAmbientPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.time != time;
}

class _Gear {
  const _Gear({
    required this.center,
    required this.radius,
    required this.teeth,
  });

  final Offset center;
  final double radius;
  final int teeth;
}
