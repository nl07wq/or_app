import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Opt-in, Flutter-native reconstruction of the Aurora Glass V8 reference.
///
/// The field is built from a responsive grid of translucent rectangular glass
/// fragments. Time-varying partial arc bands decide which grid cells assemble,
/// shift, and dissolve; no media, image, platform-view, or texture is used.
class ActivityAmbientAuroraGlassCandidate extends StatelessWidget {
  const ActivityAmbientAuroraGlassCandidate({
    super.key,
    required this.animation,
    required this.reducedMotion,
  });

  static const fieldKey = ValueKey('activity-ambient-aurora-glass-candidate');
  static const gridColumns = 34;
  static const ribbonCount = 7;

  final Animation<double> animation;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: fieldKey,
    painter: _AuroraGlassPainter(
      animation: animation,
      staticFrame: reducedMotion,
    ),
    child: const SizedBox.expand(),
  );
}

@immutable
class _GlassRibbon {
  const _GlassRibbon({
    required this.center,
    required this.radius,
    required this.width,
    required this.startAngle,
    required this.arcLength,
    required this.speed,
    required this.cyanWeight,
    required this.magentaWeight,
  });

  final Offset center;
  final double radius;
  final double width;
  final double startAngle;
  final double arcLength;
  final double speed;
  final double cyanWeight;
  final double magentaWeight;
}

class _AuroraGlassPainter extends CustomPainter {
  _AuroraGlassPainter({required this.animation, required this.staticFrame})
    : super(repaint: animation);

  final Animation<double> animation;
  final bool staticFrame;

  static const _cyan = Color(0xFF56E2EA);
  static const _magenta = Color(0xFFE69AD8);

  // These are moving density bands, rather than independent particle orbits.
  // Their overlapping portions make the larger connected glass structures.
  static const _ribbons = <_GlassRibbon>[
    _GlassRibbon(
      center: Offset(.10, .18),
      radius: .31,
      width: .132,
      startAngle: -.25,
      arcLength: 3.08,
      speed: .22,
      cyanWeight: 1,
      magentaWeight: .08,
    ),
    _GlassRibbon(
      center: Offset(.72, .13),
      radius: .30,
      width: .124,
      startAngle: 1.82,
      arcLength: 3.16,
      speed: -.19,
      cyanWeight: .05,
      magentaWeight: 1,
    ),
    _GlassRibbon(
      center: Offset(.42, .43),
      radius: .34,
      width: .152,
      startAngle: -2.55,
      arcLength: 3.08,
      speed: .16,
      cyanWeight: .86,
      magentaWeight: .36,
    ),
    _GlassRibbon(
      center: Offset(.94, .47),
      radius: .36,
      width: .138,
      startAngle: 2.22,
      arcLength: 3.18,
      speed: -.14,
      cyanWeight: .12,
      magentaWeight: .95,
    ),
    _GlassRibbon(
      center: Offset(.20, .80),
      radius: .32,
      width: .144,
      startAngle: -.88,
      arcLength: 3.1,
      speed: .18,
      cyanWeight: .94,
      magentaWeight: .12,
    ),
    _GlassRibbon(
      center: Offset(.66, .83),
      radius: .35,
      width: .158,
      startAngle: -2.78,
      arcLength: 3.16,
      speed: -.17,
      cyanWeight: .25,
      magentaWeight: .88,
    ),
    _GlassRibbon(
      center: Offset(.52, .58),
      radius: .18,
      width: .17,
      startAngle: .32,
      arcLength: 3.7,
      speed: .11,
      cyanWeight: .62,
      magentaWeight: .62,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cell = size.width / ActivityAmbientAuroraGlassCandidate.gridColumns;
    final rows = (size.height / cell).ceil();
    final phase = staticFrame ? math.pi * .74 : animation.value * math.pi * 2;
    final glow = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, cell);
    final glass = Paint();
    final reflection = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (cell * .075).clamp(.35, 1.1);

    for (var row = 0; row < rows; row++) {
      for (
        var column = 0;
        column < ActivityAmbientAuroraGlassCandidate.gridColumns;
        column++
      ) {
        final position = Offset(
          (column + .5) / ActivityAmbientAuroraGlassCandidate.gridColumns,
          (row + .5) / rows,
        );
        final field = _fieldAt(position, size, phase, column, row);
        if (field.density < .105) continue;

        final flicker =
            .73 +
            .27 *
                math.sin(
                  phase * (field.layer + 1.2) + column * .81 + row * .47,
                );
        final intensity = (field.density * flicker).clamp(0.0, 1.0);
        if (intensity < .1) continue;

        final fragmentScale = (.42 + intensity * .48 + (field.layer % 3) * .045)
            .clamp(.38, .96);
        final fragmentSize = cell * fragmentScale;
        final center = Offset((column + .5) * cell, (row + .5) * cell);
        final rect = Rect.fromCenter(
          center: center,
          width: fragmentSize,
          height: fragmentSize,
        );
        final aurora = Color.lerp(
          _cyan,
          _magenta,
          field.magenta / (field.cyan + field.magenta),
        )!;
        final alpha = (.12 + intensity * .66).clamp(0.0, 1.0);

        glow.color = aurora.withValues(alpha: alpha * .13);
        glass.color = aurora.withValues(alpha: alpha);
        reflection.color = const Color(
          0xFFF1FCFF,
        ).withValues(alpha: alpha * (.13 + intensity * .17));
        edge.color = aurora.withValues(alpha: alpha * .62);

        canvas
          ..drawRect(rect.inflate(cell * .08), glow)
          ..drawRect(rect, glass)
          ..drawRect(
            Rect.fromLTWH(
              rect.left,
              rect.top,
              rect.width,
              rect.height * (.16 + .11 * intensity),
            ),
            reflection,
          )
          ..drawLine(
            Offset(rect.left, rect.bottom),
            Offset(rect.right, rect.top),
            edge,
          )
          ..drawRect(rect, edge);
      }
    }
  }

