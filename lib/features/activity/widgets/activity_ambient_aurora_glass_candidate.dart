import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Production Flutter-native Aurora Glass V8 ambient.
///
/// The glass material is intentionally stable; continuous curved-fragment
/// events control only when each square tile forms, reorganizes and dissolves.
class ActivityAmbientAuroraGlassCandidate extends StatelessWidget {
  const ActivityAmbientAuroraGlassCandidate({
    super.key,
    required this.animation,
    required this.reducedMotion,
  });

  static const fieldKey = ValueKey('activity-ambient-aurora-glass-candidate');
  static const gridColumns = 30;
  static const eventFrequency = 2.09;
  static const globalSeed = 51;

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
  static const _staticElapsedSeconds = 7.25;

  List<double>? _stateCache;
  int _cachedRows = 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pitch = size.width / ActivityAmbientAuroraGlassCandidate.gridColumns;
    final rows = (size.height / pitch).ceil() + 2;
    final elapsed = _elapsedSeconds;
    final events = _activeEvents(elapsed);
    final states = _statesFor(rows: rows, elapsed: elapsed, events: events);
    final material = _GlassMaterial(pitch);

    for (var row = 0; row < rows; row++) {
      for (
        var column = 0;
        column < ActivityAmbientAuroraGlassCandidate.gridColumns;
        column++
      ) {
        final index =
            row * ActivityAmbientAuroraGlassCandidate.gridColumns + column;
        final state = states[index];
        if (state < .10) continue;
        final geometry = _tileGeometry(row, column, pitch, state);
        material.paint(
          canvas: canvas,
          rect: geometry,
          color: _tileRgb(row, column, rows, elapsed),
          intensity: state,
          edgeEnergy: _edgeEnergy(states, row, column, rows),
        );
      }
    }
  }

  double get _elapsedSeconds {
    if (staticFrame) return _staticElapsedSeconds;
    // This timestamp is monotonic for the app process. Unlike animation.value,
    // it does not restart when the upstream controller repeats.
    return SchedulerBinding.instance.currentFrameTimeStamp.inMicroseconds /
        Duration.microsecondsPerSecond;
  }

  List<double> _statesFor({
    required int rows,
    required double elapsed,
    required List<_CurvedFragmentEvent> events,
  }) {
    final count = rows * ActivityAmbientAuroraGlassCandidate.gridColumns;
    final cache = _stateCache;
    final states = cache != null && _cachedRows == rows
        ? cache
        : List<double>.filled(count, 0);
    _stateCache = states;
    _cachedRows = rows;

    for (var row = 0; row < rows; row++) {
      for (
        var column = 0;
        column < ActivityAmbientAuroraGlassCandidate.gridColumns;
        column++
      ) {
        states[row * ActivityAmbientAuroraGlassCandidate.gridColumns +
            column] = _tileState(
          row: row,
          column: column,
          rows: rows,
          elapsed: elapsed,
          events: events,
        );
      }
    }
    return states;
  }

  /// Probabilistic union of every currently active finite curved band.
  double _tileState({
    required int row,
    required int column,
    required int rows,
    required double elapsed,
    required List<_CurvedFragmentEvent> events,
  }) {
    final point = Offset(
      (column + .5) / ActivityAmbientAuroraGlassCandidate.gridColumns,
      // The event model is evaluated in the specified normalized viewport
      // coordinates (u = x / width, v = y / height). Tiles remain square
      // because their rendered pitch is derived only from viewport width.
      (row + .5) / (rows - 2),
    );
    final tileNoise = _tileNoise(row, column);
    final activationDelay = tileNoise * .28 - .14;
    final thresholdOffset = (_cellNoise(row, column, 23) * .20) - .10;
    var remaining = 1.0;

    for (final event in events) {
      final activation = event.activationAt(
        point: point,
        elapsed: elapsed - activationDelay,
      );
      if (activation <= 0) continue;
      final contribution = (activation + thresholdOffset).clamp(0.0, 1.0);
      remaining *= 1 - contribution;
    }
    return (1 - remaining).clamp(0.0, 1.0);
  }

  List<_CurvedFragmentEvent> _activeEvents(double elapsed) {
    // The lifetime is bounded to 3.6 seconds, plus jitter/delay margins;
    // this window remains bounded at any elapsed time.
    final first = math.max(
      0,
      ((elapsed - 3.9) * ActivityAmbientAuroraGlassCandidate.eventFrequency)
          .floor(),
    );
    final last =
        ((elapsed + .12) * ActivityAmbientAuroraGlassCandidate.eventFrequency)
            .ceil();
    return [
      for (var index = first; index <= last; index++)
        _CurvedFragmentEvent.fromIndex(index),
    ];
  }

  /// Exact V8 contract size: clamp(4 + 18 * state, 4, 22) / 24 * pitch.
  Rect _tileGeometry(int row, int column, double pitch, double state) {
    final extent = ((4 + 18 * state).clamp(4.0, 22.0) / 24) * pitch;
    return Rect.fromCenter(
      center: Offset((column + .5) * pitch, (row + .5) * pitch),
      width: extent,
      height: extent,
    );
  }

  Color _tileRgb(int row, int column, int rows, double elapsed) {
    final hue =
        _cellNoise(row, column, 17) +
        .16 * math.sin(elapsed * .55 + column * .14);
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
        .5 * math.sin(column * .24 - row * .17 + elapsed * .36 + rows * .013);
    return Color.lerp(recovered, Color.lerp(_cyan, _magenta, region)!, .86)!;
  }

  double _edgeEnergy(List<double> states, int row, int column, int rows) {
    double stateAt(int r, int c) {
      if (r < 0 ||
          r >= rows ||
          c < 0 ||
          c >= ActivityAmbientAuroraGlassCandidate.gridColumns) {
        return 0;
      }
      return states[r * ActivityAmbientAuroraGlassCandidate.gridColumns + c];
    }

    final center = stateAt(row, column);
    return (4 * center -
            stateAt(row - 1, column) -
            stateAt(row + 1, column) -
            stateAt(row, column - 1) -
            stateAt(row, column + 1))
        .abs()
        .clamp(0.0, 1.0);
  }

  double _tileNoise(int row, int column) {
    final neighbor =
        (_cellNoise(row ~/ 2, column ~/ 2, 31) +
            _cellNoise((row + 1) ~/ 2, (column + 1) ~/ 2, 37)) /
        2;
    return .65 * neighbor + .35 * _cellNoise(row, column, 41);
  }

  @override
  bool shouldRepaint(covariant _AuroraGlassPainter oldDelegate) =>
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.animation != animation;
}

