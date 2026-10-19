import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Deterministic, world-fixed DATA VAULT flight renderer.  It deliberately
/// owns only Ambient B geometry; HISTORY foreground UI remains outside it.
class HistoryDataVaultHyperspace {
  const HistoryDataVaultHyperspace({required this.seconds});

  final double seconds;

  static final _world = _VaultWorld();

  void paint(Canvas canvas, Size size) {
    final cameraDistance = HistoryDataVaultMotion.distanceAt(seconds);
    _world.prepare(cameraDistance + 94, retainFrom: cameraDistance - 2);
    final speed = HistoryDataVaultMotion.speedAt(seconds);
    final lookAhead = speed >= 9
        ? 13.0
        : speed >= 6
        ? 10.0
        : 8.0;
    final camera = _VaultCamera(
      position: _world.sample(cameraDistance),
      target: _world.sample(cameraDistance + lookAhead),
      distance: cameraDistance,
      curvature: _world.curvatureAt(cameraDistance + 10),
      size: size,
    );
    final samples = _surfaceSamples(cameraDistance);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff030a14),
    );
    _paintSurfaces(canvas, camera, samples);
    _paintFloorDetail(canvas, camera, samples);
    _paintPillars(canvas, camera, cameraDistance);
    _paintAccessLights(canvas, camera, cameraDistance, speed);
    canvas.restore();
  }

  List<_VaultSample> _surfaceSamples(double start) {
    final result = <_VaultSample>[];
    var s = start + .5;
    while (s <= start + 90 && result.length < 61) {
      final curvature = _world.curvatureAt(s).abs();
      result.add(_world.sample(s));
      s += curvature > .012 ? 1.5 : 3;
    }
    if (result.length < 2) result.add(_world.sample(start + 90));
    return result;
  }

  void _paintSurfaces(
    Canvas canvas,
    _VaultCamera camera,
    List<_VaultSample> samples,
  ) {
    for (var index = samples.length - 2; index >= 0; index--) {
      final far = samples[index + 1];
      final near = samples[index];
      final fog = ((far.s - camera.distance - 25) / 65).clamp(0.0, .75);
      _fillWorldQuad(
        canvas,
        camera,
        [
          near.point(-4, 0),
          near.point(4, 0),
          far.point(4, 0),
          far.point(-4, 0),
        ],
        Color.lerp(const Color(0xff0b2c48), const Color(0xff030a14), fog)!,
      );
      _fillWorldQuad(
        canvas,
        camera,
        [
          near.point(-4, 5),
          far.point(-4, 5),
          far.point(4, 5),
          near.point(4, 5),
        ],
        Color.lerp(const Color(0xff07192a), const Color(0xff030a14), fog)!,
      );
      _fillWorldQuad(
        canvas,
        camera,
        [
          near.point(-4, 0),
          far.point(-4, 0),
          far.point(-4, 5),
          near.point(-4, 5),
        ],
        Color.lerp(const Color(0xff0e314b), const Color(0xff030a14), fog)!,
      );
      _fillWorldQuad(
        canvas,
        camera,
        [near.point(4, 0), near.point(4, 5), far.point(4, 5), far.point(4, 0)],
        Color.lerp(const Color(0xff071627), const Color(0xff030a14), fog)!,
      );
    }
  }

  void _paintFloorDetail(
    Canvas canvas,
    _VaultCamera camera,
    List<_VaultSample> samples,
  ) {
    for (final offset in const [-3.2, -1.6, 0.0, 1.6, 3.2]) {
      _strokeWorldPolyline(
        canvas,
        camera,
        samples.map((sample) => sample.point(offset, 0)).toList(),
        const Color(0xff29bce4).withValues(alpha: .18),
        1,
      );
    }
    final minSeam = ((camera.distance - 2) / 6).floor();
    for (var n = minSeam; n <= minSeam + 16; n++) {
      final sample = _world.sample(n * 6.0);
      _strokeWorldLine(
        canvas,
        camera,
        sample.point(-4, 0),
        sample.point(4, 0),
        const Color(0xff40b4df).withValues(alpha: .13),
        .8,
      );
    }
  }

  void _paintPillars(Canvas canvas, _VaultCamera camera, double distance) {
    final first = ((distance - 3) / 6).floor();
    final pillars = <_VaultSample>[];
    for (var n = first; n < first + 18; n++) {
      final s = n * 6.0;
      if (s > distance + 92) break;
      pillars.add(_world.sample(s));
    }
    for (final sample in pillars.reversed) {
      final n = (sample.s / 6).round();
      final brightness =
          .90 + .10 * math.sin(math.pi * 2 * seconds / 12 + n * .65);
      for (final side in [-1.0, 1.0]) {
        final depth = sample.s - distance;
        final alpha = (1 - depth / 110).clamp(.12, .90) * brightness;
        _pillarLayer(
          canvas,
          camera,
          sample,
          side,
          .55,
          const Color(0xff29bce4).withValues(alpha: .10 * alpha),
        );
        _pillarLayer(
          canvas,
          camera,
          sample,
          side,
          .18,
          const Color(0xff29bce4).withValues(alpha: .36 * alpha),
        );
        _pillarLayer(
          canvas,
          camera,
          sample,
          side,
          .045,
          const Color(0xff91f4ff).withValues(alpha: .82 * alpha),
        );
        _pillarEdge(canvas, camera, sample, side, alpha);
        if (depth > 2 && depth < 45) {
          _strokeWorldLine(
            canvas,
            camera,
            sample.point(side * 3.8, 0),
            sample
                .point(side * 3.8, 0)
                .translate(sample.tangentX * 1.7, sample.tangentZ * 1.7),
            const Color(0xff91f4ff).withValues(alpha: .12 * alpha),
            .8,
          );
        }
      }
    }
  }

  void _pillarLayer(
    Canvas canvas,
    _VaultCamera camera,
    _VaultSample sample,
    double side,
    double width,
    Color color,
  ) {
    _fillWorldQuad(canvas, camera, [
      sample.point(side * 3.8 - width / 2, 0),
      sample.point(side * 3.8 + width / 2, 0),
      sample.point(side * 3.8 + width / 2, 5),
      sample.point(side * 3.8 - width / 2, 5),
    ], color);
  }

  void _pillarEdge(
    Canvas canvas,
    _VaultCamera camera,
    _VaultSample sample,
    double side,
    double alpha,
  ) {
    _strokeWorldLine(
      canvas,
      camera,
      sample.point(side * 3.8 - .09, 0),
      sample.point(side * 3.8 - .09, 5),
      const Color(0xffc9fbff).withValues(alpha: .2 * alpha),
      .7,
    );
  }

  void _paintAccessLights(
    Canvas canvas,
    _VaultCamera camera,
    double distance,
    double speed,
  ) {
    for (var index = 0; index < 3; index++) {
      final worldS = distance * 1.35 + index * 31;
      final sample = _world.sample(worldS);
      final offset = index == 2 ? 0.0 : (index == 0 ? -3.2 : 3.2);
      final point = sample.point(offset, index == 1 ? 1.8 : 0);
      final projected = camera.project(point);
      if (projected == null) continue;
      final visibility =
          ((projected.z - .5) / 7).clamp(0.0, 1.0) *
          ((90 - projected.z) / 15).clamp(0.0, 1.0);
      canvas.drawCircle(
        projected.offset,
        1.5 + 1.5 * (speed / 11),
        Paint()
          ..color = const Color(0xffa8f8ff).withValues(alpha: .45 * visibility),
      );
    }
  }

  void _fillWorldQuad(
    Canvas canvas,
    _VaultCamera camera,
    List<_WorldPoint> points,
    Color color,
  ) {
    final clipped = camera.clip(points);
    if (clipped.length < 3) return;
    final projected = clipped
        .map(camera.projectCamera)
        .whereType<_Projected>()
        .toList();
    if (projected.length < 3) return;
    final path = Path()
      ..moveTo(projected.first.offset.dx, projected.first.offset.dy);
    for (final point in projected.skip(1)) {
      path.lineTo(point.offset.dx, point.offset.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _strokeWorldLine(
    Canvas canvas,
    _VaultCamera camera,
    _WorldPoint a,
    _WorldPoint b,
    Color color,
    double width,
  ) {
    final clipped = camera.clip([a, b]);
    if (clipped.length != 2) return;
    final start = camera.projectCamera(clipped[0]);
    final end = camera.projectCamera(clipped[1]);
    if (start == null || end == null) return;
    canvas.drawLine(
      start.offset,
      end.offset,
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }

  void _strokeWorldPolyline(
    Canvas canvas,
    _VaultCamera camera,
    List<_WorldPoint> points,
    Color color,
    double width,
  ) {
    for (var index = 0; index < points.length - 1; index++) {
      _strokeWorldLine(
        canvas,
        camera,
        points[index],
        points[index + 1],
        color,
        width,
      );
    }
  }
}

class HistoryDataVaultMotion {
  static const cycleSeconds = 48.0;
  static const distancePerCycle = 305.5;
  static double smooth(double u) {
    final c = u.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  static double _smoothIntegral(double u) {
    final c = u.clamp(0.0, 1.0);
    return c * c * c - .5 * c * c * c * c;
  }

  static double speedAt(double seconds) {
    final t = ((seconds % cycleSeconds) + cycleSeconds) % cycleSeconds;
    if (t < 12) return 4;
    if (t < 17) return 4 + 7 * smooth((t - 12) / 5);
    if (t < 22) return 11;
    if (t < 27) return 11 - 4 * smooth((t - 22) / 5);
    if (t < 36) return 7;
    if (t < 42) return 7 - 3 * smooth((t - 36) / 6);
    return 4;
  }

  static double distanceAt(double seconds) {
    final cycles = (seconds / cycleSeconds).floor();
    final t = seconds - cycles * cycleSeconds;
    double distance = cycles * distancePerCycle;
    if (t <= 12) {
      return distance + 4 * t;
    }
    distance += 48;
    if (t <= 17) {
      return distance +
          20 * ((t - 12) / 5) +
          35 * _smoothIntegral((t - 12) / 5);
    }
    distance += 37.5;
    if (t <= 22) {
      return distance + 11 * (t - 17);
    }
    distance += 55;
    if (t <= 27) {
      return distance +
          55 * ((t - 22) / 5) -
          20 * _smoothIntegral((t - 22) / 5);
    }
    distance += 45;
    if (t <= 36) {
      return distance + 7 * (t - 27);
    }
    distance += 63;
    if (t <= 42) {
      return distance +
          42 * ((t - 36) / 6) -
          18 * _smoothIntegral((t - 36) / 6);
    }
    return distance + 33 + 4 * (t - 42);
  }

  static double curvatureAt(double s) {
    final base =
        .006 * math.sin(math.pi * 2 * s / 180) +
        .013 * math.sin(math.pi * 2 * s / 420);
    final r = ((s % 240) + 240) % 240;
    return base +
        _turnEnvelope(r, 40, 105, .018) +
        _turnEnvelope(r, 130, 195, -.018);
  }

  static double _turnEnvelope(double r, double start, double end, double peak) {
    if (r < start || r > end) return 0;
    if (r < start + 20) {
      return peak * smooth((r - start) / 20);
    }
    if (r > end - 20) {
      return peak * smooth((end - r) / 20);
    }
    return peak;
  }
}

class _VaultWorld {
  final List<_VaultSample> _cache = [_VaultSample.zero()];
  double curvatureAt(double s) => HistoryDataVaultMotion.curvatureAt(s);

  void prepare(double target, {required double retainFrom}) {
    while (_cache.last.s < target) {
      final previous = _cache.last;
      final step = .5;
      final heading =
          previous.heading + curvatureAt(previous.s + step / 2) * step;
      _cache.add(
        _VaultSample(
          previous.s + step,
          previous.x + math.sin(heading) * step,
          previous.z + math.cos(heading) * step,
          heading,
        ),
      );
    }
    while (_cache.length > 720 && _cache[1].s < retainFrom) {
      _cache.removeAt(0);
    }
  }

  _VaultSample sample(double s) {
    prepare(s, retainFrom: s - 1);
    for (var index = _cache.length - 2; index >= 0; index--) {
      final a = _cache[index];
      final b = _cache[index + 1];
      if (a.s <= s && s <= b.s) {
        return _VaultSample.lerp(a, b, (s - a.s) / (b.s - a.s));
      }
    }
    return _cache.last;
  }
}

class _VaultSample {
  const _VaultSample(this.s, this.x, this.z, this.heading);
  factory _VaultSample.zero() => const _VaultSample(0, 0, 0, 0);
  factory _VaultSample.lerp(_VaultSample a, _VaultSample b, double t) =>
      _VaultSample(
        a.s + (b.s - a.s) * t,
        a.x + (b.x - a.x) * t,
        a.z + (b.z - a.z) * t,
        a.heading + (b.heading - a.heading) * t,
      );
  final double s, x, z, heading;
  double get tangentX => math.sin(heading);
  double get tangentZ => math.cos(heading);
  _WorldPoint point(double lateral, double y) => _WorldPoint(
    x + math.cos(heading) * lateral,
    y,
    z - math.sin(heading) * lateral,
  );
}

class _WorldPoint {
  const _WorldPoint(this.x, this.y, this.z);
  final double x, y, z;
  _WorldPoint translate(double dx, double dz) => _WorldPoint(x + dx, y, z + dz);
}

class _CameraPoint {
  const _CameraPoint(this.x, this.y, this.z);
  final double x, y, z;
}

class _Projected {
  const _Projected(this.offset, this.z);
  final Offset offset;
  final double z;
}

class _VaultCamera {
  _VaultCamera({
    required _VaultSample position,
    required _VaultSample target,
    required this.distance,
    required double curvature,
    required this.size,
  }) : _position = position,
       _forwardX = _normX(target.x - position.x, target.z - position.z),
       _forwardZ = _normZ(target.x - position.x, target.z - position.z),
       roll = (-35 * curvature).clamp(-math.pi / 60, math.pi / 60) {
    _rightX = _forwardZ;
    _rightZ = -_forwardX;
  }
  final _VaultSample _position;
  final Size size;
  final double distance, roll;
  late final double _forwardX, _forwardZ, _rightX, _rightZ;
  static double _normX(double x, double z) {
    final l = math.sqrt(x * x + z * z);
    return x / l;
  }

  static double _normZ(double x, double z) {
    final l = math.sqrt(x * x + z * z);
    return z / l;
  }

  _CameraPoint camera(_WorldPoint p) => _CameraPoint(
    (p.x - _position.x) * _rightX + (p.z - _position.z) * _rightZ,
    p.y - 2.2,
    (p.x - _position.x) * _forwardX + (p.z - _position.z) * _forwardZ,
  );
  List<_CameraPoint> clip(List<_WorldPoint> world) {
    final input = world.map(camera).toList();
    final output = <_CameraPoint>[];
    for (var i = 0; i < input.length; i++) {
      final a = input[i], b = input[(i + 1) % input.length];
      final ai = a.z > .5, bi = b.z > .5;
      if (ai) output.add(a);
      if (ai != bi) {
        final t = (.5 - a.z) / (b.z - a.z);
        output.add(
          _CameraPoint(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, .5),
        );
      }
    }
    return output;
  }

  _Projected? project(_WorldPoint p) => projectCamera(camera(p));
  _Projected? projectCamera(_CameraPoint p) {
    if (p.z <= .5 || p.z > 100) return null;
    final f = size.height / (2 * math.tan(65 * math.pi / 360));
    final c = math.cos(roll), s = math.sin(roll);
    final x = p.x * c - p.y * s, y = p.x * s + p.y * c;
    return _Projected(
      Offset(size.width / 2 + f * x / p.z, size.height / 2 - f * y / p.z),
      p.z,
    );
  }
}
