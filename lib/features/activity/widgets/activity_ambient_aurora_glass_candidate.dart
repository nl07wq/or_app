import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Production Flutter-native Aurora Glass V8 ambient.
///
/// The glass material is intentionally stable; continuous, organically
/// deformed radial ripples control only when each square tile forms,
/// reorganizes and dissolves.
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

  /// Current production values are applied once, from the deployed baseline.
  static const _deployedMotionSpeed = .20;
  static const motionSpeed = _deployedMotionSpeed * 1.10;

  /// Reduces only dynamic activation and spatial-deviation amplitude.
  static const _deployedMotionVariation = .20;
  static const motionVariation = _deployedMotionVariation * 1.20;

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
    final events = _activeEvents(
      elapsed,
      variation: _motionVariation,
      selectFragments: !staticFrame,
    );
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
    // it does not restart when the upstream controller repeats. Scaling this
    // one clock slows formation, propagation, reorganization and dissolution
    // proportionally while leaving the event model and amplitude unchanged.
    return SchedulerBinding.instance.currentFrameTimeStamp.inMicroseconds /
        Duration.microsecondsPerSecond *
        ActivityAmbientAuroraGlassCandidate.motionSpeed;
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

  /// Probabilistic union of every currently active irregular ripple.
  double _tileState({
    required int row,
    required int column,
    required int rows,
    required double elapsed,
    required List<_CurvedFragmentEvent> events,
  }) {
    final tileNoise = _tileNoise(row, column);
    final activationDelay = (tileNoise - .5) * .28 * _motionVariation;
    final thresholdOffset =
        (_cellNoise(row, column, 23) - .5) * .20 * _motionVariation;
    var remaining = 1.0;

    for (final event in events) {
      final dx =
          column +
          .5 -
          event.center.dx * ActivityAmbientAuroraGlassCandidate.gridColumns;
      final dy = row + .5 - event.center.dy * (rows - 2);
      final activation = event.activationAt(
        dx: dx,
        dy: dy,
        elapsed: elapsed - activationDelay,
      );
      if (activation <= 0) continue;
      final contribution = (activation + thresholdOffset).clamp(0.0, 1.0);
      remaining *= 1 - contribution;
    }
    return (1 - remaining).clamp(0.0, 1.0);
  }

  double get _motionVariation =>
      staticFrame ? 1 : ActivityAmbientAuroraGlassCandidate.motionVariation;

  List<_CurvedFragmentEvent> _activeEvents(
    double elapsed, {
    required double variation,
    required bool selectFragments,
  }) {
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
        _CurvedFragmentEvent.fromIndex(
          index,
          variation: variation,
          selectFragments: selectFragments,
        ),
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
    required this.waveSpeed,
    required this.halfWidth,
    required this.fragmentPhase,
    required this.blockSeed,
    required this.variation,
    required this.selectFragments,
  });

  factory _CurvedFragmentEvent.fromIndex(
    int index, {
    required double variation,
    required bool selectFragments,
  }) {
    return _CurvedFragmentEvent(
      start:
          index / ActivityAmbientAuroraGlassCandidate.eventFrequency +
          (_eventNoise(index, 1) * 2 - 1) * .11 * variation,
      lifetime: 3 + (_eventNoise(index, 2) - .5) * 1.2 * variation,
      center: _eventCenter(index, variation: variation),
      waveSpeed: .46 + (_eventNoise(index, 3) - .5) * .16 * variation,
      halfWidth: .1145 + (_eventNoise(index, 7) - .5) * .085 * variation,
      fragmentPhase: _eventNoise(index, 8) * math.pi * 2,
      blockSeed: index,
      variation: variation,
      selectFragments: selectFragments,
    );
  }

  final double start;
  final double lifetime;
  final Offset center;
  final double waveSpeed;
  final double halfWidth;
  final double fragmentPhase;
  final int blockSeed;
  final double variation;
  final bool selectFragments;

  double activationAt({
    required double dx,
    required double dy,
    required double elapsed,
  }) {
    // A passing wave owns one fixed coarse mask. It is deliberately sampled
    // before lifecycle and wake evaluation, so rejected square blocks never
    // receive a delayed glow or residual trail from this event.
    final blockX = (dx / 2).floor();
    final blockY = (dy / 2).floor();
    if (!_isMosaicBlockActive(blockSeed, blockX, blockY)) return 0;
    final localTime =
        elapsed - start - _mosaicBlockDelay(blockSeed, blockX, blockY);
    final q = (localTime / lifetime).clamp(0.0, 1.0);
    if (localTime <= 0 || q >= 1) return 0;
    final envelope = _smoothStep(0, .16, q) * (1 - _smoothStep(.66, 1, q));
    if (envelope <= 0) return 0;

    // Euclidean grid distance is the primary propagation coordinate. The
    // bounded angular deformation softens the front without replacing its
    // center-to-outside progression with independent clusters or bands.
    final radialDistance = math.sqrt(dx * dx + dy * dy);
    final spatialVariation = _smoothRadialVariation(
      dx,
      dy,
      localTime,
      fragmentPhase,
    );
    final irregularDistance =
        radialDistance + spatialVariation * 1.20 * variation;
    final frontRadius =
        waveSpeed * ActivityAmbientAuroraGlassCandidate.gridColumns * localTime;
    final distanceFromFront = (irregularDistance - frontRadius).abs();
    // The previous narrow band read as a thin ◎ at device size. Widening the
    // responsive grid-space front, and retaining a short, fading wake behind
    // it, makes each event a broad tile formation rather than a line. This is
    // measured in existing tile units: neither the viewport nor a prototype
    // canvas/grid value participates in the geometry.
    final frontWidth =
        halfWidth * ActivityAmbientAuroraGlassCandidate.gridColumns * 1.18;
    final leadingActivation =
        1 - _smoothStep(frontWidth * .14, frontWidth, distanceFromFront);
    final distanceBehindFront = frontRadius - irregularDistance;
    final wakeActivation = distanceBehindFront <= 0
        ? 0.0
        : (1 -
                  _smoothStep(
                    frontWidth * .25,
                    frontWidth * 2.85,
                    distanceBehindFront,
                  )) *
              .72;
    final frontActivation = math.max(leadingActivation, wakeActivation);
    if (frontActivation <= 0) return 0;

    // Coarse correlated groups leave stepped, pixel-like arc fragments. They
    // evolve with the event but cannot form stationary vertical or diagonal
    // bands, nor a smooth continuous circular outline.
    final fragments = _mosaicFragmentField(dx, dy, localTime, fragmentPhase);
    final partialFront = selectFragments
        ? (radialDistance < 1.35
              ? .78 + fragments * .22
              : .22 + _smoothStep(.42, .73, fragments) * .78)
        : 1.0;
    return envelope * frontActivation * partialFront;
  }
}

