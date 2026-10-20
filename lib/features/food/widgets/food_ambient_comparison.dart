import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';

enum FoodAmbientVariant {
  continuousCirculation('CONTINUOUS CIRCULATION'),
  metabolicCells('METABOLIC CELLS'),
  thermalCurrent('THERMAL CURRENT');

  const FoodAmbientVariant(this.label);
  final String label;

  static FoodAmbientVariant fromPersistedName(String? value) {
    // V4.0's removed mode deliberately migrates to the surviving oil system.
    if (value == 'gravityFlip') return FoodAmbientVariant.continuousCirculation;
    return FoodAmbientVariant.values.firstWhere(
      (variant) => variant.name == value,
      orElse: () => FoodAmbientVariant.continuousCirculation,
    );
  }
}

abstract final class FoodAmbientPreference {
  static const _key = 'food.ambient.variant.v4';

  static Future<FoodAmbientVariant> load() async =>
      FoodAmbientVariant.fromPersistedName(
        (await SharedPreferences.getInstance()).getString(_key),
      );

  static Future<void> save(FoodAmbientVariant variant) async {
    await (await SharedPreferences.getInstance()).setString(_key, variant.name);
  }
}

@immutable
class OilTimerDrop {
  const OilTimerDrop({
    required this.id,
    required this.center,
    required this.radius,
    required this.color,
    required this.surfacePhase,
    required this.squashDirection,
    required this.squashStrength,
  });

  final int id;
  final Offset center;
  final double radius;
  final Color color;
  final double surfacePhase;
  final Offset squashDirection;
  final double squashStrength;
}

@immutable
class OilTimerFrame {
  const OilTimerFrame({
    required this.drops,
    this.collisionCount = 0,
    this.landingCount = 0,
    this.reboundCount = 0,
    this.sinkOutCount = 0,
    this.settlingDropCount = 0,
  });

  final List<OilTimerDrop> drops;
  final int collisionCount;
  final int landingCount;
  final int reboundCount;
  final int sinkOutCount;
  final int settlingDropCount;
}

enum _OilTravelState {
  descending,
  settling,
  sinkOut,
  offscreenReturn,
  entering,
}

class _OilDropState {
  _OilDropState({
    required this.id,
    required this.center,
    required this.velocity,
    required this.radius,
    required this.color,
    required this.entryX,
  });

  final int id;
  Offset center;
  Offset velocity;
  final double radius;
  final Color color;
  final double entryX;
  _OilTravelState state = _OilTravelState.descending;
  Offset returnLane = Offset.zero;
  int routeSegment = 0;
  double compression = 0;
  Offset compressionNormal = const Offset(1, 0);
  double settleAge = 0;
  double settleDuration = 0;
  double exitProgress = 0;
  Offset stableFloorPosition = Offset.zero;
}

/// Stateful, fixed-step oil dynamics. The controller is only a repaint clock;
/// no visible position is derived from a wrapped animation phase.
class OilTimerSimulation {
  OilTimerSimulation(Size size) : _size = Size.zero {
    if (size != Size.zero) _reset(size);
  }

  static const dropCount = 18;
  static const _dt = 1 / 60;
  static const _palette = <Color>[
    Color(0xff32ddd0),
    Color(0xff438cff),
    Color(0xff8f70ff),
    Color(0xffed5fbb),
    Color(0xffff8db5),
  ];

  Size _size;
  final List<_OilDropState> _drops = [];
  double _accumulator = 0;
  double _elapsed = 0;
  double _lastObservedSeconds = 0;
  int collisionCount = 0;
  int landingCount = 0;
  int reboundCount = 0;
  int sinkOutCount = 0;

  OilTimerFrame advanceTo(double seconds, Size size) {
    if (size != _size) _reset(size);
    final delta = (seconds - _lastObservedSeconds).clamp(0.0, 4 * _dt);
    _lastObservedSeconds = seconds;
    _accumulator = math.min(_accumulator + delta, 4 * _dt);
    var steps = 0;
    while (_accumulator >= _dt && steps < 4) {
      _step(_dt);
      _accumulator -= _dt;
      steps++;
    }
    return _frame();
  }

