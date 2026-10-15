import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Temporary, self-contained candidate host for the FOOD ambient comparison.
/// Keeping the candidates here makes it straightforward to retain one and
/// remove the comparison surface after device review.
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

  @override
  State<FoodAmbientComparison> createState() => _FoodAmbientComparisonState();
}

class _FoodAmbientComparisonState extends State<FoodAmbientComparison>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
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
            painter: _FoodAmbientPainter(
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
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'FOOD ambient comparison',
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
              for (final variant in FoodAmbientVariant.values)
                ChoiceChip(
                  key: ValueKey('food-ambient-${variant.name}'),
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

class _FoodAmbientPainter extends CustomPainter {
  const _FoodAmbientPainter({required this.variant, required this.time});

  final FoodAmbientVariant variant;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    switch (variant) {
      case FoodAmbientVariant.chromaticFluid:
        _paintChromaticFluid(canvas, size);
      case FoodAmbientVariant.metabolicCells:
        _paintMetabolicCells(canvas, size);
      case FoodAmbientVariant.thermalCurrent:
        _paintThermalCurrent(canvas, size);
    }
  }

  void _paintChromaticFluid(Canvas canvas, Size size) {
    const colors = [
      Color(0xFF00C8C8),
      Color(0xFF4E78FF),
      Color(0xFFE65CAB),
      Color(0xFFFFA85B),
    ];
    for (var i = 0; i < colors.length; i++) {
      final phase = time * (.22 + i * .035) + i * 1.7;
      final center = Offset(
        size.width * (.5 + .38 * math.sin(phase)),
        size.height * (.5 + .34 * math.cos(phase * .78 + i)),
      );
      final radius = size.shortestSide * (.32 + .07 * math.sin(phase * .6));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i].withValues(alpha: .15),
            colors[i].withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _paintMetabolicCells(Canvas canvas, Size size) {
    const palette = [Color(0xFF55D5C0), Color(0xFF74A4FF), Color(0xFFD184C7)];
    final columns = math.max(4, (size.width / 96).floor());
    final rows = math.max(7, (size.height / 92).floor());
    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final seed = _noise(column, row);
        final phase = time * (.34 + seed * .15) + seed * math.pi * 2;
        final pulse = .68 + .32 * math.sin(phase);
        final center = Offset(
          (column + .5 + .12 * math.sin(phase * .7)) * cellWidth,
          (row + .5 + .10 * math.cos(phase * .8)) * cellHeight,
        );
        final radius = (cellWidth + cellHeight) * (.18 + seed * .12) * pulse;
        final color = palette[(seed * palette.length).floor() % palette.length];
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: .035 + .045 * pulse);
        canvas.drawCircle(center, radius, paint);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = color.withValues(alpha: .10 + .06 * pulse),
        );
      }
    }
  }

  void _paintThermalCurrent(Canvas canvas, Size size) {
    const warm = [Color(0xFFFF9A5A), Color(0xFFFFC85C), Color(0xFFF36A76)];
    for (var i = 0; i < 12; i++) {
      final seed = _noise(i, 4);
      final x =
          (i + .45 + .18 * math.sin(time * .32 + seed * 9)) / 12 * size.width;
      final travel = (time * (.025 + seed * .018) + seed) % 1;
      final start = Offset(x, size.height * (1.05 - travel * .95));
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + 24 * math.sin(time + seed * 8),
          start.dy - size.height * .12,
          start.dx - 28 * math.cos(time * .6 + seed * 7),
          start.dy - size.height * .27,
          start.dx + 10 * math.sin(time * .9 + seed * 3),
          start.dy - size.height * .42,
        );
      final color = warm[i % warm.length];
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.2 + seed * 1.8
          ..color = color.withValues(alpha: .10 + .08 * (1 - travel)),
      );
      canvas.drawCircle(
        start.translate(0, -size.height * .18),
        1.5 + seed * 2,
        Paint()..color = color.withValues(alpha: .12),
      );
    }
  }

  double _noise(int a, int b) =>
      ((math.sin(a * 12.9898 + b * 78.233) * 43758.5453) % 1).abs();

  @override
  bool shouldRepaint(covariant _FoodAmbientPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.time != time;
}
