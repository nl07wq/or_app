import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cat_multi_pose_trace_data.dart';

/// Sandbox-only four-key-pose vector morph. Each source pose stays independent.
class CatMultiPoseRun {
  static const commonPointCount = 96;
  static const cycleDuration = Duration(milliseconds: 720);

  List<Offset> pointsAt(double phase) {
    final scaled = (phase % 1) * 4;
    final index = scaled.floor();
    final t = _ease(scaled - index);
    final first = _resample(catMultiPoseTraces[index].points);
    final second = _resample(catMultiPoseTraces[(index + 1) % 4].points);
    return List.generate(
      commonPointCount,
      (i) => Offset.lerp(first[i], second[i], t)!,
    );
  }

  List<Offset> pointsForPose(CatMultiPose pose) => _resample(
    catMultiPoseTraces.singleWhere((trace) => trace.pose == pose).points,
  );

  Path pathFor(List<Offset> points) => Path()
    ..moveTo(points.first.dx, points.first.dy)
    ..addPolygon(points, true);

  List<Offset> _resample(List<Offset> input) {
    final lengths = <double>[0];
    for (var i = 1; i <= input.length; i++) {
      lengths.add(
        lengths.last +
            (input[i % input.length] - input[(i - 1) % input.length]).distance,
      );
    }
    final total = lengths.last;
    return List.generate(commonPointCount, (i) {
      final target = total * i / commonPointCount;
      var segment = 1;
      while (segment < lengths.length && lengths[segment] < target) {
        segment++;
      }
      final start = input[(segment - 1) % input.length];
      final end = input[segment % input.length];
      final span = lengths[segment] - lengths[segment - 1];
      final local = span == 0 ? 0 : (target - lengths[segment - 1]) / span;
      return Offset.lerp(start, end, local)!;
    });
  }

  static double _ease(double t) => .5 - .5 * math.cos(math.pi * t);
}