  void advanceForTest(double seconds) {
    final steps = (seconds / _dt).floor();
    for (var step = 0; step < steps; step++) {
      _step(_dt);
    }
    final remainder = seconds - steps * _dt;
    if (remainder > 0) _step(remainder);
  }

  OilTimerFrame snapshot() => _frame();

  void _reset(Size size) {
    _size = size;
    _drops.clear();
    _accumulator = 0;
    _elapsed = 0;
    _lastObservedSeconds = 0;
    collisionCount = 0;
    landingCount = 0;
    reboundCount = 0;
    sinkOutCount = 0;
    final min = size.shortestSide;
    for (var index = 0; index < dropCount; index++) {
      final h = OilTimerMotion.hash(index, 13);
      final xSeed = (index * .61803398875 + OilTimerMotion.hash(index, 31)) % 1;
      final radius = min * (.032 + .050 * h);
      _drops.add(
        _OilDropState(
          id: index,
          center: Offset(
            radius + 8 + xSeed * math.max(1, size.width - 2 * radius - 16),
            size.height * (-.25 + OilTimerMotion.hash(index, 19) * 1.35),
          ),
          velocity: Offset(
            (OilTimerMotion.hash(index, 23) - .5) * 12,
            28 + OilTimerMotion.hash(index, 29) * 32,
          ),
          radius: radius,
          color: _palette[index % _palette.length],
          entryX:
              radius +
              8 +
              OilTimerMotion.hash(index, 37) *
                  math.max(1, size.width - 2 * radius - 16),
        ),
      );
    }
  }

  void _step(double dt) {
    final floor = _size.height - math.max(16, _size.height * .06);
    for (final drop in _drops) {
      drop.compression *= math.exp(-dt / .30);
      if (drop.state == _OilTravelState.descending ||
          drop.state == _OilTravelState.entering) {
        final ax = 12 * math.sin(.35 * _elapsed + .9 * drop.id);
        final vx = ((drop.velocity.dx + ax * dt) * math.exp(-1.8 * dt)).clamp(
          -22.0,
          22.0,
        );
        final vy = math.min(90.0, drop.velocity.dy + 65 * dt);
        drop.velocity = Offset(vx, vy);
        drop.center += drop.velocity * dt;
        if (drop.center.dx - drop.radius < 0 ||
            drop.center.dx + drop.radius > _size.width) {
          final x = drop.center.dx.clamp(
            drop.radius,
            _size.width - drop.radius,
          );
          drop.center = Offset(x, drop.center.dy);
          drop.velocity = Offset(-drop.velocity.dx * .65, drop.velocity.dy);
        }
        if (drop.state == _OilTravelState.entering &&
            drop.center.dy - drop.radius >= 0) {
          drop.state = _OilTravelState.descending;
        }
        if (drop.center.dy + drop.radius >= floor) {
          _landOnFloor(drop, floor);
        }
      } else if (drop.state == _OilTravelState.settling) {
        _advanceSettling(drop, dt, floor);
      } else if (drop.state == _OilTravelState.sinkOut) {
        _advanceSinkOut(drop, dt);
      } else if (drop.state == _OilTravelState.offscreenReturn) {
        _advanceReturn(drop, dt);
      } else {
        _advanceReturn(drop, dt);
      }
    }
    _solveContacts(dt);
    _elapsed += dt;
  }

  void _landOnFloor(_OilDropState drop, double floor) {
    drop.center = Offset(drop.center.dx, floor - drop.radius);
    final incoming = drop.velocity.dy;
    drop.velocity = Offset(drop.velocity.dx * .46, -incoming.abs() * .18);
    drop.state = _OilTravelState.settling;
    drop.settleAge = 0;
    drop.settleDuration = 2.5 + OilTimerMotion.hash(drop.id, 53) * 2;
    drop.stableFloorPosition = drop.center;
    landingCount++;
  }

