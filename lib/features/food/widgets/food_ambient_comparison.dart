import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';

enum FoodAmbientVariant {
  chromaticFluid('CHROMATIC FLUID'),
  metabolicCells('METABOLIC CELLS'),
  thermalCurrent('THERMAL CURRENT');

  const FoodAmbientVariant(this.label);
  final String label;
}

enum ChromaticFluidDropSize { large, medium, small }

@immutable
class ChromaticFluidDrop {
  const ChromaticFluidDrop({
    required this.id,
    required this.center,
    required this.radius,
    required this.baseRadius,
    required this.color,
    required this.size,
    required this.surfacePhase,
    this.absorption = 0,
    this.hostId,
  });

  final int id;
  final Offset center;
  final double radius;
  final double baseRadius;
  final Color color;
  final ChromaticFluidDropSize size;
  final double surfacePhase;
  final double absorption;
  final int? hostId;
}

@immutable
class ChromaticFluidContact {
  const ChromaticFluidContact({
    required this.first,
    required this.second,
    required this.strength,
  });

  final ChromaticFluidDrop first;
  final ChromaticFluidDrop second;
  final double strength;

  Color get mixedColor => Color.lerp(first.color, second.color, .5)!;

  Offset get center => Offset.lerp(
    first.center,
    second.center,
    first.radius / (first.radius + second.radius),
  )!;

  double get radius =>
      math.min(first.radius, second.radius) * (.34 + strength * .48);
}

@immutable
class ChromaticFluidFrame {
  const ChromaticFluidFrame({
    required this.drops,
    required this.contacts,
    required this.particles,
  });

  final List<ChromaticFluidDrop> drops;
  final List<ChromaticFluidContact> contacts;
  final List<ChromaticFluidParticle> particles;
}

@immutable
class ChromaticFluidParticle {
  const ChromaticFluidParticle({
    required this.center,
    required this.radius,
    required this.color,
    required this.opacity,
    required this.isBubble,
  });

  final Offset center;
  final double radius;
  final Color color;
  final double opacity;
  final bool isBubble;
}

@immutable
class ChromaticFluidFieldContour {
  const ChromaticFluidFieldContour({
    required this.path,
    required this.bounds,
    required this.dropIds,
    required this.pointCount,
    required this.samplePoints,
  });

  final Path path;
  final Rect bounds;
  final Set<int> dropIds;
  final int pointCount;
  final List<Offset> samplePoints;
}

@immutable
class ChromaticFluidField {
  const ChromaticFluidField({
    required this.contours,
    required this.sampleCount,
    required this.groupCount,
  });

  final List<ChromaticFluidFieldContour> contours;
  final int sampleCount;
  final int groupCount;
}

class _ChromaticFluidFieldSource {
  const _ChromaticFluidFieldSource({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.cosRotation,
    required this.sinRotation,
    required this.weight,
  });

  final Offset center;
  final double radiusX;
  final double radiusY;
  final double cosRotation;
  final double sinRotation;
  final double weight;
}

typedef _ChromaticFluidFieldNode = (int orientation, int x, int y);

/// Deterministic, bounded implicit-field geometry for Chromatic Fluid V3.
///
/// Nearby drops are linked dynamically into bounded local field groups. A
/// smooth iso-contour is extracted from the summed scalar surface, so every
/// approach, merge, absorption, split, and pinch-off comes from one field
/// instead of from fixed pair connectors.
abstract final class ChromaticFluidMetaballs {
  static const dropCount = 12;
  static const maximumContactCount = 5;
  static const maximumFieldGroupCount = 12;
  static const maximumFieldSampleCount = 18000;
  static const cycleSeconds = 24.0;
  static const fieldIsoValue = 1.0;
  static const _palette = <Color>[
    Color(0xff32ddd0),
    Color(0xff438cff),
    Color(0xff9368ff),
    Color(0xffed5fbb),
    Color(0xffff9b55),
    Color(0xff58d58a),
  ];

