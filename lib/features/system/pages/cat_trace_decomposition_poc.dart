import 'package:flutter/material.dart';

import 'cat_trace_poc_data.dart';

/// Static, CAT-only decomposition of the fixed TRACE MEDIUM contour.
///
/// Every component is clipped from the canonical trace. The clipping zones
/// overlap only inside the filled source silhouette, so they provide hidden
/// root material for a later articulation experiment without redrawing an
/// exposed contour in this neutral reconstruction POC.
class CatTraceDecomposition {
  CatTraceDecomposition._({
    required this.sourceLevel,
    required this.components,
  });

  factory CatTraceDecomposition.medium() {
    final sourceLevel = generatedCatTraceVectorLevels[1];
    return CatTraceDecomposition._(
      sourceLevel: sourceLevel,
      components: [
        _component(
          id: CatTraceComponentId.headNeck,
          parent: CatTraceComponentId.torso,
          pivot: const Offset(.205, .185),
          zone: const Rect.fromLTRB(0, 0, .285, .365),
          contourRanges: const [
            CatTraceContourRange(0, 12),
            CatTraceContourRange(75, 84),
          ],
        ),
        _component(
          id: CatTraceComponentId.torso,
          pivot: const Offset(.465, .215),
          zone: const Rect.fromLTRB(.115, .045, .735, .385),
          contourRanges: const [
            CatTraceContourRange(10, 18),
            CatTraceContourRange(42, 58),
          ],
        ),
        _component(
          id: CatTraceComponentId.forelegNear,
          parent: CatTraceComponentId.torso,
          pivot: const Offset(.205, .295),
          zone: const Rect.fromLTRB(0, .245, .255, .50),
          contourRanges: const [CatTraceContourRange(68, 75)],
        ),
        _component(
          id: CatTraceComponentId.forelegFar,
          parent: CatTraceComponentId.torso,
          pivot: const Offset(.275, .295),
          zone: const Rect.fromLTRB(.195, .245, .365, .50),
          contourRanges: const [CatTraceContourRange(58, 67)],
        ),
        _component(
          id: CatTraceComponentId.hindLegFar,
          parent: CatTraceComponentId.torso,
          pivot: const Offset(.495, .290),
          zone: const Rect.fromLTRB(.405, .245, .605, .50),
          contourRanges: const [CatTraceContourRange(45, 53)],
        ),
        _component(
          id: CatTraceComponentId.hindLegNear,
          parent: CatTraceComponentId.torso,
          pivot: const Offset(.700, .270),
          zone: const Rect.fromLTRB(.645, .175, .835, .50),
          contourRanges: const [CatTraceContourRange(30, 42)],
        ),
        _component(
          id: CatTraceComponentId.tail,
          parent: CatTraceComponentId.torso,
          pivot: const Offset(.690, .185),
          zone: const Rect.fromLTRB(.660, .095, 1, .340),
          contourRanges: const [CatTraceContourRange(15, 30)],
        ),
      ],
    );
  }

  final CatTraceVectorLevel sourceLevel;
  final List<CatTraceComponent> components;

  /// The untouched C trace, evaluated in normalized source coordinates.
  Path originalPath() => CatTracePathGeometry.closedPath(sourceLevel.points);

  /// The neutral C' reconstruction. It is formed from component paths only.
  Path reconstructedPath() {
    final original = originalPath();
    return components
        .map((component) => component.pathFrom(original))
        .reduce(
          (union, path) => Path.combine(PathOperation.union, union, path),
        );
  }

  List<Path> componentPaths() {
    final original = originalPath();
    return [for (final component in components) component.pathFrom(original)];
  }

  CatTraceReconstructionMetrics measure({int width = 512, int height = 256}) =>
      CatTraceReconstructionMetrics.fromPaths(
        original: originalPath(),
        reconstructed: reconstructedPath(),
        width: width,
        height: height,
      );

  static CatTraceComponent _component({
    required CatTraceComponentId id,
    CatTraceComponentId? parent,
    required Offset pivot,
    required Rect zone,
    required List<CatTraceContourRange> contourRanges,
  }) => CatTraceComponent(
    id: id,
    parent: parent,
    pivot: pivot,
    hiddenRootZone: zone,
    visibleContourRanges: contourRanges,
    neutralTransform: const CatTraceNeutralTransform(),
  );
}

enum CatTraceComponentId {
  headNeck,
  torso,
  forelegNear,
  forelegFar,
  hindLegNear,
  hindLegFar,
  tail,
}

@immutable
class CatTraceComponent {
  const CatTraceComponent({
    required this.id,
    required this.parent,
    required this.pivot,
    required this.hiddenRootZone,
    required this.visibleContourRanges,
    required this.neutralTransform,
  });

  final CatTraceComponentId id;
  final CatTraceComponentId? parent;
  final Offset pivot;

  /// A deliberately overlapping interior zone. It never creates a new outer
  /// contour in neutral because the final path is intersected with source C.
  final Rect hiddenRootZone;
  final List<CatTraceContourRange> visibleContourRanges;
  final CatTraceNeutralTransform neutralTransform;

  Path pathFrom(Path source) => Path.combine(
    PathOperation.intersect,
    source,
    Path()..addRect(hiddenRootZone),
  );
}

@immutable
class CatTraceContourRange {
  const CatTraceContourRange(this.startInclusive, this.endInclusive);

  final int startInclusive;
  final int endInclusive;
}

@immutable
class CatTraceNeutralTransform {
  const CatTraceNeutralTransform({
    this.translation = Offset.zero,
    this.rotationRadians = 0,
    this.scale = 1,
  });

  final Offset translation;
  final double rotationRadians;
  final double scale;
}

/// Shared trace-to-path conversion. Cubic controls are mechanically derived
/// from adjacent samples and are used for original C and C' alike.
abstract final class CatTracePathGeometry {
  static Path closedPath(List<Offset> points) {
    assert(points.length >= 3);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length; index++) {
      final previous = points[(index - 1 + points.length) % points.length];
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final afterNext = points[(index + 2) % points.length];
      final firstControl = current + (next - previous) / 6;
      final secondControl = next - (afterNext - current) / 6;
      path.cubicTo(
        firstControl.dx,
        firstControl.dy,
        secondControl.dx,
        secondControl.dy,
        next.dx,
        next.dy,
      );
    }
    return path..close();
  }
}

@immutable
class CatTraceReconstructionMetrics {
  const CatTraceReconstructionMetrics({
    required this.iou,
    required this.disagreement,
    required this.originalPixels,
    required this.reconstructedPixels,
  });

  factory CatTraceReconstructionMetrics.fromPaths({
    required Path original,
    required Path reconstructed,
    required int width,
    required int height,
  }) {
    var intersection = 0;
    var union = 0;
    var disagreements = 0;
    var originalPixels = 0;
    var reconstructedPixels = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final point = Offset((x + .5) / width, (y + .5) / height);
        final isOriginal = original.contains(point);
        final isReconstructed = reconstructed.contains(point);
        if (isOriginal) originalPixels++;
        if (isReconstructed) reconstructedPixels++;
        if (isOriginal || isReconstructed) union++;
        if (isOriginal && isReconstructed) intersection++;
        if (isOriginal != isReconstructed) disagreements++;
      }
    }
    return CatTraceReconstructionMetrics(
      iou: union == 0 ? 0 : intersection / union,
      disagreement: disagreements / (width * height),
      originalPixels: originalPixels,
      reconstructedPixels: reconstructedPixels,
    );
  }

  final double iou;
  final double disagreement;
  final int originalPixels;
  final int reconstructedPixels;
}