  void _advanceSettling(_OilDropState drop, double dt, double floor) {
    drop.settleAge += dt;
    final sway = math.sin(_elapsed * 1.4 + drop.id * .91) * 2;
    final vx = (drop.velocity.dx * math.exp(-dt * 4)).clamp(-8.0, 8.0);
    final vy = drop.velocity.dy + 65 * dt;
    drop.velocity = Offset(vx, vy);
    drop.center += drop.velocity * dt;
    if (drop.center.dy + drop.radius >= floor) {
      drop.center = Offset(
        (drop.stableFloorPosition.dx + sway).clamp(
          drop.radius,
          _size.width - drop.radius,
        ),
        floor - drop.radius,
      );
      if (drop.velocity.dy > 1.2) {
        drop.velocity = Offset(drop.velocity.dx, -drop.velocity.dy * .18);
        reboundCount++;
      } else {
        drop.velocity = Offset(drop.velocity.dx, 0);
      }
    }
    if (drop.settleAge >= drop.settleDuration) {
      drop.state = _OilTravelState.sinkOut;
      drop.exitProgress = 0;
      drop.velocity = Offset(
        drop.velocity.dx * .35,
        math.max(12, drop.velocity.dy),
      );
      sinkOutCount++;
    }
  }

  void _advanceSinkOut(_OilDropState drop, double dt) {
    drop.exitProgress += dt / (1.2 + OilTimerMotion.hash(drop.id, 59) * .6);
    final vy = math.min(90.0, drop.velocity.dy + 65 * dt);
    drop.velocity = Offset(drop.velocity.dx * math.exp(-dt * 2), vy);
    drop.center += drop.velocity * dt;
    if (drop.center.dy - drop.radius > _size.height + 8) {
      final side = drop.id.isEven ? -1.0 : 1.0;
      drop.returnLane = Offset(
        side < 0 ? -drop.radius - 24 : _size.width + drop.radius + 24,
        _size.height + drop.radius + 18,
      );
      drop.routeSegment = 0;
      drop.state = _OilTravelState.offscreenReturn;
    }
  }

  void _advanceReturn(_OilDropState drop, double dt) {
    final top = -drop.radius - 18;
    final targets = [
      drop.returnLane,
      Offset(drop.returnLane.dx, top),
      Offset(drop.entryX, top),
    ];
    var remaining = 110 * dt;
    while (remaining > 0 && drop.routeSegment < targets.length) {
      final target = targets[drop.routeSegment];
      final delta = target - drop.center;
      final distance = delta.distance;
      if (distance <= remaining || distance < .01) {
        drop.center = target;
        remaining -= distance;
        drop.routeSegment++;
      } else {
        drop.center += delta / distance * remaining;
        remaining = 0;
      }
    }
    if (drop.routeSegment >= targets.length) {
      drop.state = _OilTravelState.entering;
      drop.velocity = Offset(0, 24 + OilTimerMotion.hash(drop.id, 41) * 18);
    }
  }

  void _solveContacts(double dt) {
    for (var iteration = 0; iteration < 2; iteration++) {
      for (var first = 0; first < _drops.length - 1; first++) {
        final a = _drops[first];
        if (!_isContacting(a)) continue;
        for (var second = first + 1; second < _drops.length; second++) {
          final b = _drops[second];
          if (!_isContacting(b)) continue;
          final delta = b.center - a.center;
          final distance = math.max(.001, delta.distance);
          final limit = a.radius + b.radius;
          if (distance >= limit) continue;
          final normal = delta / distance;
          final overlap = limit - distance;
          final ma = a.radius * a.radius;
          final mb = b.radius * b.radius;
          final inverseMass = 1 / ma + 1 / mb;
          a.center -= normal * (overlap * (1 / ma / inverseMass) * .82);
          b.center += normal * (overlap * (1 / mb / inverseMass) * .82);
          final relative =
              (b.velocity - a.velocity).dx * normal.dx +
              (b.velocity - a.velocity).dy * normal.dy;
          if (relative < 0) {
            final impulse = -(1 + .42) * relative / inverseMass;
            a.velocity -= normal * (impulse / ma);
            b.velocity += normal * (impulse / mb);
            final tangent = Offset(-normal.dy, normal.dx);
            final tangentSpeed =
                (b.velocity - a.velocity).dx * tangent.dx +
                (b.velocity - a.velocity).dy * tangent.dy;
            final friction = tangentSpeed * .08 / inverseMass;
            a.velocity += tangent * (friction / ma);
            b.velocity -= tangent * (friction / mb);
          }
          final compression = math.min(
            .32,
            .12 + .35 * overlap / math.min(a.radius, b.radius),
          );
          a.compression = math.max(a.compression, compression);
          b.compression = math.max(b.compression, compression);
          a.compressionNormal = -normal;
          b.compressionNormal = normal;
          if (iteration == 0) collisionCount++;
        }
      }
    }
  }