  static ChromaticFluidFrame frame(Size size, double seconds) {
    final shortest = size.shortestSide;
    final drops = <ChromaticFluidDrop>[];
    const majorAnchors = <Offset>[
      Offset(.20, .17),
      Offset(.72, .20),
      Offset(.32, .47),
      Offset(.73, .52),
      Offset(.18, .80),
      Offset(.69, .82),
    ];
    const majorRadii = <double>[.142, .086, .126, .076, .136, .082];

    for (var id = 0; id < majorAnchors.length; id++) {
      final phase = seconds * (.105 + id * .009) + id * 1.41;
      final anchor = majorAnchors[id];
      final center = Offset(
        size.width * anchor.dx +
            math.sin(phase * .91) * (24 + (id % 3) * 8) +
            math.cos(phase * .37 + id) * 13,
        size.height * anchor.dy +
            math.cos(phase * .73) * (31 + (id % 2) * 10) +
            math.sin(phase * .41 + id) * 16,
      );
      final baseRadius = shortest * majorRadii[id];
      // Alternating currents gather a changing local triad without assigning
      // any contact pair in advance. The field still decides whether the
      // neighbouring drops actually merge at this phase.
      final triadPhase = seconds * .13 + (id.isEven ? 0 : math.pi);
      final triadPull = _smoothStep(
        ((.5 + .5 * math.sin(triadPhase) - .70) / .30).clamp(0.0, 1.0),
      );
      final triadIndex = id ~/ 2;
      final triadCenter = Offset(
        size.width * (id.isEven ? .41 : .63) + math.sin(seconds * .07) * 18,
        size.height * (.48 + math.cos(seconds * .06) * .12),
      );
      final gatheredCenter =
          triadCenter +
          Offset.fromDirection(triadIndex * math.pi * 2 / 3 + seconds * .11) *
              baseRadius *
              .30;
      drops.add(
        ChromaticFluidDrop(
          id: id,
          center: Offset.lerp(center, gatheredCenter, triadPull)!,
          radius: baseRadius,
          baseRadius: baseRadius,
          color: _palette[id],
          size: id.isEven
              ? ChromaticFluidDropSize.large
              : ChromaticFluidDropSize.medium,
          surfacePhase: seconds * (.31 + id * .018) + id * 1.23,
        ),
      );
    }

    const smallAnchors = <Offset>[
      Offset(.09, .10),
      Offset(.80, .16),
      Offset(.12, .43),
      Offset(.89, .67),
      Offset(.16, .91),
      Offset(.76, .90),
    ];
    for (var i = 0; i < smallAnchors.length; i++) {
      final phase = seconds * (.15 + i * .012) + i * 1.47;
      final anchor = smallAnchors[i];
      final freeCenter = Offset(
        size.width * anchor.dx + math.sin(phase * .83) * (13 + i % 3 * 4),
        size.height * anchor.dy + math.cos(phase * .67) * (16 + i % 2 * 5),
      );
      final host = drops
          .where((drop) => drop.size != ChromaticFluidDropSize.small)
          .reduce(
            (nearest, candidate) =>
                (candidate.center - freeCenter).distance <
                    (nearest.center - freeCenter).distance
                ? candidate
                : nearest,
          );
      final absorption = _smoothStep(
        ((.5 + .5 * math.sin(seconds * (.19 + i * .011) + i * 1.91)) - .44)
                .clamp(0.0, 1.0) /
            .56,
      );
      final direction = Offset.fromDirection(phase * .72 + i * .83);
      final hostPosition =
          host.center +
          direction * host.radius * (.20 + (1 - absorption) * .62);
      final center = Offset.lerp(freeCenter, hostPosition, absorption)!;
      final baseRadius = shortest * (.020 + (i % 3) * .008);
      drops.add(
        ChromaticFluidDrop(
          id: 6 + i,
          center: center,
          radius: baseRadius * (1 - absorption * .82),
          baseRadius: baseRadius,
          color: _palette[(i + 1) % _palette.length],
          size: ChromaticFluidDropSize.small,
          surfacePhase: phase,
          absorption: absorption,
          hostId: absorption > .02 ? host.id : null,
        ),
      );
    }

    final contacts = <ChromaticFluidContact>[];
    for (var firstIndex = 0; firstIndex < drops.length - 1; firstIndex++) {
      for (
        var secondIndex = firstIndex + 1;
        secondIndex < drops.length;
        secondIndex++
      ) {
        final first = drops[firstIndex];
        final second = drops[secondIndex];
        final normalizedDistance =
            (second.center - first.center).distance /
            (first.radius + second.radius);
        final strength = contactStrength(normalizedDistance);
        if (strength <= .005) continue;
        contacts.add(
          ChromaticFluidContact(
            first: first,
            second: second,
            strength: strength,
          ),
        );
      }
    }
    contacts.sort((first, second) => second.strength.compareTo(first.strength));
    return ChromaticFluidFrame(
      drops: List.unmodifiable(drops),
      contacts: List.unmodifiable(contacts.take(maximumContactCount)),
      particles: List.unmodifiable(_particles(size, seconds)),
    );
  }