class _CurvedFragmentEvent {
  const _CurvedFragmentEvent({
    required this.start,
    required this.lifetime,
    required this.center,
    required this.theta,
    required this.radius,
    required this.arcSpan,
    required this.halfWidth,
    required this.deformationPhase,
  });

  factory _CurvedFragmentEvent.fromIndex(int index) {
    return _CurvedFragmentEvent(
      start:
          index / ActivityAmbientAuroraGlassCandidate.eventFrequency +
          (_eventNoise(index, 1) * 2 - 1) * .11,
      lifetime: 1.6 + _eventNoise(index, 2) * 2.0,
      center: _eventCenter(index),
      theta: _eventNoise(index, 3) * math.pi * 2,
      radius: .10 + _eventNoise(index, 4) * .21,
      arcSpan: .35 + _eventNoise(index, 5) * .95,
      halfWidth: .035 + _eventNoise(index, 6) * .060,
      deformationPhase: _eventNoise(index, 7) * math.pi * 2,
    );
  }

  final double start;
  final double lifetime;
  final Offset center;
  final double theta;
  final double radius;
  final double arcSpan;
  final double halfWidth;
  final double deformationPhase;

  double activationAt({required Offset point, required double elapsed}) {
    final localTime = elapsed - start;
    final q = (localTime / lifetime).clamp(0.0, 1.0);
    if (localTime <= 0 || q >= 1) return 0;
    final envelope = _smoothStep(0, .22, q) * (1 - _smoothStep(.62, 1, q));
    if (envelope <= 0) return 0;

    final wobble = localTime * 1.15 + deformationPhase;
    final orientation = theta + math.sin(wobble * .83) * .09;
    final dynamicRadius = radius * (1 + math.sin(wobble * 1.17) * .055);
    final arcCenter =
        center +
        Offset(math.cos(wobble * .71) * .008, math.sin(wobble * .93) * .008);
    final relative = point - arcCenter;
    final rawAngle = math.atan2(relative.dy, relative.dx);
    final delta = _wrapAngle(
      rawAngle - orientation,
    ).clamp(-arcSpan / 2, arcSpan / 2);
    final nearest =
        arcCenter + Offset.fromDirection(orientation + delta, dynamicRadius);
    final distance = (point - nearest).distance;
    final spatial = 1 - _smoothStep(.25 * halfWidth, halfWidth, distance);
    return envelope * spatial;
  }
}

Offset _eventCenter(int index) {
  final previous = index == 0 ? null : _centerCandidate(index - 1, 0);
  for (var attempt = 0; attempt < 6; attempt++) {
    final candidate = _centerCandidate(index, attempt);
    if (previous == null || (candidate - previous).distance >= .13) {
      return candidate;
    }
  }
  return _centerCandidate(index, 6);
}

Offset _centerCandidate(int index, int attempt) {
  final angle = _eventNoise(index, 101 + attempt * 3) * math.pi * 2;
  // Linear radius gives a weak center bias while still reaching the viewport.
  final radius = .06 + _eventNoise(index, 102 + attempt * 3) * .59;
  return Offset(
    (.5 + math.cos(angle) * radius).clamp(.04, .96).toDouble(),
    (.5 + math.sin(angle) * radius).clamp(.04, .96).toDouble(),
  );
}

double _eventNoise(int eventIndex, int parameterId) => _hash01(
  ActivityAmbientAuroraGlassCandidate.globalSeed,
  eventIndex,
  parameterId,
);

double _cellNoise(int row, int column, int parameterId) => _hash01(
  ActivityAmbientAuroraGlassCandidate.globalSeed ^ row,
  column,
  parameterId,
);

double _hash01(int first, int second, int third) {
  var value = first * 73856093 ^ second * 19349663 ^ third * 83492791;
  value ^= value >> 13;
  value *= 1274126177;
  return (value & 0x7fffffff) / 0x7fffffff;
}

double _smoothStep(double lower, double upper, double value) {
  final t = ((value - lower) / (upper - lower)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _wrapAngle(double value) {
  while (value > math.pi) {
    value -= math.pi * 2;
  }
  while (value < -math.pi) {
    value += math.pi * 2;
  }
  return value;
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