  bool _isContacting(_OilDropState drop) =>
      drop.state == _OilTravelState.descending ||
      drop.state == _OilTravelState.settling;

  OilTimerFrame _frame() => OilTimerFrame(
    drops: [
      for (final drop in _drops)
        OilTimerDrop(
          id: drop.id,
          center: drop.center,
          radius: drop.radius,
          color: drop.color,
          surfacePhase: _elapsed * .32 + drop.id * .71,
          squashDirection: drop.compressionNormal,
          squashStrength: drop.compression,
        ),
    ],
    collisionCount: collisionCount,
    landingCount: landingCount,
    reboundCount: reboundCount,
    sinkOutCount: sinkOutCount,
    settlingDropCount: _drops
        .where((drop) => drop.state == _OilTravelState.settling)
        .length,
  );
}

abstract final class OilTimerMotion {
  static OilTimerFrame continuousCirculationFrame(Size size, double seconds) {
    final simulation = OilTimerSimulation(size);
    simulation.advanceForTest(seconds);
    return simulation.snapshot();
  }

  static double hash(int a, int b) =>
      (math.sin(a * 12.9898 + b * 78.233) * 43758.5453).abs() % 1;
}

class FoodAmbientComparison extends StatefulWidget {
  const FoodAmbientComparison({
    required this.variant,
    this.debugTime,
    super.key,
  });
  final FoodAmbientVariant variant;
  final double? debugTime;
  static double motionSignatureFor(FoodAmbientVariant v, double t) =>
      math.sin(t * (v.index + 1.17)) + math.cos(t * (v.index + .43));
  @override
  State<FoodAmbientComparison> createState() => _FoodAmbientComparisonState();
}

