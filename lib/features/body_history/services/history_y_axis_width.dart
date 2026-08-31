import 'dart:math' as math;

import 'package:flutter/widgets.dart';

abstract final class HistoryYAxisWidth {
  static const double trailingPadding = 6;
  static const double minimumWidth = 32;

  static double calculate({
    required Iterable<String> labels,
    required TextStyle style,
    required TextDirection textDirection,
  }) {
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        maxLines: 1,
        textDirection: textDirection,
      )..layout();
      widest = math.max(widest, painter.width);
    }
    return math.max(minimumWidth, widest.ceilToDouble() + trailingPadding + 1);
  }
}
