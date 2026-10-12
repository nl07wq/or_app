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
  // The verified V8 frames contain many independently assembling small
  // fragment constellations, rather than a handful of large radial blobs.
  // These deterministic events move through a repeating timeline so the
  // control field remains continuous at the reference-loop boundary.
  static const _activationEventCount = 37;
  static const _activationEpochCount = 7;

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

  /// V8-informed local formation events create actual tile assembly and
  /// dissolution. Each event receives a new seeded location for every epoch,
  /// then moves smoothly to the next location. This keeps local coherence
  /// while removing the fixed, center-radial origin directions that produced
  /// the previous vertical and diagonal bands.
  double _tileState(int row, int column, int rows, double phase) {
    final point = Offset(
      (column + .5) / ActivityAmbientAuroraGlassCandidate.gridColumns,
      (row + .5) / rows,
    );
    var intensity = 0.0;

    for (var event = 0; event < _activationEventCount; event++) {
      final signal = _eventSignal(event, phase);
      if (signal <= 0) continue;

      final position = _eventPosition(event, phase);
      final orientation = _eventOrientation(event, phase);
      final dx = point.dx - position.dx;
      // The verified reference is square, while Activity uses a portrait
      // full viewport. Measure both axes in grid-cell units so a compact V8
      // cluster remains compact instead of becoming a vertical band.
      final dy =
          (point.dy - position.dy) *
          rows /
          ActivityAmbientAuroraGlassCandidate.gridColumns;
      final longitudinal =
          dx * math.cos(orientation) + dy * math.sin(orientation);
      final lateral = -dx * math.sin(orientation) + dy * math.cos(orientation);
      // Broad, short curved fields assemble into V8-like fragment masses.
      // They deliberately avoid the thin, one-cell tracks made by the old
      // origin discs and retain dark negative space between formations.
      final length = .060 + _eventNoise(event, 11) * .100;
      final width = .065 + _eventNoise(event, 12) * .070;
      final bend = (_eventNoise(event, 13) - .5) * 1.25;
      final curvedLateral =
          lateral - bend * longitudinal * longitudinal / length;
      final local =
          1 -
          _smoothStep(
            .38,
            1,
            math.sqrt(
              longitudinal * longitudinal / (length * length) +
                  curvedLateral * curvedLateral / (width * width),
            ),
          );
      final fragment = _smoothStep(
        .30,
        .82,
        local + (_unitNoise(row, column, event + 71) - .5) * .72,
      );
      intensity = math.max(intensity, signal * local * fragment).toDouble();
    }

    return intensity.clamp(0.0, 1.0).toDouble();
  }

  Offset _eventPosition(int event, double phase) {
    final epochProgress = phase / (math.pi * 2) * _activationEpochCount;
    final epoch = epochProgress.floor();
    final blend = _smoothStep(0, 1, epochProgress - epoch);
    return Offset.lerp(
      _eventAnchor(event, epoch),
      _eventAnchor(event, (epoch + 1) % _activationEpochCount),
      blend,
    )!;
  }

  Offset _eventAnchor(int event, int epoch) {
    final direction = _eventNoise(event, epoch * 17 + 1) * math.pi * 2;
    // A square-root distribution maintains V8's sparse peripheral fragments
    // without imposing a circular front or a protected central void.
    final radius = .03 + math.sqrt(_eventNoise(event, epoch * 17 + 2)) * .67;
    return Offset(
      (.5 + math.cos(direction) * radius).clamp(.03, .97).toDouble(),
      (.5 + math.sin(direction) * radius).clamp(.03, .97).toDouble(),
    );
  }

  double _eventOrientation(int event, double phase) {
    final epochProgress = phase / (math.pi * 2) * _activationEpochCount;
    final epoch = epochProgress.floor();
    final blend = _smoothStep(0, 1, epochProgress - epoch);
    final start = _eventNoise(event, epoch * 17 + 3) * math.pi * 2;
    final end =
        _eventNoise(event, ((epoch + 1) % _activationEpochCount) * 17 + 3) *
        math.pi *
        2;
    return start +
        math.atan2(math.sin(end - start), math.cos(end - start)) * blend;
  }

  double _eventSignal(int event, double phase) {
    final speed = 1 + (event % 4);
    final offset = _eventNoise(event, 7) * math.pi * 2;
    final cycle = .5 + .5 * math.sin(phase * speed + offset);
    final forming = _smoothStep(.23, .53, cycle);
    final dissolving = 1 - _smoothStep(.60, .90, cycle);
    return forming * dissolving;
  }

  double _smoothStep(double lower, double upper, double value) {
    final t = ((value - lower) / (upper - lower)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
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

  double _eventNoise(int event, int salt) {
    var value = event * 73856093 ^ salt * 19349663 ^ 51 * 83492791;
    value ^= value >> 13;
    value *= 1274126177;
    return (value & 0x7fffffff) / 0x7fffffff;
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