  static List<ChromaticFluidParticle> _particles(Size size, double seconds) {
    const particleCount = 26;
    return List<ChromaticFluidParticle>.generate(particleCount, (index) {
      final speed = .030 + (index % 5) * .006;
      final progress = (seconds * speed + index * .173) % 1;
      final edgeFade = _smoothStep(
        math.min(progress / .13, (1 - progress) / .13),
      );
      final isBubble = index % 3 != 0;
      final radius = isBubble
          ? 1.4 + (index % 4) * .72
          : .55 + (index % 3) * .22;
      return ChromaticFluidParticle(
        center: Offset(
          size.width * (.06 + ((index * .371) % .88)) +
              math.sin(seconds * (.42 + index * .013) + index) * 7,
          size.height * (1.08 - progress * 1.20) +
              math.cos(seconds * (.31 + index * .017) + index) * 4,
        ),
        radius: radius,
        color: _palette[(index + 1) % _palette.length],
        opacity: edgeFade * (isBubble ? .20 : .25),
        isBubble: isBubble,
      );
    });
  }

  static double contactStrength(double normalizedDistance) {
    final raw = ((1.43 - normalizedDistance) / .82).clamp(0.0, 1.0);
    return _smoothStep(raw);
  }

  static double fieldSpacingFor(Size size) =>
      (size.shortestSide / 92).clamp(3.8, 5.2);

  static ChromaticFluidField buildField(
    Size size,
    ChromaticFluidFrame frame, {
    double? spacing,
  }) {
    final byId = {for (final drop in frame.drops) drop.id: drop};
    final parent = <int, int>{for (final id in byId.keys) id: id};
    int root(int id) {
      var current = id;
      while (parent[current] != current) {
        current = parent[current]!;
      }
      return current;
    }

    for (final contact in frame.contacts) {
      if (contact.strength < .025) continue;
      final firstRoot = root(contact.first.id);
      final secondRoot = root(contact.second.id);
      if (firstRoot != secondRoot) parent[secondRoot] = firstRoot;
    }
    final grouped = <int, List<ChromaticFluidDrop>>{};
    for (final drop in frame.drops) {
      grouped
          .putIfAbsent(root(drop.id), () => <ChromaticFluidDrop>[])
          .add(drop);
    }
    final groups = grouped.values.toList(growable: false);
    final contours = <ChromaticFluidFieldContour>[];
    var sampleCount = 0;
    final fieldSpacing = spacing ?? fieldSpacingFor(size);
    for (final group in groups) {
      // Small standalone drops need a denser *local* contour to remain
      // round rather than reading as a low-polygon background point.
      final localSpacing =
          group.every((drop) => drop.size == ChromaticFluidDropSize.small)
          ? fieldSpacing * .72
          : fieldSpacing;
      final result = _contoursForGroup(group, localSpacing);
      contours.addAll(result.$1);
      sampleCount += result.$2;
    }
    assert(groups.length <= maximumFieldGroupCount);
    assert(sampleCount <= maximumFieldSampleCount);
    return ChromaticFluidField(
      contours: List.unmodifiable(contours),
      sampleCount: sampleCount,
      groupCount: groups.length,
    );
  }

