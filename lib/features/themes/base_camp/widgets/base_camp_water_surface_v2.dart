import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../base_camp_map_configuration.dart';

const baseCampWaterReflectionStep = Duration(milliseconds: 67);
const baseCampWaterArcStep = Duration(milliseconds: 34);
const baseCampWaterReflectionGridStep = 4.0;
const baseCampWaterReflectionLargeWavelength = 72.0;
const baseCampWaterReflectionSmallWavelength = 28.0;
const baseCampWaterReflectionLargePeriodSeconds = 7.0;
const baseCampWaterReflectionSmallPeriodSeconds = 5.5;
const baseCampWaterReflectionDisplacementMapPixels = 4.0;
const baseCampWaterArcDensityPerTenThousandPixels = 1.2;
const baseCampWaterArcMaximumCount = 80;

/// WATER V2 presentation layer. The two painters have independent throttled
/// clocks and repaint boundaries, so the 30fps fragments never force the
/// 15fps reflection mesh (or unrelated map content) to repaint.
class BaseCampWaterSurfaceV2Layer extends StatefulWidget {
  const BaseCampWaterSurfaceV2Layer({
    super.key,
    required this.water,
    required this.imageRect,
    required this.artworkSize,
    required this.reflectionTick,
    required this.arcTick,
  });

  final BaseCampWaterFx water;
  final Rect imageRect;
  final Size artworkSize;
  final ValueListenable<int> reflectionTick;
  final ValueListenable<int> arcTick;

  @override
  State<BaseCampWaterSurfaceV2Layer> createState() =>
      _BaseCampWaterSurfaceV2LayerState();
}

class _BaseCampWaterSurfaceV2LayerState
    extends State<BaseCampWaterSurfaceV2Layer> {
  late BaseCampWaterV2Scene _scene;

  @override
  void initState() {
    super.initState();
    _scene = BaseCampWaterV2Scene.create(
      water: widget.water,
      artworkSize: widget.artworkSize,
    );
  }

  @override
  void didUpdateWidget(BaseCampWaterSurfaceV2Layer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.water != widget.water ||
        oldWidget.artworkSize != widget.artworkSize) {
      _scene = BaseCampWaterV2Scene.create(
        water: widget.water,
        artworkSize: widget.artworkSize,
      );
    }
  }

  @override
  Widget build(BuildContext context) => ClipPath(
    key: const ValueKey('base-camp-water-mask-clip'),
    clipper: BaseCampWaterV2MaskClipper(
      water: widget.water,
      imageRect: widget.imageRect,
      artworkSize: widget.artworkSize,
    ),
    clipBehavior: Clip.hardEdge,
    child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          key: const ValueKey('base-camp-water-surface-reflection'),
          child: CustomPaint(
            painter: _SurfaceReflectionPainter(
              scene: _scene,
              imageRect: widget.imageRect,
              artworkSize: widget.artworkSize,
              tick: widget.reflectionTick,
            ),
          ),
        ),
        RepaintBoundary(
          key: const ValueKey('base-camp-water-arc-fragments'),
          child: CustomPaint(
            painter: _ArcFragmentPainter(
              scene: _scene,
              imageRect: widget.imageRect,
              artworkSize: widget.artworkSize,
              tick: widget.arcTick,
            ),
          ),
        ),
      ],
    ),
  );
}

class BaseCampWaterV2MaskClipper extends CustomClipper<Path> {
  const BaseCampWaterV2MaskClipper({
    required this.water,
    required this.imageRect,
    required this.artworkSize,
  });

  final BaseCampWaterFx water;
  final Rect imageRect;
  final Size artworkSize;

  Offset _toViewport(Offset point) => Offset(
    imageRect.left + point.dx * imageRect.width / artworkSize.width,
    imageRect.top + point.dy * imageRect.height / artworkSize.height,
  );

  @override
  Path getClip(Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final area in water.effectiveAreas) {
      if (area.mask.length < 3) continue;
      path.addPolygon(area.mask.map(_toViewport).toList(growable: false), true);
      for (final exclusion in area.exclusionMasks) {
        if (exclusion.length < 3) continue;
        path.addPolygon(
          exclusion.map(_toViewport).toList(growable: false),
          true,
        );
      }
    }
    return path;
  }

  @override
  bool shouldReclip(BaseCampWaterV2MaskClipper oldClipper) =>
      oldClipper.water != water ||
      oldClipper.imageRect != imageRect ||
      oldClipper.artworkSize != artworkSize;
}