  _GlassField _fieldAt(
    Offset position,
    Size size,
    double phase,
    int column,
    int row,
  ) {
    var density = 0.0;
    var cyan = 0.0;
    var magenta = 0.0;
    var layer = 0;
    final aspect = size.height / size.width;
    for (var index = 0; index < _ribbons.length; index++) {
      final ribbon = _ribbons[index];
      final wobble = Offset(
        math.sin(phase * .71 + index * 1.7) * .026,
        math.cos(phase * .63 + index * 1.1) * .023,
      );
      final delta = position - ribbon.center - wobble;
      final x = delta.dx;
      final y = delta.dy * aspect;
      final radius = math.sqrt(x * x + y * y);
      final angle = math.atan2(y, x);
      final start = ribbon.startAngle + phase * ribbon.speed;
      final angularDistance = _angularDistance(
        angle,
        start + ribbon.arcLength / 2,
      );
      final arc = (1 - angularDistance / (ribbon.arcLength / 2)).clamp(
        0.0,
        1.0,
      );
      final radial = (1 - (radius - ribbon.radius).abs() / ribbon.width).clamp(
        0.0,
        1.0,
      );
      final structuralTexture =
          .62 +
          .38 *
              math.sin(column * .72 + row * .51 + phase * (1.3 + index * .07));
      final contribution = arc * radial * structuralTexture;
      density += contribution;
      cyan += contribution * ribbon.cyanWeight;
      magenta += contribution * ribbon.magentaWeight;
      if (contribution > .25) layer += index + 1;
    }
    return _GlassField(
      density: density.clamp(0.0, 1.0),
      cyan: cyan,
      magenta: magenta,
      layer: layer,
    );
  }

  double _angularDistance(double a, double b) {
    final raw = (a - b + math.pi) % (math.pi * 2) - math.pi;
    return raw.abs();
  }

  @override
  bool shouldRepaint(covariant _AuroraGlassPainter oldDelegate) =>
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.animation != animation;
}

@immutable
class _GlassField {
  const _GlassField({
    required this.density,
    required this.cyan,
    required this.magenta,
    required this.layer,
  });

  final double density;
  final double cyan;
  final double magenta;
  final int layer;
}