  static (List<ChromaticFluidFieldContour>, int) _contoursForGroup(
    List<ChromaticFluidDrop> drops,
    double spacing,
  ) {
    final sources = <_ChromaticFluidFieldSource>[
      for (final drop in drops) ..._sourcesFor(drop),
    ];
    var bounds = Rect.fromCircle(
      center: drops.first.center,
      radius: drops.first.radius * 1.5,
    );
    for (final drop in drops.skip(1)) {
      bounds = bounds.expandToInclude(
        Rect.fromCircle(center: drop.center, radius: drop.radius * 1.5),
      );
    }
    bounds = Rect.fromLTRB(
      (bounds.left / spacing).floor() * spacing,
      (bounds.top / spacing).floor() * spacing,
      (bounds.right / spacing).ceil() * spacing,
      (bounds.bottom / spacing).ceil() * spacing,
    );
    final columns = math.max(2, (bounds.width / spacing).ceil());
    final rows = math.max(2, (bounds.height / spacing).ceil());
    final values = List<double>.filled((columns + 1) * (rows + 1), 0);
    int valueIndex(int x, int y) => y * (columns + 1) + x;
    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x <= columns; x++) {
        values[valueIndex(x, y)] = _fieldValue(
          Offset(bounds.left + x * spacing, bounds.top + y * spacing),
          sources,
        );
      }
    }

    final positions = <_ChromaticFluidFieldNode, Offset>{};
    final neighbours =
        <_ChromaticFluidFieldNode, List<_ChromaticFluidFieldNode>>{};
    Offset edgePosition(
      _ChromaticFluidFieldNode node,
      Offset first,
      Offset second,
      double firstValue,
      double secondValue,
    ) {
      return positions.putIfAbsent(node, () {
        final denominator = secondValue - firstValue;
        final amount = denominator.abs() < .000001
            ? .5
            : ((fieldIsoValue - firstValue) / denominator).clamp(0.0, 1.0);
        return Offset.lerp(first, second, amount)!;
      });
    }

    void connect(
      _ChromaticFluidFieldNode first,
      _ChromaticFluidFieldNode second,
    ) {
      neighbours
          .putIfAbsent(first, () => <_ChromaticFluidFieldNode>[])
          .add(second);
      neighbours
          .putIfAbsent(second, () => <_ChromaticFluidFieldNode>[])
          .add(first);
    }

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final topLeft = values[valueIndex(x, y)];
        final topRight = values[valueIndex(x + 1, y)];
        final bottomRight = values[valueIndex(x + 1, y + 1)];
        final bottomLeft = values[valueIndex(x, y + 1)];
        final state =
            (topLeft >= fieldIsoValue ? 1 : 0) |
            (topRight >= fieldIsoValue ? 2 : 0) |
            (bottomRight >= fieldIsoValue ? 4 : 0) |
            (bottomLeft >= fieldIsoValue ? 8 : 0);
        if (state == 0 || state == 15) continue;
        final origin = Offset(
          bounds.left + x * spacing,
          bounds.top + y * spacing,
        );
        final points = <Offset>[
          origin,
          origin + Offset(spacing, 0),
          origin + Offset(spacing, spacing),
          origin + Offset(0, spacing),
        ];
        final edgeNodes = <_ChromaticFluidFieldNode>[
          (0, x, y),
          (1, x + 1, y),
          (0, x, y + 1),
          (1, x, y),
        ];
        final edgeValues = <(double, double)>[
          (topLeft, topRight),
          (topRight, bottomRight),
          (bottomLeft, bottomRight),
          (topLeft, bottomLeft),
        ];
        const edgePointIndexes = <(int, int)>[(0, 1), (1, 2), (3, 2), (0, 3)];
        _ChromaticFluidFieldNode node(int edge) {
          final valuePair = edgeValues[edge];
          final pointIndexes = edgePointIndexes[edge];
          edgePosition(
            edgeNodes[edge],
            points[pointIndexes.$1],
            points[pointIndexes.$2],
            valuePair.$1,
            valuePair.$2,
          );
          return edgeNodes[edge];
        }

        void add(int first, int second) => connect(node(first), node(second));
        switch (state) {
          case 1:
          case 14:
            add(3, 0);
            break;
          case 2:
          case 13:
            add(0, 1);
            break;
          case 3:
          case 12:
            add(3, 1);
            break;
          case 4:
          case 11:
            add(1, 2);
            break;
          case 6:
          case 9:
            add(0, 2);
            break;
          case 7:
          case 8:
            add(3, 2);
            break;
          case 5:
          case 10:
            final centerInside =
                (topLeft + topRight + bottomRight + bottomLeft) * .25 >=
                fieldIsoValue;
            if ((state == 5) == centerInside) {
              add(0, 1);
              add(2, 3);
            } else {
              add(3, 0);
              add(1, 2);
            }
            break;
          default:
            break;
        }
      }
    }

    String edgeId(
      _ChromaticFluidFieldNode first,
      _ChromaticFluidFieldNode second,
    ) {
      final firstText = '${first.$1}:${first.$2}:${first.$3}';
      final secondText = '${second.$1}:${second.$2}:${second.$3}';
      return firstText.compareTo(secondText) <= 0
          ? '$firstText|$secondText'
          : '$secondText|$firstText';
    }

    final visited = <String>{};
    final contours = <ChromaticFluidFieldContour>[];
    for (final start in neighbours.keys) {
      for (final firstStep in neighbours[start]!) {
        if (visited.contains(edgeId(start, firstStep))) continue;
        final points = <Offset>[positions[start]!];
        var previous = start;
        var current = firstStep;
        var closed = false;
        while (points.length <= neighbours.length + 1) {
          visited.add(edgeId(previous, current));
          if (current == start) {
            closed = true;
            break;
          }
          points.add(positions[current]!);
          final options = neighbours[current]!;
          final next = options.firstWhere(
            (candidate) => candidate != previous,
            orElse: () => previous,
          );
          if (next == previous) break;
          previous = current;
          current = next;
        }
        if (!closed || points.length < 8) continue;
        // Marching Squares can legitimately produce a compact eight-edge
        // loop for a tiny particle. Insert midpoint controls before the
        // cubic smoothing pass so that it keeps a rounded liquid silhouette
        // instead of exposing the coarse local sampling grid.
        final contourPoints = points.length < 12
            ? <Offset>[
                for (var index = 0; index < points.length; index++) ...[
                  points[index],
                  Offset.lerp(
                    points[index],
                    points[(index + 1) % points.length],
                    .5,
                  )!,
                ],
              ]
            : points;
        final path = _closedSmoothPath(contourPoints);
        contours.add(
          ChromaticFluidFieldContour(
            path: path,
            bounds: path.getBounds(),
            dropIds: Set.unmodifiable(drops.map((drop) => drop.id)),
            pointCount: contourPoints.length,
            samplePoints: List.unmodifiable(contourPoints),
          ),
        );
      }
    }
    return (contours, values.length);
  }

  static List<_ChromaticFluidFieldSource> _sourcesFor(ChromaticFluidDrop drop) {
    final shapePhase = drop.surfacePhase * .63 + drop.id * .71;
    final rotation = shapePhase * .37;
    final xScale = 1 + math.sin(shapePhase) * .052;
    final yScale = 1 + math.cos(shapePhase * .83) * .047;
    final lobeDirection = Offset.fromDirection(shapePhase * .71 + drop.id);
    return [
      _ChromaticFluidFieldSource(
        center: drop.center,
        radiusX: drop.radius * xScale,
        radiusY: drop.radius * yScale,
        cosRotation: math.cos(rotation),
        sinRotation: math.sin(rotation),
        weight: .90,
      ),
      _ChromaticFluidFieldSource(
        center: drop.center + lobeDirection * drop.radius * .18,
        radiusX: drop.radius * .57,
        radiusY: drop.radius * .48,
        cosRotation: math.cos(rotation + .8),
        sinRotation: math.sin(rotation + .8),
        weight: .18,
      ),
    ];
  }

  static double _fieldValue(
    Offset point,
    List<_ChromaticFluidFieldSource> sources,
  ) {
    var field = 0.0;
    for (final source in sources) {
      final delta = point - source.center;
      final localX =
          delta.dx * source.cosRotation + delta.dy * source.sinRotation;
      final localY =
          -delta.dx * source.sinRotation + delta.dy * source.cosRotation;
      final normalizedSquared =
          localX * localX / (source.radiusX * source.radiusX) +
          localY * localY / (source.radiusY * source.radiusY);
      field += source.weight / math.max(normalizedSquared, .0001);
    }
    return field;
  }

  static Path _closedSmoothPath(List<Offset> points) {
    final path = Path();
    final firstMidpoint = Offset.lerp(points.last, points.first, .5)!;
    path.moveTo(firstMidpoint.dx, firstMidpoint.dy);
    for (var index = 0; index < points.length; index++) {
      final previous = points[(index - 1 + points.length) % points.length];
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final midpoint = Offset.lerp(current, next, .5)!;
      final tangent = next - previous;
      path.cubicTo(
        current.dx - tangent.dx * .10,
        current.dy - tangent.dy * .10,
        current.dx + tangent.dx * .10,
        current.dy + tangent.dy * .10,
        midpoint.dx,
        midpoint.dy,
      );
    }
    return path..close();
  }

  static double _smoothStep(double value) => value * value * (3 - 2 * value);
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
        builder: (context, child) => CustomPaint(
          painter: _FoodAmbientPainter(
            widget.variant,
            widget.debugTime ?? _clock.value * 48,
          ),
          child: const SizedBox.expand(),
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
  const _FoodAmbientPainter(this.variant, this.t);
  final FoodAmbientVariant variant;
  final double t;
  static const _cool = [
    Color(0xff36d8ca),
    Color(0xffdc5bb3),
    Color(0xff886fff),
    Color(0xffffad61),
  ];
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xff05080d));
    switch (variant) {
      case FoodAmbientVariant.chromaticFluid:
        _fluid(c, s);
      case FoodAmbientVariant.metabolicCells:
        _cells(c, s);
      case FoodAmbientVariant.thermalCurrent:
        _thermal(c, s);
    }
  }

  void _fluid(Canvas c, Size s) {
    final frame = ChromaticFluidMetaballs.frame(s, t);
    final field = ChromaticFluidMetaballs.buildField(s, frame);
    final dropsById = {for (final drop in frame.drops) drop.id: drop};
    final viewport = Offset.zero & s;

    // The particle layer lives behind the field: it adds depth without
    // obscuring either the liquid contours or the FOOD foreground UI.
    for (final particle in frame.particles) {
      if (!viewport.inflate(particle.radius * 2).contains(particle.center)) {
        continue;
      }
      final rect = Rect.fromCircle(
        center: particle.center,
        radius: particle.radius * 1.8,
      );
      c.drawCircle(
        particle.center,
        particle.radius * 1.8,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: particle.opacity * .78),
              particle.color.withValues(alpha: particle.opacity * .54),
              particle.color.withValues(alpha: 0),
            ],
            stops: const [0, .38, 1],
          ).createShader(rect),
      );
      if (particle.isBubble) {
        c.drawCircle(
          particle.center,
          particle.radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .55
            ..color = Color.lerp(
              particle.color,
              Colors.white,
              .55,
            )!.withValues(alpha: particle.opacity),
        );
      }
    }

    for (final contour in field.contours) {
      if (!contour.bounds.overlaps(viewport)) continue;
      final contourDrops = [for (final id in contour.dropIds) dropsById[id]!];
      final averageColor = contourDrops
          .map((drop) => drop.color)
          .reduce((first, second) => Color.lerp(first, second, .5)!);

      // Only the local contour is blurred. The viewport never enters an
      // offscreen layer and distant drops do not participate in this pass.
      c.drawPath(
        contour.path,
        Paint()
          ..color = averageColor.withValues(alpha: .09)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      c.save();
      c.clipPath(contour.path);
      c.drawRect(
        contour.bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x42102b48), Color(0x4813092f), Color(0x3c07372e)],
          ).createShader(contour.bounds),
      );

      if (contourDrops.length >= 2) {
        final ordered = [...contourDrops]
          ..sort((first, second) => first.id.compareTo(second.id));
        final first = ordered.first;
        final second = ordered.last;
        final mixed = ordered
            .skip(1)
            .fold(
              first.color,
              (color, drop) => Color.lerp(color, drop.color, .5)!,
            );
        final flow = .5 + .5 * math.sin(t * .33 + first.id * .7 + second.id);
        c.drawRect(
          contour.bounds,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset.lerp(first.center, second.center, .15 + flow * .18)!,
              Offset.lerp(second.center, first.center, .12 + flow * .16)!,
              [
                first.color.withValues(alpha: .42),
                Color.lerp(
                  mixed,
                  Colors.white,
                  .10,
                )!.withValues(alpha: .48 + contourDrops.length * .025),
                second.color.withValues(alpha: .42),
              ],
              [.0, .38 + flow * .20, 1],
            ),
        );
      } else {
        c.drawPath(
          contour.path,
          Paint()..color = averageColor.withValues(alpha: .34),
        );
      }

      for (final drop in contourDrops) {
        final flowCenter =
            drop.center +
            Offset(
                  math.cos(drop.surfacePhase * .73),
                  math.sin(drop.surfacePhase * .61),
                ) *
                drop.radius *
                .24;
        c.drawCircle(
          drop.center,
          drop.radius * 1.72,
          Paint()
            ..shader =
                RadialGradient(
                  center: const Alignment(-.24, -.28),
                  radius: 1,
                  colors: [
                    Color.lerp(
                      drop.color,
                      Colors.white,
                      .30,
                    )!.withValues(alpha: .27),
                    drop.color.withValues(alpha: .16),
                    Color.lerp(
                      drop.color,
                      const Color(0xff071522),
                      .50,
                    )!.withValues(alpha: .10),
                    drop.color.withValues(alpha: 0),
                  ],
                  stops: const [0, .38, .76, 1],
                ).createShader(
                  Rect.fromCircle(
                    center: drop.center,
                    radius: drop.radius * 1.72,
                  ),
                ),
        );

        // A rotating, soft anisotropic lobe gives the interior its own period,
        // independent from both centre translation and contour deformation.
        c.save();
        c.translate(flowCenter.dx, flowCenter.dy);
        c.rotate(drop.surfacePhase * .19 + drop.id * .37);
        final flowRect = Rect.fromCenter(
          center: Offset.zero,
          width: drop.radius * 1.34,
          height: drop.radius * .42,
        );
        c.drawOval(
          flowRect,
          Paint()
            ..shader = LinearGradient(
              colors: [
                drop.color.withValues(alpha: 0),
                Color.lerp(
                  drop.color,
                  Colors.white,
                  .42,
                )!.withValues(alpha: .14),
                drop.color.withValues(alpha: 0),
              ],
              stops: const [0, .52, 1],
            ).createShader(flowRect)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        );
        c.restore();
      }

      // Mixed colour is a local field around the saddle point. It is clipped
      // by the same iso-contour and contracts continuously as contact fades.
      for (final contact in frame.contacts) {
        if (!contour.dropIds.contains(contact.first.id) ||
            !contour.dropIds.contains(contact.second.id)) {
          continue;
        }
        final mixRadius =
            contact.radius * (1 + math.sin(t * .38 + contact.first.id) * .10);
        final mixCenter = Offset.lerp(
          contact.center,
          contact.first.center,
          .08 * math.sin(t * .41 + contact.second.id),
        )!;
        c.drawCircle(
          mixCenter,
          mixRadius,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    Color.lerp(
                      contact.mixedColor,
                      Colors.white,
                      .12,
                    )!.withValues(alpha: .18 + contact.strength * .28),
                    contact.mixedColor.withValues(
                      alpha: .10 + contact.strength * .17,
                    ),
                    contact.mixedColor.withValues(alpha: 0),
                  ],
                  stops: const [0, .54, 1],
                ).createShader(
                  Rect.fromCircle(center: mixCenter, radius: mixRadius),
                ),
        );
      }
      c.restore();
      c.drawPath(
        contour.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = Color.lerp(
            averageColor,
            Colors.white,
            .28,
          )!.withValues(alpha: .19),
      );
    }
  }

  void _cells(Canvas c, Size s) {
    final cells =
        <({Offset center, double radius, double phase, Color color})>[];
    for (var i = 0; i < 15; i++) {
      final seed = _h(i, 9);
      final q = t * (.23 + seed * .18) + i;
      final o = Offset(
        s.width * (.06 + .88 * _h(i, 11)) + 18 * math.sin(q * .7),
        s.height * (.05 + .9 * _h(i, 13)) + 20 * math.cos(q * .63),
      );
      final r = s.shortestSide * (.052 + seed * .072);
      final split = i % 5 == 0 ? math.sin(q * .36).abs() : 0.0;
      final col = _cool[i % 3];
      cells.add((center: o, radius: r, phase: q, color: col));
      final membrane = _smoothOrganicPath(
        o,
        r,
        q,
        i + 30,
        14,
        .16 + split * .09,
        x: 1 + split * .62,
        y: 1 - split * .24,
      );
      c.drawPath(membrane, Paint()..color = col.withValues(alpha: .07));
      c.drawPath(
        membrane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 + seed * .8
          ..color = Color.lerp(col, Colors.white, .30)!.withValues(alpha: .35),
      );
      c.drawPath(
        _smoothOrganicPath(o, r * .76, q + .55, i + 60, 14, .11),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .75
          ..color = col.withValues(alpha: .15),
      );
      c.drawCircle(
        o + Offset(math.cos(q * .8), math.sin(q * .67)) * r * .12,
        r * .30,
        Paint()
          ..color = Color.lerp(col, Colors.white, .22)!.withValues(alpha: .21)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      c.drawCircle(
        o + Offset(math.cos(q * .8), math.sin(q * .67)) * r * .12,
        r * .15,
        Paint()..color = col.withValues(alpha: .44),
      );
      for (var organelle = 0; organelle < 3; organelle++) {
        final a = q * (1.1 + organelle * .13) + organelle * 2.1;
        c.drawCircle(
          o + Offset(math.cos(a), math.sin(a)) * r * (.35 + organelle * .08),
          r * (.045 + organelle * .012),
          Paint()..color = col.withValues(alpha: .30),
        );
      }
      if (split > .45) {
        final d = Offset(math.cos(q), math.sin(q)) * r * split * .55;
        c.drawCircle(
          o - d,
          r * .13,
          Paint()..color = col.withValues(alpha: .4),
        );
        c.drawCircle(
          o + d,
          r * .13,
          Paint()..color = col.withValues(alpha: .4),
        );
      }
    }
    // Short-lived membrane bridges make local contacts read as a living
    // environment, instead of a uniform field of isolated outlines.
    for (var i = 0; i < cells.length - 1; i += 4) {
      final a = cells[i], b = cells[i + 1];
      final bridge = Path()
        ..moveTo(a.center.dx, a.center.dy)
        ..cubicTo(
          a.center.dx + (b.center.dx - a.center.dx) * .32,
          a.center.dy + 18 * math.sin(a.phase),
          b.center.dx - (b.center.dx - a.center.dx) * .30,
          b.center.dy - 18 * math.cos(b.phase),
          b.center.dx,
          b.center.dy,
        );
      c.drawPath(
        bridge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 + math.sin(t * .41 + i).abs() * 1.8
          ..color = Color.lerp(a.color, b.color, .5)!.withValues(alpha: .12),
      );
      final exchange = (t * (.18 + i * .006) + i * .17) % 1;
      final reaction =
          Offset.lerp(a.center, b.center, exchange)! +
          Offset(0, math.sin(exchange * math.pi * 2 + a.phase) * 7);
      c.drawCircle(
        reaction,
        2.2 + math.sin(exchange * math.pi).abs() * 1.8,
        Paint()
          ..color = Color.lerp(
            a.color,
            b.color,
            exchange,
          )!.withValues(alpha: .48)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    for (var i = 0; i < 30; i++) {
      final q = t * (.32 + _h(i, 33) * .2) + i;
      c.drawCircle(
        Offset(
          s.width * (.5 + .48 * math.sin(q)),
          s.height * (.5 + .46 * math.cos(q * .81)),
        ),
        1 + _h(i, 41) * 1.6,
        Paint()..color = _cool[i % 3].withValues(alpha: .26),
      );
    }
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
  }) {
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final w =
          1 +
          d *
              (.58 * math.sin(a * 3 + q + seed) +
                  .3 * math.sin(a * 7 - q * .7));
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
      old.variant != variant || old.t != t;
}
