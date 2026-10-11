import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Production Flutter-native reconstruction of the Aurora Glass V8 reference.
///
/// It ports the recovered V6 tile state, geometry, and RGB foundations, then
/// adds the V8-like frosted material and localized aurora restoration inferred
/// from the supplied V8 comparison videos. It has no media dependency.
class ActivityAmbientAuroraGlassCandidate extends StatelessWidget {
  const ActivityAmbientAuroraGlassCandidate({
    super.key,
    required this.animation,
    required this.reducedMotion,
  });

  static const fieldKey = ValueKey('activity-ambient-aurora-glass-candidate');
  static const gridColumns = 30;
  static const referenceFrameCount = 344;
  static const referenceFramesPerSecond = 30;

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

class _AuroraGlassPainter extends CustomPainter {
  _AuroraGlassPainter({required this.animation, required this.staticFrame})
    : super(repaint: animation);

  final Animation<double> animation;
  final bool staticFrame;

  static const _cyan = Color(0xFF56E2EA);
  static const _magenta = Color(0xFFE19AD2);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cell = size.width / ActivityAmbientAuroraGlassCandidate.gridColumns;
    final rows = (size.height / cell).ceil();
    final frame = staticFrame
        ? ActivityAmbientAuroraGlassCandidate.referenceFrameCount ~/ 3
        : (animation.value *
                  ActivityAmbientAuroraGlassCandidate.referenceFrameCount)
              .floor();
    final phase =
        math.pi *
        2 *
        frame /
        ActivityAmbientAuroraGlassCandidate.referenceFrameCount;
    final material = _GlassMaterial(cell);

    for (var row = 0; row < rows; row++) {
      for (
        var column = 0;
        column < ActivityAmbientAuroraGlassCandidate.gridColumns;
        column++
      ) {
        final intensity = _tileState(row, column, rows, phase);
        if (intensity < .10) continue;
        final geometry = _tileGeometry(row, column, cell, intensity);
        final color = _tileRgb(row, column, rows, phase);
        final edgeEnergy = _edgeEnergy(row, column, rows, phase, intensity);
        material.paint(
          canvas: canvas,
          rect: geometry,
          color: color,
          intensity: intensity,
          edgeEnergy: edgeEnergy,
        );
      }
    }
  }

  /// Recovered V6 tile_state() port: center-origin formation waves plus a
  /// diagonal assembly component. A deterministic, low-frequency spatial
  /// timing field breaks synchronized bands while retaining coherent clusters.
  /// The dynamic row count preserves the field across portrait and landscape
  /// viewports.
  double _tileState(int row, int column, int rows, double phase) {
    final centerX = (ActivityAmbientAuroraGlassCandidate.gridColumns - 1) / 2;
    final centerY = (rows - 1) / 2;
    // Grid-aligned Chebyshev distance creates an expanding square formation
    // front. The tile state still carries the same low-frequency variation,
    // so clusters reorganize organically instead of blinking in rigid bands.
    final squareDistance = math.max(
      (column - centerX).abs(),
      (row - centerY).abs(),
    );
    final timing = _spatialTimingVariation(row, column, rows);
    final localRate = 1 + timing * .075;
    final wave = math.sin(
      2 * phase * localRate - squareDistance * .37 + timing,
    );
    final active = ((wave - .06) * 2).clamp(0.0, 1.0);
    final diagonal =
        (math.sin(.37 * column + .22 * row - 2 * phase * localRate + timing) +
                .35)
            .clamp(0.0, 1.0);
    return active * (.40 + .60 * diagonal);
  }

  /// Recovered V6 tile_geometry() port, scaled from the 720px source grid.
  Rect _tileGeometry(int row, int column, double cell, double intensity) {
    final extent = (cell * (.167 + .75 * intensity)).clamp(cell * .167, cell);
    return Rect.fromCenter(
      center: Offset((column + .5) * cell, (row + .5) * cell),
      width: extent,
      height: extent,
    );
  }

  /// Recovered V6 tile_rgb() port, with V8's coherent cyan/magenta spatial
  /// restoration blended over the recovered changing RGB base.
  Color _tileRgb(int row, int column, int rows, double phase) {
    final hue =
        _unitNoise(row, column, 17) + .16 * math.sin(phase + column * .14);
    final recovered = Color.fromRGBO(
      ((.2 + .8 * math.max(0, math.sin(math.pi * 2 * hue))) * 255).round(),
      ((.30 + .65 * math.max(0, math.sin(math.pi * 2 * hue + 2.1))) * 255)
          .round(),
      ((.48 + .5 * math.max(0, math.sin(math.pi * 2 * hue + 4.2))) * 255)
          .round(),
      255,
    );
    final region =
        .5 +
        .5 * math.sin(column * .24 - row * .17 + phase * .68 + rows * .013);
    final aurora = Color.lerp(_cyan, _magenta, region)!;
    return Color.lerp(recovered, aurora, .86)!;
  }

