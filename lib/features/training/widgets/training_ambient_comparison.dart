import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Isolated candidate renderers for the temporary TRAINING ambient comparison.
enum TrainingAmbientVariant {
  magneticFlux('MAGNETIC FLUX'),
  kineticEngine('KINETIC ENGINE'),
  vectorImpulse('VECTOR IMPULSE');

  const TrainingAmbientVariant(this.label);

  final String label;
}

class TrainingAmbientComparison extends StatefulWidget {
  const TrainingAmbientComparison({required this.variant, super.key});

  final TrainingAmbientVariant variant;

  @override
  State<TrainingAmbientComparison> createState() =>
      _TrainingAmbientComparisonState();
}

class _TrainingAmbientComparisonState extends State<TrainingAmbientComparison>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _TrainingAmbientPainter(
              variant: widget.variant,
              time: _controller.value * math.pi * 2,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class TrainingAmbientComparisonSelector extends StatelessWidget {
  const TrainingAmbientComparisonSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final TrainingAmbientVariant selected;
  final ValueChanged<TrainingAmbientVariant> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'TRAINING ambient comparison',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline.withValues(alpha: .35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final variant in TrainingAmbientVariant.values)
                ChoiceChip(
                  key: ValueKey('training-ambient-${variant.name}'),
                  label: Text(variant.label),
                  selected: selected == variant,
                  onSelected: (_) => onChanged(variant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingAmbientPainter extends CustomPainter {
  const _TrainingAmbientPainter({required this.variant, required this.time});

  final TrainingAmbientVariant variant;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    switch (variant) {
      case TrainingAmbientVariant.magneticFlux:
        _paintMagneticFlux(canvas, size);
      case TrainingAmbientVariant.kineticEngine:
        _paintKineticEngine(canvas, size);
      case TrainingAmbientVariant.vectorImpulse:
        _paintVectorImpulse(canvas, size);
    }
  }

  void _paintMagneticFlux(Canvas canvas, Size size) {
    final center = Offset(size.width * .52, size.height * .42);
    final maximum = size.longestSide * .72;
    for (var i = 0; i < 11; i++) {
      final phase = time * (.30 + i * .012) + i * .58;
      final radius = 30 + i * maximum / 14;
      final path = Path();
      for (var step = 0; step <= 32; step++) {
        final theta = step / 32 * math.pi * 2;
        final warp =
            15 * math.sin(theta * 3 + phase) +
            8 * math.sin(theta * 6 - phase * .7);
        final point = Offset(
          center.dx + (radius + warp) * math.cos(theta),
          center.dy + (radius * .62 + warp * .4) * math.sin(theta),
        );
        if (step == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i.isEven ? 1.15 : .75
          ..color = Color.lerp(
            const Color(0xFF49DBFF),
            const Color(0xFF8B70FF),
            i / 11,
          )!.withValues(alpha: .055 + (i % 3) * .018),
      );
    }
  }

  void _paintKineticEngine(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .40);
    final base = size.shortestSide * .22;
    for (var layer = 0; layer < 4; layer++) {
      final radius = base + layer * 34;
      final rotation = time * (layer.isEven ? .24 : -.18) * (layer + 1);
      final color = layer.isEven
          ? const Color(0xFF53D7F4)
          : const Color(0xFF9A83FF);
      for (var segment = 0; segment < 7 + layer; segment++) {
        final start = rotation + segment / (7 + layer) * math.pi * 2;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          .28 + .08 * math.sin(time + segment),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.square
            ..strokeWidth = 1.2 + layer * .25
            ..color = color.withValues(alpha: .09 + layer * .016),
        );
      }
    }
  }

  void _paintVectorImpulse(Canvas canvas, Size size) {
    const colors = [Color(0xFF46D8F3), Color(0xFF8576FF), Color(0xFFEE6EA9)];
    for (var i = 0; i < 24; i++) {
      final seed = _noise(i, 2);
      final progress = (time * (.11 + seed * .07) + seed) % 1;
      final angle = seed * math.pi * 2 + .22 * math.sin(time * .7 + i);
      final origin = Offset(size.width * .5, size.height * .42);
      final distance = progress * size.longestSide * .60;
      final tail = origin + Offset(math.cos(angle), math.sin(angle)) * distance;
      final length = 14 + seed * 34;
      final head = tail + Offset(math.cos(angle), math.sin(angle)) * length;
      final color = colors[i % colors.length].withValues(
        alpha: .06 + .09 * (1 - progress),
      );
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.0 + seed * 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, head, paint);
      final normal = Offset(math.cos(angle + 2.55), math.sin(angle + 2.55)) * 5;
      canvas.drawLine(head, head + normal, paint);
      canvas.drawLine(head, head + Offset(-normal.dy, normal.dx), paint);
    }
  }

  double _noise(int a, int b) =>
      ((math.sin(a * 12.9898 + b * 78.233) * 43758.5453) % 1).abs();

  @override
  bool shouldRepaint(covariant _TrainingAmbientPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.time != time;
}