/// Immutable deterministic scene data. Random values are generated only when
/// the WATER configuration changes, never during an animation frame.
@immutable
class BaseCampWaterV2Scene {
  const BaseCampWaterV2Scene._({
    required this.water,
    required this.artworkSize,
    required this.validSurfaceArea,
    required this._validWaterPath,
    required this._fragments,
  });

  factory BaseCampWaterV2Scene.create({
    required BaseCampWaterFx water,
    required Size artworkSize,
  }) {
    final validArea = _validWaterArea(water);
    final count =
        (validArea / 10000 * baseCampWaterArcDensityPerTenThousandPixels)
            .round()
            .clamp(validArea > 0 ? 1 : 0, baseCampWaterArcMaximumCount);
    final random = _DeterministicRandom(0x57415432);
    final bounds = _waterBounds(water, artworkSize);
    final validWaterPath = _waterPath(water);
    final fragments = <_ArcFragment>[];
    for (var index = 0; index < count; index++) {
      final duration = 4 + random.nextDouble() * 4;
      final states = <_ArcState>[];
      for (var generation = 0; generation < 12; generation++) {
        states.add(
          _ArcState(
            center: _nextValidPoint(random, water, validWaterPath, bounds),
            radiusX: 5 + random.nextDouble() * 9,
            radiusY: 2 + random.nextDouble() * 4,
            startAngle: random.nextDouble() * math.pi * 2,
            sweepAngle: _radians(60 + random.nextDouble() * 90),
            // Leave three degrees of headroom for lifecycle fluctuation while
            // keeping the final rendered rotation inside the approved range.
            rotation: _radians(-32 + random.nextDouble() * 64),
            strokeWidth: 1.5 + random.nextDouble() * 1.5,
            maximumAlpha: .08 + random.nextDouble() * .17,
            curvaturePhase: random.nextDouble() * math.pi * 2,
            movementPhaseX: random.nextDouble() * math.pi * 2,
            movementPhaseY: random.nextDouble() * math.pi * 2,
          ),
        );
      }
      fragments.add(
        _ArcFragment(
          lifecycleSeconds: duration,
          phaseOffsetSeconds: random.nextDouble() * duration,
          states: states,
        ),
      );
    }
    return BaseCampWaterV2Scene._(
      water: water,
      artworkSize: artworkSize,
      validSurfaceArea: validArea,
      validWaterPath: validWaterPath,
      fragments: fragments,
    );
  }

  final BaseCampWaterFx water;
  final Size artworkSize;
  final double validSurfaceArea;
  final Path _validWaterPath;
  final List<_ArcFragment> _fragments;

  int get fragmentCount => _fragments.length;

  bool containsWaterPoint(Offset point) => _validWaterPath.contains(point);

  double sampleReflection(Offset artworkPoint, Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final largePhase =
        seconds / baseCampWaterReflectionLargePeriodSeconds * math.pi * 2;
    final smallPhase =
        seconds / baseCampWaterReflectionSmallPeriodSeconds * math.pi * 2;
    final rawDisplacement = Offset(
      _gradientNoise2(
        artworkPoint.dx / 180 + math.cos(largePhase) * .55,
        artworkPoint.dy / 180 + math.sin(largePhase) * .55,
        0x4217,
      ),
      _gradientNoise2(
        artworkPoint.dx / 150 + math.cos(smallPhase) * .55,
        artworkPoint.dy / 150 + math.sin(smallPhase) * .55,
        0x7391,
      ),
    );
    final displacement = rawDisplacement.distance > 1
        ? rawDisplacement /
              rawDisplacement.distance *
              baseCampWaterReflectionDisplacementMapPixels
        : rawDisplacement * baseCampWaterReflectionDisplacementMapPixels;
    final displaced = artworkPoint + displacement;
    final large = _gradientNoise2(
      displaced.dx / baseCampWaterReflectionLargeWavelength,
      displaced.dy / baseCampWaterReflectionLargeWavelength,
      0x2a13,
    );
    final small = _gradientNoise2(
      displaced.dx / baseCampWaterReflectionSmallWavelength,
      displaced.dy / baseCampWaterReflectionSmallWavelength,
      0x6b31,
    );
    return (.65 * large + .35 * small).clamp(-1.0, 1.0);
  }