class _FoodAmbientComparisonState extends State<FoodAmbientComparison>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 48),
  )..repeat();
  final Stopwatch _worldClock = Stopwatch()..start();
  final OilTimerSimulation _circulation = OilTimerSimulation(Size.zero);
  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, child) => LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final seconds =
                widget.debugTime ??
                _worldClock.elapsedMicroseconds /
                    Duration.microsecondsPerSecond;
            final frame =
                widget.variant == FoodAmbientVariant.continuousCirculation
                ? (widget.debugTime == null
                      ? _circulation.advanceTo(seconds, size)
                      : OilTimerMotion.continuousCirculationFrame(
                          size,
                          seconds,
                        ))
                : null;
            return CustomPaint(
              painter: _FoodAmbientPainter(widget.variant, seconds, frame),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    ),
  );
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
    final c = Theme.of(context).colorScheme;
    return Semantics(
      label: 'FOOD ambient comparison',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.outline.withValues(alpha: .35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in FoodAmbientVariant.values)
                ActionableFeedbackRegion(
                  role: ActionableFeedbackRole.silent,
                  child: ChoiceChip(
                    key: ValueKey('food-ambient-${v.name}'),
                    label: Text(v.label),
                    selected: v == selected,
                    onSelected: (_) {
                      if (v == selected) return;
                      GlobalTouchRipple.previewFeedback(
                        TouchFeedbackSound.cursor,
                      );
                      onChanged(v);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodAmbientPainter extends CustomPainter {
  const _FoodAmbientPainter(this.variant, this.t, this.circulationFrame);
  final FoodAmbientVariant variant;
  final double t;
  final OilTimerFrame? circulationFrame;

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xff05080d));
    switch (variant) {
      case FoodAmbientVariant.continuousCirculation:
        _oilTimer(c, s, circulationFrame!);
      case FoodAmbientVariant.metabolicCells:
        _restoredCells(c, s);
      case FoodAmbientVariant.thermalCurrent:
        _thermal(c, s);
    }
  }

  void _oilTimer(Canvas c, Size s, OilTimerFrame frame) {
    _waterParticles(c, s);
    final viewport = (Offset.zero & s).inflate(s.shortestSide * .12);
    for (final drop in frame.drops) {
      if (!viewport.contains(drop.center)) continue;
      final path = _smoothOrganicPath(
        drop.center,
        drop.radius,
        drop.surfacePhase,
        drop.id,
        22,
        .050,
        contactDirection: drop.squashDirection,
        contactStrength: drop.squashStrength,
      );
      final bounds = path.getBounds();
      c.drawPath(path, Paint()..color = drop.color.withValues(alpha: .07));
      c.save();
      c.clipPath(path);
      c.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              -.24 + math.sin(drop.surfacePhase) * .08,
              -.30 + math.cos(drop.surfacePhase * .7) * .06,
            ),
            radius: 1.05,
            colors: [
              Color.lerp(drop.color, Colors.white, .42)!.withValues(alpha: .48),
              drop.color.withValues(alpha: .36),
              Color.lerp(
                drop.color,
                const Color(0xff071522),
                .58,
              )!.withValues(alpha: .26),
              drop.color.withValues(alpha: .08),
            ],
            stops: const [0, .30, .70, 1],
          ).createShader(bounds),
      );
      c.restore();
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .9
          ..color = Color.lerp(
            drop.color,
            Colors.white,
            .42,
          )!.withValues(alpha: .42),
      );
    }
  }

  void _waterParticles(Canvas c, Size s) {
    for (var index = 0; index < 14; index++) {
      final seed = _h(index, 67);
      final travel = (t * (.018 + seed * .012) + seed) % 1;
      final center = Offset(
        s.width * (.06 + seed * .88) +
            math.sin(travel * math.pi * 2 + index) * 5,
        s.height * (1.10 - travel * 1.22),
      );
      final radius = 1.6 + seed * 3.5;
      final opacity = math.sin(math.pi * travel) * (.13 + seed * .13);
      c.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65
          ..color = const Color(0xffa6f7ff).withValues(alpha: opacity),
      );
      c.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -2.6,
        1.0,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: opacity * .8),
      );
    }

    // Sparse light points remain a separate, quieter support layer from the
    // transparent bubbles above.
    for (var index = 0; index < 18; index++) {
      final seed = _h(index, 173);
      final travel = (t * (.026 + seed * .018) + seed * .73) % 1;
      final position = Offset(
        s.width * (.04 + seed * .92) +
            math.sin(travel * math.pi * 2 + seed) * 5,
        s.height * (1.08 - travel * 1.16),
      );
      final edgeFade = math.sin(math.pi * travel).clamp(0.0, 1.0);
      final color = Color.lerp(const Color(0xFF78E8FF), Colors.white, seed)!;
      c.drawCircle(
        position,
        .45 + seed * .75,
        Paint()..color = color.withValues(alpha: .12 * edgeFade),
      );
    }
  }

  void _restoredCells(Canvas c, Size s) {
    // f8d5faf3 supplied the restrained membrane palette and breathing
    // character. V4.1 intentionally replaces its grid with cached, seeded
    // dart-thrown positions so a screenshot reads as a cell population.
    const palette = [Color(0xff55d5c0), Color(0xff74a4ff), Color(0xffd184c7)];
    for (final cell in _cellsFor(s)) {
      final phase = cell.phase;
      final driftPeriod = 16 + _h(cell.id, 241) * 19;
      final breathPeriod = 7 + _h(cell.id, 251) * 6;
      final center = Offset(
        (cell.x + .025 * math.sin(math.pi * 2 * t / driftPeriod + phase)) *
            s.width,
        (cell.y +
                .020 *
                    math.cos(
                      math.pi * 2 * t / (driftPeriod * .87) + phase * 1.3,
                    )) *
            s.height,
      );
      final radius =
          cell.radius *
          (.90 + .10 * math.sin(math.pi * 2 * t / breathPeriod + phase));
      final color = palette[cell.id % palette.length];
      final membrane = _smoothOrganicPath(
        center,
        radius,
        phase + math.pi * 2 * t / (10 + _h(cell.id, 257) * 3),
        cell.id,
        24,
        .045,
      );
      final bounds = membrane.getBounds();
      c.save();
      c.clipPath(membrane);
      // Cytoplasm stays translucent and non-uniform instead of becoming an
      // oil sphere: a broad fill plus two quiet internal regions.
      c.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.22, -.18),
            colors: [
              Color.lerp(color, Colors.white, .30)!.withValues(alpha: .16),
              color.withValues(alpha: .15),
              color.withValues(alpha: .05),
              color.withValues(alpha: 0),
            ],
            stops: const [0, .38, .78, 1],
          ).createShader(bounds),
      );
      for (var region = 0; region < 2; region++) {
        final regionAngle = phase + region * 2.73 + t / (20 + region * 5);
        final regionCenter =
            center +
            Offset(math.cos(regionAngle), math.sin(regionAngle)) * radius * .42;
        c.drawOval(
          Rect.fromCenter(
            center: regionCenter,
            width: radius * (.42 + region * .08),
            height: radius * (.26 + region * .05),
          ),
          Paint()..color = color.withValues(alpha: .07 + region * .04),
        );
      }
      final nucleusAngle =
          phase * 1.7 + math.pi * 2 * t / (9 + _h(cell.id, 263) * 9);
      final nucleusCenter =
          center +
          Offset(math.cos(nucleusAngle), math.sin(nucleusAngle)) *
              radius *
              (.12 + cell.nucleusOffset * .13);
      final nucleusRadius = radius * (.25 + cell.nucleusOffset * .08);
      final nucleus = Rect.fromCircle(
        center: nucleusCenter,
        radius: nucleusRadius,
      );
      c.drawOval(
        nucleus,
        Paint()
          ..color = Color.lerp(
            color,
            const Color(0xff12172a),
            .66,
          )!.withValues(alpha: .52),
      );
      c.drawOval(
        nucleus,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .75
          ..color = Color.lerp(
            color,
            Colors.white,
            .25,
          )!.withValues(alpha: .42),
      );
      c.drawCircle(
        nucleusCenter + Offset(nucleusRadius * .22, -nucleusRadius * .18),
        radius * (.08 + cell.nucleusOffset * .03),
        Paint()..color = Colors.white.withValues(alpha: .68),
      );
      for (var organelle = 0; organelle < 3 + cell.id % 4; organelle++) {
        final angle =
            phase + organelle * 2.21 + t / (24 + organelle * 4 + cell.id % 3);
        final localRadius = radius * (.46 + (organelle % 3) * .08);
        final position =
            center +
            Offset(math.cos(angle), math.sin(angle) * .72) * localRadius;
        // Keep organelles recognizably cytoplasmic rather than over the
        // nucleus, while their independent phase gives the cell life.
        if ((position - nucleusCenter).distance < nucleusRadius * 1.15) {
          continue;
        }
        c.drawOval(
          Rect.fromCenter(
            center: position,
            width: radius * (.05 + (organelle % 2) * .035),
            height: radius * (.035 + (organelle % 3) * .018),
          ),
          Paint()
            ..color = Color.lerp(
              color,
              Colors.white,
              .18,
            )!.withValues(alpha: .16 + (organelle % 2) * .05),
        );
      }
      c.restore();
      // The two membrane outlines make the boundary legible at phone scale.
      c.drawPath(
        membrane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = Color.lerp(
            color,
            Colors.white,
            .25,
          )!.withValues(alpha: .22),
      );
      c.drawPath(
        membrane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25
          ..color = Color.lerp(
            color,
            Colors.white,
            .34,
          )!.withValues(alpha: .36),
      );
    }
  }

  static final Map<String, List<_CellSeed>> _cellLayouts = {};

  List<_CellSeed> _cellsFor(Size size) {
    final key = '${size.width.round()}x${size.height.round()}';
    return _cellLayouts.putIfAbsent(key, () {
      final min = size.shortestSide;
      final target = (26 * size.width * size.height / (390 * 844))
          .round()
          .clamp(14, 38);
      final cells = <_CellSeed>[];
      for (var attempt = 0; attempt < 400 && cells.length < target; attempt++) {
        final id = attempt;
        final radius = min * (.035 + .050 * _h(id, 211));
        final candidate = _CellSeed(
          id: id,
          x: .06 + .88 * _h(id, 223),
          y: .05 + .90 * _h(id, 227),
          radius: radius,
          phase: _h(id, 229) * math.pi * 2,
          nucleusOffset: _h(id, 233),
        );
        final valid = cells.every((other) {
          final dx = (candidate.x - other.x) * size.width;
          final dy = (candidate.y - other.y) * size.height;
          return math.sqrt(dx * dx + dy * dy) >=
              .75 * (candidate.radius + other.radius);
        });
        if (valid) cells.add(candidate);
      }
      return cells;
    });
  }

  void _thermal(Canvas c, Size s) {
    for (var i = 0; i < 7; i++) {
      final seed = _h(i, 77), q = t * (.28 + seed * .14) + i;
      final x = s.width * (.05 + .9 * _h(i, 81));
      final pts = <Offset>[];
      for (var j = 0; j < 17; j++) {
        final u = j / 16;
        pts.add(
          Offset(
            x + s.width * (.07 + seed * .06) * math.sin(q + u * 5),
            s.height * (1.04 - u * (.62 + seed * .2)),
          ),
        );
      }
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final z in pts) {
        p.lineTo(z.dx + 18 * (1 - z.dy / s.height), z.dy);
      }
      for (final z in pts.reversed) {
        p.lineTo(z.dx - 18 * (1 - z.dy / s.height), z.dy);
      }
      p.close();
      final col = [
        const Color(0xffffb45f),
        const Color(0xffff704e),
        const Color(0xffe94d70),
      ][i % 3];
      c.drawPath(
        p,
        Paint()
          ..color = col.withValues(alpha: .055)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      final core = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final z in pts.skip(1)) {
        core.lineTo(z.dx, z.dy);
      }
      c.drawPath(
        core,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.5 + seed
          ..color = col.withValues(alpha: .3),
      );
      for (var k = 0; k < 4; k++) {
        final u = (t * (.24 + seed * .14) + k * .27) % 1;
        final z = pts[(u * 16).floor()];
        c.drawCircle(z, 1.5, Paint()..color = col.withValues(alpha: .5));
      }
    }
  }

  Path _smoothOrganicPath(
    Offset o,
    double r,
    double q,
    int seed,
    int n,
    double d, {
    double x = 1,
    double y = 1,
    Offset? contactDirection,
    double contactStrength = 0,
  }) {
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final w =
          1 +
          d *
              (.58 * math.sin(a * 3 + q + seed) +
                  .3 * math.sin(a * 7 - q * .7)) -
          contactStrength *
              math.max(
                0,
                math.cos(
                  a -
                      math.atan2(
                        contactDirection?.dy ?? 0,
                        contactDirection?.dx ?? 1,
                      ),
                ),
              ) +
          contactStrength *
              .12 *
              math.max(
                0,
                math
                    .sin(
                      a -
                          math.atan2(
                            contactDirection?.dy ?? 0,
                            contactDirection?.dx ?? 1,
                          ),
                    )
                    .abs(),
              );
      points.add(
        Offset(o.dx + math.cos(a) * r * w * x, o.dy + math.sin(a) * r * w * y),
      );
    }
    final p = Path();
    final start = Offset(
      (points.last.dx + points.first.dx) / 2,
      (points.last.dy + points.first.dy) / 2,
    );
    p.moveTo(start.dx, start.dy);
    for (var i = 0; i < points.length; i++) {
      final previous = points[(i - 1 + points.length) % points.length];
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      final tangent = next - previous;
      p.cubicTo(
        current.dx - tangent.dx * .12,
        current.dy - tangent.dy * .12,
        current.dx + tangent.dx * .12,
        current.dy + tangent.dy * .12,
        mid.dx,
        mid.dy,
      );
    }
    return p..close();
  }

  double _h(int a, int b) =>
      (math.sin(a * 12.9898 + b * 78.233) * 43758.5453).abs() % 1;
  @override
  bool shouldRepaint(covariant _FoodAmbientPainter old) =>
      old.variant != variant ||
      old.t != t ||
      old.circulationFrame != circulationFrame;
}

class _CellSeed {
  const _CellSeed({
    required this.id,
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.nucleusOffset,
  });

  final int id;
  final double x;
  final double y;
  final double radius;
  final double phase;
  final double nucleusOffset;
}
