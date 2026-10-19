import 'dart:math' as math;
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

/// Deterministic, bounded implicit-field geometry for Chromatic Fluid V3.6.
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
  // The controller already repeats every 48 seconds. Keeping the liquid on
  // that same cycle removes the former mid-controller rewind and gives a
  // complete approach/contact/separation enough time to read as material
  // motion rather than an accelerated pull.
  static const cycleSeconds = 48.0;
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
    final loop = _cycleAngle(seconds);
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
      // Independent slow orbit and gathering channels keep local contact from
      // looking like an accelerated pull into a shared centre.
      final phase = loop * (1 + id % 2) + id * 1.41;
      final anchor = majorAnchors[id];
      final center = Offset(
        size.width * anchor.dx +
            math.sin(phase) * (20 + (id % 3) * 7) +
            math.cos(loop * (2 + id % 2) + id) * 11,
        size.height * anchor.dy +
            math.cos(loop * (2 + id % 2) + id) * (26 + (id % 2) * 9) +
            math.sin(loop * (3 + id % 2) + id) * 13,
      );
      final baseRadius = shortest * majorRadii[id];
      // Alternating currents gather a changing local triad without assigning
      // any contact pair in advance. The field still decides whether the
      // neighbouring drops actually merge at this phase.
      final triadPhase = loop * (1 + id % 2) + (id.isEven ? 0 : math.pi);
      final triadPull = _smoothStep(
        ((.5 + .5 * math.sin(triadPhase) - .70) / .30).clamp(0.0, 1.0),
      );
      final triadIndex = id ~/ 2;
      final triadCenter = Offset(
        size.width * (id.isEven ? .41 : .63) + math.sin(loop) * 18,
        size.height * (.48 + math.cos(loop * 2) * .12),
      );
      final gatheredCenter =
          triadCenter +
          Offset.fromDirection(triadIndex * math.pi * 2 / 3 + loop * 2) *
              baseRadius *
              .22;
      drops.add(
        ChromaticFluidDrop(
          id: id,
          // Keep the independent orbit dominant. The gathering field is a
          // gentle, long-lived bias; it never takes ownership of a body's
          // centre or compresses the approach into a few frames.
          center: Offset.lerp(center, gatheredCenter, triadPull * .48)!,
          radius: baseRadius,
          baseRadius: baseRadius,
          color: _palette[id],
          size: id.isEven
              ? ChromaticFluidDropSize.large
              : ChromaticFluidDropSize.medium,
          surfacePhase: loop * (4 + id % 3) + id * 1.23,
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
      final phase = loop * (1 + i % 3) + i * 1.47;
      final anchor = smallAnchors[i];
      final freeCenter = Offset(
        size.width * anchor.dx + math.sin(phase) * (13 + i % 3 * 4),
        size.height * anchor.dy +
            math.cos(loop * (2 + i % 2) + i) * (16 + i % 2 * 5),
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
        ((.5 + .5 * math.sin(loop * (1 + i % 2) + i * 1.91)) - .44).clamp(
              0.0,
              1.0,
            ) /
            .56,
      );
      final direction = Offset.fromDirection(loop * (2 + i % 3) + i * .83);
      final hostPosition =
          host.center +
          direction * host.radius * (.20 + (1 - absorption) * .62);
      final center = Offset.lerp(freeCenter, hostPosition, absorption)!;
      final baseRadius = shortest * (.020 + (i % 3) * .008);
      drops.add(
        ChromaticFluidDrop(
          id: 6 + i,
          center: center,
          // A small drop may visually join its host, but its local field
          // source must never collapse to an almost-zero contribution.
          radius: baseRadius * (.48 + (1 - absorption) * .52),
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
    final loop = _cycleAngle(seconds);
    return List<ChromaticFluidParticle>.generate(particleCount, (index) {
      // Every particle completes exactly one transparent-edge traversal per
      // ambient loop, so its wrap is invisible at both endpoints.
      final progress = (seconds / cycleSeconds + index * .173) % 1;
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
              math.sin(loop * (3 + index % 3) + index) * 7,
          size.height * (1.08 - progress * 1.20) +
              math.cos(loop * (2 + index % 4) + index) * 4,
        ),
        radius: radius,
        color: _palette[(index + 1) % _palette.length],
        opacity: edgeFade * (isBubble ? .34 : .17),
        isBubble: isBubble,
      );
    });
  }

  static double contactStrength(double normalizedDistance) {
    // A long eased contact window lets pigment and the implicit neck begin
    // changing before the bodies visually overlap. This avoids the binary,
    // suction-like transition that the shorter V3.5 window produced.
    final raw = ((1.28 - normalizedDistance) / .52).clamp(0.0, 1.0);
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

    // Group on a generous local influence radius rather than a binary
    // contact threshold. The implicit field can then form and release a neck
    // continuously instead of switching between two separate evaluations.
    final drops = frame.drops;
    for (var firstIndex = 0; firstIndex < drops.length - 1; firstIndex++) {
      for (
        var secondIndex = firstIndex + 1;
        secondIndex < drops.length;
        secondIndex++
      ) {
        final first = drops[firstIndex];
        final second = drops[secondIndex];
        final normalizedDistance =
            (first.center - second.center).distance /
            (first.radius + second.radius);
        if (normalizedDistance > 1.60) continue;
        final firstRoot = root(first.id);
        final secondRoot = root(second.id);
        if (firstRoot != secondRoot) parent[secondRoot] = firstRoot;
      }
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
      radius: drops.first.radius * 1.9,
    );
    for (final drop in drops.skip(1)) {
      bounds = bounds.expandToInclude(
        Rect.fromCircle(center: drop.center, radius: drop.radius * 1.9),
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
        final pathBounds = path.getBounds();
        final contributingDrops = drops
            .where((drop) => pathBounds.contains(drop.center))
            .toSet();
        // A proximity group can still contain two disconnected contours.
        // Associate pigment with the contour that actually encloses its drop,
        // otherwise separated drops would inherit each other's full colour
        // field before the liquid neck exists.
        if (contributingDrops.isEmpty) {
          contributingDrops.add(
            drops.reduce(
              (nearest, candidate) =>
                  (candidate.center - pathBounds.center).distance <
                      (nearest.center - pathBounds.center).distance
                  ? candidate
                  : nearest,
            ),
          );
        }
        contours.add(
          ChromaticFluidFieldContour(
            path: path,
            bounds: pathBounds,
            dropIds: Set.unmodifiable(contributingDrops.map((drop) => drop.id)),
            pointCount: contourPoints.length,
            samplePoints: List.unmodifiable(contourPoints),
          ),
        );
      }
    }
    return (contours, values.length);
  }

  static List<_ChromaticFluidFieldSource> _sourcesFor(ChromaticFluidDrop drop) {
    final shapePhase = drop.surfacePhase + drop.id * .71;
    final rotation = shapePhase;
    final xScale = 1 + math.sin(shapePhase) * .102;
    final yScale = 1 + math.cos(shapePhase * 2) * .092;
    final driftDirection = Offset.fromDirection(shapePhase * 2 + drop.id);
    final firstLobeDirection = Offset.fromDirection(shapePhase * 3 + drop.id);
    final secondLobeDirection = Offset.fromDirection(
      shapePhase * -2 + drop.id * 1.83,
    );
    final rippleDirection = Offset.fromDirection(
      shapePhase * 4 - drop.id * .61,
    );
    return [
      _ChromaticFluidFieldSource(
        // The principal body stays near the kinematic centre while a slow
        // offset leaves a wake rather than scaling the whole outline in
        // unison. Every term is deterministic and continuous in time.
        center: drop.center + driftDirection * drop.radius * .045,
        radiusX: drop.radius * xScale,
        radiusY: drop.radius * yScale,
        cosRotation: math.cos(rotation),
        sinRotation: math.sin(rotation),
        weight: .68,
      ),
      _ChromaticFluidFieldSource(
        center: drop.center + firstLobeDirection * drop.radius * .42,
        radiusX: drop.radius * .62,
        radiusY: drop.radius * .40,
        cosRotation: math.cos(rotation + .8),
        sinRotation: math.sin(rotation + .8),
        weight: .29,
      ),
      _ChromaticFluidFieldSource(
        center: drop.center + secondLobeDirection * drop.radius * .58,
        radiusX: drop.radius * .41,
        radiusY: drop.radius * .27,
        cosRotation: math.cos(rotation - .72),
        sinRotation: math.sin(rotation - .72),
        weight: .15,
      ),
      _ChromaticFluidFieldSource(
        center:
            drop.center +
            rippleDirection *
                drop.radius *
                (.62 + math.sin(shapePhase * 3) * .055),
        radiusX: drop.radius * .28,
        radiusY: drop.radius * .17,
        cosRotation: math.cos(rotation + 1.56),
        sinRotation: math.sin(rotation + 1.56),
        weight: .055,
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

  static double _cycleAngle(double seconds) =>
      (seconds % cycleSeconds) / cycleSeconds * math.pi * 2;
}

@immutable
class HighFidelityFluidCell {
  const HighFidelityFluidCell({
    required this.center,
    required this.radius,
    required this.density,
    required this.color,
    required this.velocity,
  });

  final Offset center;
  final double radius;
  final double density;
  final Color color;
  final Offset velocity;
}

@immutable
class HighFidelityFluidRibbon {
  const HighFidelityFluidRibbon({
    required this.path,
    required this.color,
    required this.width,
  });

  final Path path;
  final Color color;
  final double width;
}

@immutable
class HighFidelityFluidPigmentParcel {
  const HighFidelityFluidPigmentParcel({
    required this.center,
    required this.velocity,
    required this.color,
    required this.density,
    required this.progress,
  });

  final Offset center;
  final Offset velocity;
  final Color color;
  final double density;
  final double progress;
}

/// A bounded local velocity/density/pigment field for the quality fluid.
///
/// It deliberately stays independent from the twelve implicit metaballs. The
/// simulation samples a velocity-driven, semi-Lagrangian pigment field, but
/// display reconstruction uses overlapping density kernels rather than its
/// calculation cells. This keeps the inexpensive local simulation from
/// leaking square cell boundaries into the painted liquid.
@immutable
class HighFidelityFluidFrame {
  const HighFidelityFluidFrame({
    required this.bounds,
    required this.outline,
    required this.cells,
    required this.ribbons,
    required this.pigmentParcels,
    required this.sampleCount,
  });

  final Rect bounds;
  final Path outline;
  final List<HighFidelityFluidCell> cells;
  final List<HighFidelityFluidRibbon> ribbons;
  final List<HighFidelityFluidPigmentParcel> pigmentParcels;
  final int sampleCount;
}

abstract final class HighFidelityChromaticFluid {
  static const gridResolution = 30;
  static const cycleSeconds = ChromaticFluidMetaballs.cycleSeconds;
  static const maximumSampleCount = gridResolution * gridResolution;
  static const _pigments = <Color>[
    Color(0xff2fe3d5),
    Color(0xff438cff),
    Color(0xffa65cf1),
    Color(0xfff05cae),
    Color(0xffcf72ff),
  ];

  static HighFidelityFluidFrame frame(Size size, double seconds) {
    final phase = _cycleAngle(seconds);
    final diameter = size.shortestSide * .30;
    final center = Offset(
      size.width * (.70 + math.sin(phase) * .055),
      size.height * (.34 + math.cos(phase * 2) * .075),
    );
    final bounds = Rect.fromCenter(
      center: center,
      width: diameter,
      height: diameter,
    );
    final cells = <HighFidelityFluidCell>[];
    final cellSize = diameter / gridResolution;
    for (var row = 0; row < gridResolution; row++) {
      for (var column = 0; column < gridResolution; column++) {
        final local = Offset(
          (column + .5) / gridResolution * 2 - 1,
          (row + .5) / gridResolution * 2 - 1,
        );
        final radius = local.distance;
        if (radius > 1.06) continue;
        final velocity = _velocity(local, phase);
        // Semi-Lagrangian backtrace: pigment reads from where this cell was,
        // rather than merely rotating a gradient at its current position.
        final traced = local - velocity * .18;
        final upstreamVelocity = _velocity(traced, phase - .10);
        // Two backtraces give colour a visible folded history.  This is still
        // bounded to the local field, unlike a full-screen fluid simulation.
        final diffused = traced - upstreamVelocity * .085;
        final pigment = _pigment(diffused, phase);
        final diffusion = _density(local + velocity * .035, phase) * .18;
        final density = (_density(diffused, phase) + diffusion).clamp(0.0, 1.0);
        if (density < .025) continue;
        cells.add(
          HighFidelityFluidCell(
            center: Offset(
              bounds.left + (column + .5) * cellSize,
              bounds.top + (row + .5) * cellSize,
            ),
            // Kept as a local physical footprint for bounded density checks;
            // it is never painted as a rectangular simulation cell.
            radius: cellSize * 1.34,
            density: density,
            color: pigment,
            velocity: velocity,
          ),
        );
      }
    }
    return HighFidelityFluidFrame(
      bounds: bounds,
      outline: _outline(center, diameter, phase),
      cells: List.unmodifiable(cells),
      ribbons: List.unmodifiable(_ribbons(bounds, phase)),
      pigmentParcels: List.unmodifiable(_pigmentParcels(bounds, phase)),
      sampleCount: cells.length,
    );
  }

  // These parcels are display samples of the same velocity/density field as
  // the 30x30 bounded simulation. They are deliberately not cells: painting
  // them as overlapping, advected kernels removes the coarse colour bands
  // caused by V3.5's 12x12 bucket reconstruction.
  static List<HighFidelityFluidPigmentParcel> _pigmentParcels(
    Rect bounds,
    double phase,
  ) {
    final parcels = <HighFidelityFluidPigmentParcel>[];
    for (final source in _pigmentSources(phase)) {
      var local = source.$1;
      for (var step = 0; step < 15; step++) {
        if (local.distance > 1.08) break;
        final velocity = _velocity(local, phase + step * .055);
        final density = _density(local, phase);
        if (density > .045) {
          final pigment = _pigment(
            local - velocity * (.11 + step * .006),
            phase - step * .018,
          );
          parcels.add(
            HighFidelityFluidPigmentParcel(
              center: Offset(
                bounds.center.dx + local.dx * bounds.width * .5,
                bounds.center.dy + local.dy * bounds.height * .5,
              ),
              velocity: velocity,
              color: Color.lerp(source.$2, pigment, .58)!,
              density: density,
              progress: step / 14,
            ),
          );
        }
        // RK2 keeps advection curved and coupled to the local vortices
        // without introducing a stateful simulation reset at the loop seam.
        final midpoint = local + velocity * .034;
        local += _velocity(midpoint, phase + step * .055 + .03) * .068;
      }
    }
    return parcels;
  }

  static List<HighFidelityFluidRibbon> _ribbons(Rect bounds, double phase) {
    final ribbons = <HighFidelityFluidRibbon>[];
    for (final (index, source) in _pigmentSources(phase).indexed) {
      var local = source.$1;
      final points = <Offset>[];
      for (var step = 0; step < 26; step++) {
        if (local.distance > 1.16) break;
        points.add(
          Offset(
            bounds.center.dx + local.dx * bounds.width * .5,
            bounds.center.dy + local.dy * bounds.height * .5,
          ),
        );
        final velocity = _velocity(local, phase + step * .12);
        local += velocity * .045;
      }
      if (points.length < 4) continue;
      ribbons.add(
        HighFidelityFluidRibbon(
          path: _openSmoothPath(points),
          color: source.$2,
          width: bounds.width * (.029 + (index % 2) * .008),
        ),
      );
    }
    return ribbons;
  }

  static Offset _velocity(Offset point, double phase) {
    final radial = point.distance;
    final primaryVortex =
        .58 * (1 - radial.clamp(0.0, 1.0)) +
        math.sin(phase * 2 + point.dx * 4 + point.dy * 2) * .16;
    final secondaryCenter = Offset(
      math.cos(phase * 2) * .27,
      math.sin(phase * 2 - .7) * .22,
    );
    final aroundSecondary = point - secondaryCenter;
    final secondaryVortex =
        .36 * (1 - aroundSecondary.distance.clamp(0.0, 1.0));
    final tangent =
        Offset(-point.dy, point.dx) * primaryVortex +
        Offset(-aroundSecondary.dy, aroundSecondary.dx) * secondaryVortex;
    final shear = Offset(
      math.sin(phase + point.dy * 5) * (.10 + point.dy.abs() * .09),
      math.cos(phase * 2 - point.dx * 4) * (.08 + point.dx.abs() * .08),
    );
    final folding = Offset(
      point.dy * math.sin(phase * 2 + point.dx * 3) * .15,
      -point.dx * math.cos(phase * 2 - point.dy * 3) * .13,
    );
    // Cross-stream transport prevents every pigment parcel from settling
    // into the same circular orbit. Alternating entrainment pulls colour
    // through the core, then releases it into the folding/shear field.
    final entrainment =
        point * (-.36 + math.sin(phase + point.dx * 2 - point.dy * 3) * .12) +
        Offset(
          math.cos(phase * 2 + point.dy * 4) * .10,
          math.sin(phase * 2 - point.dx * 4) * .10,
        );
    return tangent + shear + folding + entrainment;
  }

  static double _density(Offset point, double phase) {
    final angle = math.atan2(point.dy, point.dx);
    final edgeWave =
        math.sin(angle * 3 + phase * 2) * .070 +
        math.cos(angle * 5 - phase * 2) * .042 +
        math.sin(angle * 7 + phase) * .022;
    final envelope = (1.10 + edgeWave - point.distance).clamp(0.0, 1.0);
    final wave =
        .67 +
        math.sin(point.dx * 5.7 + point.dy * 4.1 - phase * 3) * .13 +
        math.cos(point.dy * 6.8 + phase * 2) * .10 +
        math.sin((point.dx - point.dy) * 4.6 + phase) * .055;
    return (envelope * wave).clamp(0.0, 1.0);
  }

  static Color _pigment(Offset point, double phase) {
    final sources = _pigmentSources(phase);
    var total = 0.0;
    var red = 0.0;
    var green = 0.0;
    var blue = 0.0;
    for (final source in sources) {
      final distanceSquared = (point - source.$1).distanceSquared;
      final weight = math.exp(-distanceSquared * 5.4) + .018;
      total += weight;
      red += source.$2.r * weight;
      green += source.$2.g * weight;
      blue += source.$2.b * weight;
    }
    return Color.fromARGB(
      255,
      (red / total * 255).round().clamp(0, 255),
      (green / total * 255).round().clamp(0, 255),
      (blue / total * 255).round().clamp(0, 255),
    );
  }

  static List<(Offset, Color)> _pigmentSources(
    double phase,
  ) => <(Offset, Color)>[
    (
      Offset(
        -.50 + math.sin(phase * 2) * .12,
        -.16 + math.cos(phase * 2 - .4) * .13,
      ),
      _pigments[0],
    ),
    (
      Offset(.27 + math.cos(phase * 3) * .15, -.43 + math.sin(phase * 2) * .11),
      _pigments[1],
    ),
    (
      Offset(
        .49 + math.sin(phase * 2 + 1.4) * .13,
        .18 + math.cos(phase * 2 + .3) * .12,
      ),
      _pigments[2],
    ),
    (
      Offset(
        -.12 + math.cos(phase * 4 + .7) * .17,
        .48 + math.sin(phase * 2) * .12,
      ),
      _pigments[3],
    ),
    (
      Offset(
        -.42 + math.sin(phase * 3 + 2.1) * .12,
        .31 + math.cos(phase * 4 + .6) * .13,
      ),
      _pigments[4],
    ),
  ];

  static Path _openSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length - 1; index++) {
      final point = points[index];
      final next = points[index + 1];
      path.quadraticBezierTo(
        point.dx,
        point.dy,
        (point.dx + next.dx) * .5,
        (point.dy + next.dy) * .5,
      );
    }
    final last = points.last;
    return path..lineTo(last.dx, last.dy);
  }

  static Path _outline(Offset center, double diameter, double phase) {
    final points = <Offset>[];
    for (var index = 0; index < 28; index++) {
      final angle = index * math.pi * 2 / 28;
      final probe = Offset(math.cos(angle), math.sin(angle));
      final flow = _velocity(probe * .82, phase);
      final projectedFlow = flow.dx * probe.dx + flow.dy * probe.dy;
      final radius =
          diameter *
          (.47 +
              math.sin(angle * 3 + phase * 3) * .050 +
              math.cos(angle * 5 - phase * 2) * .034 +
              projectedFlow * .040);
      points.add(
        center +
            Offset(math.cos(angle) * radius, math.sin(angle) * radius * .91),
      );
    }
    return ChromaticFluidMetaballs._closedSmoothPath(points);
  }

  static double _cycleAngle(double seconds) =>
      (seconds % cycleSeconds) / cycleSeconds * math.pi * 2;
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

  /// The chromatic field is periodic independently of the screen ticker.
  /// Keeping paint-only flow on this same phase prevents a visible rewind at
  /// either the 24-second field seam or the enclosing 48-second controller.
  double get _chromaticPhase =>
      (t % ChromaticFluidMetaballs.cycleSeconds) /
      ChromaticFluidMetaballs.cycleSeconds *
      math.pi *
      2;
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
      if (particle.isBubble) {
        // Water bubbles have a transparent centre: only their thin rim and
        // two local reflections are visible over the existing ambient.
        c.drawCircle(
          particle.center,
          particle.radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .72
            ..color = Color.lerp(
              particle.color,
              Colors.white,
              .55,
            )!.withValues(alpha: particle.opacity),
        );
        c.drawArc(
          Rect.fromCircle(center: particle.center, radius: particle.radius),
          -2.55,
          1.15,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .85
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: particle.opacity * .9),
        );
        c.drawCircle(
          particle.center +
              Offset(-particle.radius * .24, -particle.radius * .30),
          math.max(.38, particle.radius * .16),
          Paint()
            ..color = Colors.white.withValues(alpha: particle.opacity * .82),
        );
      } else {
        c.drawCircle(
          particle.center,
          particle.radius,
          Paint()..color = particle.color.withValues(alpha: particle.opacity),
        );
      }
    }

    _paintHighFidelityFluid(c, s);

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

      // Reconstruct colour from the moving pigment carried by every drop.
      // Unlike V3.2's single end-to-end linear gradient, these overlapping
      // radial fields curve and circulate independently inside the contour.
      c.drawPath(
        contour.path,
        Paint()..color = averageColor.withValues(alpha: .09),
      );

      for (final drop in contourDrops) {
        final flowCenter =
            drop.center +
            Offset(
                  math.cos(drop.surfacePhase * 2),
                  math.sin(drop.surfacePhase * 3),
                ) *
                drop.radius *
                .24;
        c.drawCircle(
          flowCenter,
          drop.radius * 1.82,
          Paint()
            ..shader =
                RadialGradient(
                  center: Alignment(
                    math.sin(drop.surfacePhase * 2) * .22,
                    math.cos(drop.surfacePhase * 3) * .18,
                  ),
                  radius: 1,
                  colors: [
                    Color.lerp(
                      drop.color,
                      Colors.white,
                      .30,
                    )!.withValues(alpha: .31),
                    drop.color.withValues(alpha: .22),
                    Color.lerp(
                      drop.color,
                      const Color(0xff071522),
                      .50,
                    )!.withValues(alpha: .08),
                    drop.color.withValues(alpha: 0),
                  ],
                  stops: const [0, .34, .72, 1],
                ).createShader(
                  Rect.fromCircle(
                    center: flowCenter,
                    radius: drop.radius * 1.82,
                  ),
                ),
        );

        // A rotating, soft anisotropic lobe gives the interior its own period,
        // independent from both centre translation and contour deformation.
        c.save();
        c.translate(flowCenter.dx, flowCenter.dy);
        c.rotate(drop.surfacePhase * 2 + drop.id * .37);
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
            contact.radius *
            (1 + math.sin(_chromaticPhase * 2 + contact.first.id) * .10);
        final mixCenter = Offset.lerp(
          contact.center,
          contact.first.center,
          .08 * math.sin(_chromaticPhase * 3 + contact.second.id),
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
                    )!.withValues(alpha: contact.strength * .34),
                    contact.mixedColor.withValues(
                      alpha: contact.strength * .21,
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

  void _paintHighFidelityFluid(Canvas c, Size s) {
    final fluid = HighFidelityChromaticFluid.frame(s, t);
    c.save();
    c.clipPath(fluid.outline);
    c.drawRect(
      fluid.bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.18, -.24),
          colors: [Color(0xff143e63), Color(0xff182957), Color(0xff0b1127)],
          stops: [.0, .58, 1],
        ).createShader(fluid.bounds),
    );

    // Fold a broad portion of every advected colour plume through the core.
    // This is a density-weighted view of the same parcels below, not a static
    // background gradient: it changes with their velocity and phase while
    // preventing the quality fluid from reading as a hollow ribbon ring.
    for (
      var sourceIndex = 0;
      sourceIndex < fluid.pigmentParcels.length;
      sourceIndex += 15
    ) {
      final parcel = fluid.pigmentParcels[sourceIndex];
      final center = Offset.lerp(parcel.center, fluid.bounds.center, .42)!;
      final stamp = Rect.fromCenter(
        center: center,
        width: fluid.bounds.width * .52,
        height: fluid.bounds.height * .30,
      );
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(math.atan2(parcel.velocity.dy, parcel.velocity.dx));
      c.translate(-center.dx, -center.dy);
      c.drawOval(
        stamp,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.22, -.16),
            colors: [
              parcel.color.withValues(alpha: .24 * parcel.density),
              parcel.color.withValues(alpha: .10 * parcel.density),
              parcel.color.withValues(alpha: 0),
            ],
            stops: const [0, .48, 1],
          ).createShader(stamp),
      );
      c.restore();
    }

    // Draw sparse, broad parcels advected through the same field. The source
    // grid is never sampled in the final raster: each parcel is an RK2 flow
    // trace, so overlapping plumes read as pigment rather than dots/cells.
    for (final (index, parcel) in fluid.pigmentParcels.indexed) {
      if (index % 3 != 0) continue;
      final speed = parcel.velocity.distance;
      final radius = fluid.bounds.width * (.070 + parcel.density * .038);
      final center = parcel.center;
      final stamp = Rect.fromCenter(
        center: center,
        width: radius * (1.82 + speed * .34),
        height: radius * (1.22 + speed * .13),
      );
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(math.atan2(parcel.velocity.dy, parcel.velocity.dx));
      c.translate(-center.dx, -center.dy);
      c.drawOval(
        stamp,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.18, -.10),
            radius: 1,
            colors: [
              Color.lerp(
                parcel.color,
                Colors.white,
                .20,
              )!.withValues(alpha: .32 * parcel.density),
              parcel.color.withValues(alpha: .26 * parcel.density),
              parcel.color.withValues(alpha: 0),
            ],
            stops: const [0, .48, 1],
          ).createShader(stamp),
      );
      c.restore();
    }

    c.restore();
    c.drawPath(
      fluid.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .85
        ..color = const Color(0xff78dfff).withValues(alpha: .22),
    );
  }

  void _cells(Canvas c, Size s) {
    // METABOLIC CELLS intentionally has its own liquid-sphere construction.
    // It keeps the established fifteen-cell population and spatial rhythm,
    // while avoiding the chromatic fluid's denser scalar field and ribbons.
    // Every term is periodic over the controller's 48-second cycle so there
    // is no state or velocity jump when the ticker repeats.
    final loop = t / 48 * math.pi * 2;
    final cells =
        <
          ({
            Offset center,
            Offset velocity,
            double radius,
            double phase,
            Color color,
          })
        >[];
    for (var i = 0; i < 15; i++) {
      final seed = _h(i, 9);
      final frequency = 1 + i % 3;
      final q = loop * frequency + i;
      final o = Offset(
        s.width * (.06 + .88 * _h(i, 11)) + 18 * math.sin(q),
        s.height * (.05 + .9 * _h(i, 13)) + 20 * math.cos(q * 2),
      );
      final r = s.shortestSide * (.052 + seed * .072);
      final col = _cool[i % 3];
      final velocity = Offset(
        18 * frequency * math.cos(q),
        -40 * frequency * math.sin(q * 2),
      );
      cells.add((
        center: o,
        velocity: velocity,
        radius: r,
        phase: q,
        color: col,
      ));
    }

    final contacts = List.generate(
      cells.length,
      (_) => <({Offset direction, double strength})>[],
    );
    for (var first = 0; first < cells.length - 1; first++) {
      for (var second = first + 1; second < cells.length; second++) {
        final a = cells[first];
        final b = cells[second];
        final distance = (a.center - b.center).distance;
        final ratio = distance / (a.radius + b.radius);
        final raw = ((1.12 - ratio) / .30).clamp(0.0, 1.0);
        final strength = raw * raw * (3 - 2 * raw);
        if (strength < .02) continue;
        final direction = distance < .0001
            ? const Offset(1, 0)
            : (b.center - a.center) / distance;
        contacts[first].add((direction: direction, strength: strength));
        contacts[second].add((direction: -direction, strength: strength));
      }
    }

    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i];
      final seed = _h(i, 9);
      final speed = cell.velocity.distance / 20;
      final travel = cell.velocity.distance == 0
          ? Offset.zero
          : cell.velocity / cell.velocity.distance;
      final surfaceOffset =
          travel * cell.radius * (.055 + speed * .050) +
          Offset(math.cos(cell.phase * 2), math.sin(cell.phase)) *
              cell.radius *
              .045;
      var contactVector = Offset.zero;
      var contactStrength = 0.0;
      for (final contact in contacts[i]) {
        contactVector += contact.direction * contact.strength;
        contactStrength += contact.strength;
      }
      final contactDirection = contactVector.distanceSquared < .00001
          ? const Offset(1, 0)
          : contactVector / contactVector.distance;
      final membrane = _smoothOrganicPath(
        cell.center + surfaceOffset,
        cell.radius,
        cell.phase,
        i + 30,
        18,
        .075 + speed * .030,
        x: 1 + speed * .11,
        y: 1 - speed * .045,
        contactDirection: contactDirection,
        contactStrength: (contactStrength / 1.6).clamp(0.0, .16),
      );
      final bounds = membrane.getBounds();
      c.drawPath(
        membrane,
        Paint()
          ..color = cell.color.withValues(alpha: .075)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      c.save();
      c.clipPath(membrane);
      c.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              -.30 + math.sin(cell.phase) * .10,
              -.34 + math.cos(cell.phase) * .08,
            ),
            radius: 1.04,
            colors: [
              Color.lerp(cell.color, Colors.white, .42)!.withValues(alpha: .27),
              cell.color.withValues(alpha: .19),
              Color.lerp(
                cell.color,
                const Color(0xff071522),
                .52,
              )!.withValues(alpha: .07),
              cell.color.withValues(alpha: 0),
            ],
            stops: const [0, .32, .73, 1],
          ).createShader(bounds),
      );
      for (var dye = 0; dye < 2; dye++) {
        final dyePhase = cell.phase * (1 + dye) + dye * 2.1;
        final dyeCenter =
            cell.center +
            Offset(math.cos(dyePhase), math.sin(dyePhase * .84)) *
                cell.radius *
                (.22 + dye * .10);
        final dyeRect = Rect.fromCircle(
          center: dyeCenter,
          radius: cell.radius * .66,
        );
        c.drawOval(
          dyeRect,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Color.lerp(
                  cell.color,
                  _cool[(i + dye + 1) % _cool.length],
                  .58,
                )!.withValues(alpha: .12),
                cell.color.withValues(alpha: 0),
              ],
              stops: const [0, 1],
            ).createShader(dyeRect),
        );
      }
      // A recognisable cell needs a stable nucleus and nucleolus rather than
      // an anonymous colour blob. Both drift gently within the cytoplasm but
      // stay enclosed by the membrane during contact deformation.
      final nucleusCenter =
          cell.center +
          Offset(
                math.cos(cell.phase * .72 + i),
                math.sin(cell.phase * .58 - i),
              ) *
              cell.radius *
              .22;
      final nucleusRect = Rect.fromCircle(
        center: nucleusCenter,
        radius: cell.radius * .235,
      );
      c.drawOval(
        nucleusRect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.28, -.25),
            colors: [
              Color.lerp(cell.color, Colors.white, .30)!.withValues(alpha: .28),
              Color.lerp(
                cell.color,
                const Color(0xff14213d),
                .72,
              )!.withValues(alpha: .31),
              const Color(0xff08101f).withValues(alpha: .21),
            ],
            stops: const [0, .58, 1],
          ).createShader(nucleusRect),
      );
      c.drawCircle(
        nucleusCenter + Offset(cell.radius * .045, -cell.radius * .028),
        cell.radius * .060,
        Paint()
          ..color = Colors.white.withValues(alpha: .28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
      c.restore();
      c.drawPath(
        membrane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.05 + seed * .42
          ..color = Color.lerp(
            cell.color,
            Colors.white,
            .34,
          )!.withValues(alpha: .38),
      );
      c.drawPath(
        membrane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .44
          ..color = const Color(0xff071522).withValues(alpha: .48),
      );
      c.drawCircle(
        cell.center +
            Offset(math.cos(cell.phase), math.sin(cell.phase * 2)) *
                cell.radius *
                .34,
        cell.radius * .25,
        Paint()
          ..color = Colors.white.withValues(alpha: .12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    for (var i = 0; i < 30; i++) {
      final q = loop * (1 + i % 3) + i;
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
      old.variant != variant || old.t != t;
}