  BaseCampWaterArcSample arcSample(int index, Duration elapsed) {
    final fragment = _fragments[index];
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final absolute =
        (seconds + fragment.phaseOffsetSeconds) / fragment.lifecycleSeconds;
    final generation = absolute.floor();
    final progress = absolute - generation;
    final state = fragment.states[generation % fragment.states.length];
    final envelope = _lifecycleEnvelope(progress);
    final fluctuation = math.sin(progress * math.pi * 2 + state.curvaturePhase);
    final rawMovement = Offset(
      math.sin(progress * math.pi * 2 + state.movementPhaseX) * 2,
      math.cos(progress * math.pi * 2 + state.movementPhaseY) * 2,
    );
    final movement = rawMovement.distance > 2
        ? rawMovement / rawMovement.distance * 2
        : rawMovement;
    return BaseCampWaterArcSample(
      center: state.center + movement,
      radiusX: state.radiusX * (1 + fluctuation * .06),
      radiusY: state.radiusY * (1 + fluctuation * .10),
      startAngle: state.startAngle,
      sweepAngle: state.sweepAngle,
      rotation: state.rotation + _radians(fluctuation * 3),
      strokeWidth: state.strokeWidth,
      alpha: state.maximumAlpha * envelope,
      lifecycleProgress: progress,
      perceptiblyVisible: envelope >= .8,
    );
  }
}

@immutable
class BaseCampWaterArcSample {
  const BaseCampWaterArcSample({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.startAngle,
    required this.sweepAngle,
    required this.rotation,
    required this.strokeWidth,
    required this.alpha,
    required this.lifecycleProgress,
    required this.perceptiblyVisible,
  });

  final Offset center;
  final double radiusX;
  final double radiusY;
  final double startAngle;
  final double sweepAngle;
  final double rotation;
  final double strokeWidth;
  final double alpha;
  final double lifecycleProgress;
  final bool perceptiblyVisible;
}

class _SurfaceReflectionPainter extends CustomPainter {
  _SurfaceReflectionPainter({
    required this.scene,
    required this.imageRect,
    required this.artworkSize,
    required this.tick,
  }) : super(repaint: tick);

  final BaseCampWaterV2Scene scene;
  final Rect imageRect;
  final Size artworkSize;
  final ValueListenable<int> tick;
  final Paint _paint = Paint();

  Size? _meshSize;
  Rect? _meshImageRect;
  Float32List? _positions;
  Int32List? _colors;
  Uint16List? _indices;
  Uint8List? _activeVertices;

  void _ensureMesh(Size size) {
    if (_meshSize == size && _meshImageRect == imageRect) return;
    _meshSize = size;
    _meshImageRect = imageRect;
    final bounds = imageRect.intersect(Offset.zero & size);
    final columns = (bounds.width / baseCampWaterReflectionGridStep).ceil() + 1;
    final rows = (bounds.height / baseCampWaterReflectionGridStep).ceil() + 1;
    final positions = Float32List(columns * rows * 2);
    final colors = Int32List(columns * rows);
    final activeVertices = Uint8List(columns * rows);
    var positionIndex = 0;
    var vertexIndex = 0;
    final scaleX = artworkSize.width / imageRect.width;
    final scaleY = artworkSize.height / imageRect.height;
    for (var row = 0; row < rows; row++) {
      final y = math.min(
        bounds.bottom,
        bounds.top + row * baseCampWaterReflectionGridStep,
      );
      for (var column = 0; column < columns; column++) {
        final x = math.min(
          bounds.right,
          bounds.left + column * baseCampWaterReflectionGridStep,
        );
        positions[positionIndex++] = x;
        positions[positionIndex++] = y;
        final artworkPoint = Offset(
          (x - imageRect.left) * scaleX,
          (y - imageRect.top) * scaleY,
        );
        activeVertices[vertexIndex++] = scene.containsWaterPoint(artworkPoint)
            ? 1
            : 0;
      }
    }
    final indices = Uint16List((columns - 1) * (rows - 1) * 6);
    var index = 0;
    for (var row = 0; row < rows - 1; row++) {
      for (var column = 0; column < columns - 1; column++) {
        final topLeft = row * columns + column;
        final bottomLeft = topLeft + columns;
        indices[index++] = topLeft;
        indices[index++] = bottomLeft;
        indices[index++] = topLeft + 1;
        indices[index++] = topLeft + 1;
        indices[index++] = bottomLeft;
        indices[index++] = bottomLeft + 1;
      }
    }
    _positions = positions;
    _colors = colors;
    _indices = indices;
    _activeVertices = activeVertices;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _ensureMesh(size);
    final positions = _positions;
    final colors = _colors;
    final indices = _indices;
    final activeVertices = _activeVertices;
    if (positions == null ||
        colors == null ||
        indices == null ||
        activeVertices == null) {
      return;
    }
    final elapsed = baseCampWaterReflectionStep * tick.value;
    final scaleX = artworkSize.width / imageRect.width;
    final scaleY = artworkSize.height / imageRect.height;
    for (var colorIndex = 0; colorIndex < colors.length; colorIndex++) {
      if (activeVertices[colorIndex] == 0) {
        colors[colorIndex] = 0;
        continue;
      }
      final positionIndex = colorIndex * 2;
      final artworkPoint = Offset(
        (positions[positionIndex] - imageRect.left) * scaleX,
        (positions[positionIndex + 1] - imageRect.top) * scaleY,
      );
      final reflection = scene.sampleReflection(artworkPoint, elapsed);
      final brightnessVariation = (reflection * .12).clamp(-.12, .12);
      final channel = (128 + brightnessVariation * 150).round().clamp(0, 255);
      colors[colorIndex] = Color.fromARGB(
        84,
        channel,
        channel,
        channel,
      ).toARGB32();
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
      indices: indices,
    );
    canvas.drawVertices(vertices, BlendMode.softLight, _paint);
  }