double _smoothRadialVariation(double dx, double dy, double time, double phase) {
  final angle = math.atan2(dy, dx);
  final radius = math.sqrt(dx * dx + dy * dy);
  final signal =
      .52 * math.sin(angle * 3 + time * .29 + phase) +
      .31 * math.sin(angle * 7 - time * .17 + phase * 1.6) +
      .17 * math.sin(radius * .73 + angle * 2 + phase * .62);
  return signal.clamp(-1.0, 1.0);
}

double _mosaicFragmentField(double dx, double dy, double time, double phase) {
  final angle = math.atan2(dy, dx);
  final radius = math.sqrt(dx * dx + dy * dy);
  // Quantizing only the activation field, rather than tile geometry, creates
  // uneven stepped groups while preserving the existing 30-column square grid.
  // Larger quantized activation regions form adjacent-tile mosaics while
  // preserving the individual square tile pitch and responsive grid.
  final groupX = (dx / 5.2).floorToDouble();
  final groupY = (dy / 5.2).floorToDouble();
  final grouped =
      .58 * math.sin(groupX * .91 + groupY * .57 + time * .17 + phase) +
      .42 * math.sin(groupX * .31 - groupY * .73 - time * .11 + phase * 1.7);
  final field =
      .54 * grouped +
      .29 * math.sin(angle * 5 + radius * .18 + time * .33 + phase) +
      .17 * math.sin(angle * 9 - time * .19 + phase * 1.3);
  return (.5 + field * .5).clamp(0.0, 1.0);
}

/// Coarse eligibility is intentionally independent of elapsed time. Every
/// coordinate in a two-by-two tile block shares one decision and delay for an
/// event; adjacent rejected blocks sometimes join into the larger stepped
/// gaps required to break a continuous radial band.
bool _isMosaicBlockActive(int eventSeed, int blockX, int blockY) {
  final own = _hash01(eventSeed, blockX, blockY);
  final east = _hash01(eventSeed, blockX + 1, blockY);
  final south = _hash01(eventSeed, blockX, blockY + 1);
  final bridge = _hash01(eventSeed ^ 0x5f3759df, blockX, blockY);
  final inactive =
      own > .72 || (own > .56 && (east > .68 || south > .68 || bridge > .73));
  return !inactive;
}

double _mosaicBlockDelay(int eventSeed, int blockX, int blockY) =>
    (_hash01(eventSeed ^ 0x45d9f3b, blockX, blockY) - .5) * .24;

Offset _eventCenter(int index, {required double variation}) {
  final angle = _eventNoise(index, 101) * math.pi * 2;
  // Successive waves share the viewport center while retaining a small,
  // deterministic origin drift so their fronts can split and reconnect.
  final radius = .043 + (_eventNoise(index, 102) - .5) * .078 * variation;
  return Offset(.5 + math.cos(angle) * radius, .5 + math.sin(angle) * radius);
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
