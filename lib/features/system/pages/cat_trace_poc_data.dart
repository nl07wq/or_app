import 'package:flutter/material.dart';

part 'cat_trace_poc_data.g.dart';

/// Source-derived vector level emitted by the deterministic development tool.
@immutable
class CatTraceVectorLevel {
  const CatTraceVectorLevel({
    required this.name,
    required this.tolerance,
    required this.sourcePointCount,
    required this.iou,
    required this.disagreement,
    required this.points,
  });

  final String name;
  final double tolerance;
  final int sourcePointCount;
  final double iou;
  final double disagreement;
  final List<Offset> points;
}

/// Immutable, reproducible source-processing report for CAT TRACE POC-B.
const catTraceSourceReport = CatTraceSourceReport(
  sourceWidth: 1280,
  sourceHeight: 640,
  luminanceThreshold: 128,
  openingKernel: 3,
  rawContourPointCount: 5480,
  contourMethod: 'oriented pixel-grid outer boundary',
  simplificationMethod: 'Ramer-Douglas-Peucker',
  curveMethod: 'uniform Catmull-Rom converted to cubic Bezier',
);

@immutable
class CatTraceSourceReport {
  const CatTraceSourceReport({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.luminanceThreshold,
    required this.openingKernel,
    required this.rawContourPointCount,
    required this.contourMethod,
    required this.simplificationMethod,
    required this.curveMethod,
  });

  final int sourceWidth;
  final int sourceHeight;
  final int luminanceThreshold;
  final int openingKernel;
  final int rawContourPointCount;
  final String contourMethod;
  final String simplificationMethod;
  final String curveMethod;
}