  double _edgeEnergy(
    int row,
    int column,
    int rows,
    double phase,
    double intensity,
  ) {
    double neighbor(int r, int c) {
      if (r < 0 ||
          r >= rows ||
          c < 0 ||
          c >= ActivityAmbientAuroraGlassCandidate.gridColumns) {
        return 0;
      }
      return _tileState(r, c, rows, phase);
    }

    final laplacian =
        4 * intensity -
        neighbor(row - 1, column) -
        neighbor(row + 1, column) -
        neighbor(row, column - 1) -
        neighbor(row, column + 1);
    return laplacian.abs().clamp(0.0, 1.0);
  }

  /// Smoothly correlated timing variation: nearby tiles share timing and
  /// lifecycle changes, while distant groups assemble and dissolve at subtly
  /// different moments. This stays deterministic and never flickers.
  double _spatialTimingVariation(int row, int column, int rows) {
    final x = column / ActivityAmbientAuroraGlassCandidate.gridColumns;
    final y = row / rows;
    return .44 * math.sin(x * math.pi * 2.1 + y * math.pi * .72 + .34) +
        .27 * math.sin(x * math.pi * .78 - y * math.pi * 2.45 + 1.18) +
        .16 * math.cos(x * math.pi * 3.15 + y * math.pi * 1.36 - .62);
  }

  double _unitNoise(int row, int column, int salt) {
    var value = row * 73856093 ^ column * 19349663 ^ salt * 83492791;
    value ^= value >> 13;
    value *= 1274126177;
    return (value & 0x7fffffff) / 0x7fffffff;
  }

  @override
  bool shouldRepaint(covariant _AuroraGlassPainter oldDelegate) =>
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.animation != animation;
}

class _GlassMaterial {
  _GlassMaterial(double cell)
    : _nearHalo = Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * .125),
      _middleHalo = Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * .35),
      _outerHalo = Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * .83),
      _fill = Paint(),
      _frost = Paint(),
      _edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (cell * .045).clamp(.35, 1.05),
      _reflection = Paint(),
      _glint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (cell * .055).clamp(.4, 1.2);

  final Paint _nearHalo;
  final Paint _middleHalo;
  final Paint _outerHalo;
  final Paint _fill;
  final Paint _frost;
  final Paint _edge;
  final Paint _reflection;
  final Paint _glint;

  void paint({
    required Canvas canvas,
    required Rect rect,
    required Color color,
    required double intensity,
    required double edgeEnergy,
  }) {
    final alpha = (.06 + intensity * .39).clamp(0.0, 1.0);
    _outerHalo.color = color.withValues(alpha: alpha * .008);
    _middleHalo.color = color.withValues(alpha: alpha * .018);
    _nearHalo.color = color.withValues(alpha: alpha * .042);
    _fill.color = color.withValues(alpha: alpha);
    _frost.color = const Color(
      0xFFDDF7FA,
    ).withValues(alpha: alpha * (.08 + intensity * .10));
    _edge.color = color.withValues(alpha: alpha * (.17 + edgeEnergy * .42));

    if (intensity > .78) {
      canvas
        ..drawRect(rect.inflate(rect.width * .13), _outerHalo)
        ..drawRect(rect.inflate(rect.width * .08), _middleHalo);
    }
    if (intensity > .48) {
      canvas.drawRect(rect.inflate(rect.width * .035), _nearHalo);
    }
    canvas
      ..drawRect(rect, _fill)
      ..drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * .56),
        _frost,
      )
      ..drawRect(rect, _edge);

    if (intensity > .67) {
      _reflection.color = const Color(
        0xFFF4FEFF,
      ).withValues(alpha: alpha * .24);
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * .16),
        _reflection,
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width * .12, rect.height),
        _reflection,
      );
    }
    if (intensity > .48) {
      _glint.color = Colors.white.withValues(
        alpha: alpha * (.16 + edgeEnergy * .34),
      );
      canvas.drawLine(rect.topLeft, rect.topRight, _glint);
    }
  }
}