  @override
  bool shouldRepaint(_SurfaceReflectionPainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.imageRect != imageRect ||
      oldDelegate.artworkSize != artworkSize ||
      oldDelegate.tick != tick;
}

class _ArcFragmentPainter extends CustomPainter {
  _ArcFragmentPainter({
    required this.scene,
    required this.imageRect,
    required this.artworkSize,
    required this.tick,
  }) : _paths = List<Path>.generate(scene.fragmentCount, (_) => Path()),
       super(repaint: tick);

  final BaseCampWaterV2Scene scene;
  final Rect imageRect;
  final Size artworkSize;
  final ValueListenable<int> tick;
  final List<Path> _paths;
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = baseCampWaterArcStep * tick.value;
    final scale = imageRect.width / artworkSize.width;
    for (var index = 0; index < scene.fragmentCount; index++) {
      final sample = scene.arcSample(index, elapsed);
      if (sample.alpha <= .002) continue;
      final center = Offset(
        imageRect.left + sample.center.dx * scale,
        imageRect.top + sample.center.dy * scale,
      );
      final path = _paths[index]
        ..reset()
        ..addArc(
          Rect.fromCenter(
            center: Offset.zero,
            width: sample.radiusX * scale * 2,
            height: sample.radiusY * scale * 2,
          ),
          sample.startAngle,
          sample.sweepAngle,
        );
      _paint
        ..strokeWidth = sample.strokeWidth * scale
        ..color = Color.fromRGBO(118, 169, 161, sample.alpha);
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(sample.rotation)
        ..drawPath(path, _paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ArcFragmentPainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.imageRect != imageRect ||
      oldDelegate.artworkSize != artworkSize ||
      oldDelegate.tick != tick;
}

@immutable
class _ArcFragment {
  const _ArcFragment({
    required this.lifecycleSeconds,
    required this.phaseOffsetSeconds,
    required this.states,
  });

  final double lifecycleSeconds;
  final double phaseOffsetSeconds;
  final List<_ArcState> states;
}

@immutable
class _ArcState {
  const _ArcState({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.startAngle,
    required this.sweepAngle,
    required this.rotation,
    required this.strokeWidth,
    required this.maximumAlpha,
    required this.curvaturePhase,
    required this.movementPhaseX,
    required this.movementPhaseY,
  });

  final Offset center;
  final double radiusX;
  final double radiusY;
  final double startAngle;
  final double sweepAngle;
  final double rotation;
  final double strokeWidth;
  final double maximumAlpha;
  final double curvaturePhase;
  final double movementPhaseX;
  final double movementPhaseY;
}

double _lifecycleEnvelope(double progress) {
  if (progress < .2) return _smoothstep(progress / .2);
  if (progress < .65) {
    return .9 + .1 * math.sin((progress - .2) / .45 * math.pi * 2);
  }
  if (progress < .9) return _smoothstep((.9 - progress) / .25);
  return 0;
}

double _smoothstep(double value) {
  final clamped = value.clamp(0.0, 1.0);
  return clamped * clamped * (3 - 2 * clamped);
}

double _radians(double degrees) => degrees * math.pi / 180;

double _validWaterArea(BaseCampWaterFx water) {
  var area = 0.0;
  for (final region in water.effectiveAreas) {
    area += _polygonArea(region.mask).abs();
    for (final exclusion in region.exclusionMasks) {
      area -= _polygonArea(exclusion).abs();
    }
  }
  return math.max(0, area);
}

double _polygonArea(List<Offset> polygon) {
  if (polygon.length < 3) return 0;
  var total = 0.0;
  for (var index = 0; index < polygon.length; index++) {
    final current = polygon[index];
    final next = polygon[(index + 1) % polygon.length];
    total += current.dx * next.dy - next.dx * current.dy;
  }
  return total / 2;
}

Rect _waterBounds(BaseCampWaterFx water, Size artworkSize) {
  final points = <Offset>[
    for (final area in water.effectiveAreas) ...area.mask,
  ];
  if (points.isEmpty) return Offset.zero & artworkSize;
  var left = points.first.dx;
  var right = left;
  var top = points.first.dy;
  var bottom = top;
  for (final point in points.skip(1)) {
    left = math.min(left, point.dx);
    right = math.max(right, point.dx);
    top = math.min(top, point.dy);
    bottom = math.max(bottom, point.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

Offset _nextValidPoint(
  _DeterministicRandom random,
  BaseCampWaterFx water,
  Path validWaterPath,
  Rect bounds,
) {
  for (var attempt = 0; attempt < 256; attempt++) {
    final point = Offset(
      bounds.left + random.nextDouble() * bounds.width,
      bounds.top + random.nextDouble() * bounds.height,
    );
    if (validWaterPath.contains(point)) return point;
  }
  for (final area in water.effectiveAreas) {
    if (area.mask.isEmpty) continue;
    final sum = area.mask.fold<Offset>(
      Offset.zero,
      (sum, point) => sum + point,
    );
    final centroid = sum / area.mask.length.toDouble();
    if (validWaterPath.contains(centroid)) return centroid;
  }
  return bounds.center;
}

Path _waterPath(BaseCampWaterFx water) {
  final path = Path()..fillType = PathFillType.evenOdd;
  for (final area in water.effectiveAreas) {
    if (area.mask.length >= 3) {
      path.addPolygon(area.mask, true);
    }
    for (final exclusion in area.exclusionMasks) {
      if (exclusion.length >= 3) path.addPolygon(exclusion, true);
    }
  }
  return path;
}

double _gradientNoise2(double x, double y, int seed) {
  final x0 = x.floor();
  final y0 = y.floor();
  final fx = x - x0;
  final fy = y - y0;
  final u = _fade(fx);
  final v = _fade(fy);

  double dot(int dx, int dy) {
    final hash = _hash2(x0 + dx, y0 + dy, seed);
    final gradient = _gradient2(hash);
    return gradient.$1 * (fx - dx) + gradient.$2 * (fy - dy);
  }

  final top = _lerp(dot(0, 0), dot(1, 0), u);
  final bottom = _lerp(dot(0, 1), dot(1, 1), u);
  return (_lerp(top, bottom, v) * 1.35).clamp(-1.0, 1.0);
}

double _fade(double value) =>
    value * value * value * (value * (value * 6 - 15) + 10);

double _lerp(double a, double b, double t) => a + (b - a) * t;

(double, double) _gradient2(int hash) => switch (hash & 7) {
  0 => (1, 0),
  1 => (-1, 0),
  2 => (0, 1),
  3 => (0, -1),
  4 => (.70710678, .70710678),
  5 => (-.70710678, .70710678),
  6 => (.70710678, -.70710678),
  _ => (-.70710678, -.70710678),
};

int _hash2(int x, int y, int seed) {
  var value = seed ^ (x * 0x1f123bb5) ^ (y * 0x5f356495);
  value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff;
  value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff;
  return value ^ (value >> 16);
}

class _DeterministicRandom {
  _DeterministicRandom(this._state);

  int _state;

  double nextDouble() {
    var value = _state;
    value ^= (value << 13) & 0xffffffff;
    value ^= value >> 17;
    value ^= (value << 5) & 0xffffffff;
    _state = value & 0xffffffff;
    return (_state & 0x7fffffff) / 0x80000000;
  }
}
