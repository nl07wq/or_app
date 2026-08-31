import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/services/history_y_axis_width.dart';

void main() {
  const style = TextStyle(fontSize: 11);

  test('uses measured label width plus safe trailing padding', () {
    final compact = HistoryYAxisWidth.calculate(
      labels: const ['0%', '34.0%'],
      style: style,
      textDirection: TextDirection.ltr,
    );
    final wide = HistoryYAxisWidth.calculate(
      labels: const ['0 kcal', '3500 kcal'],
      style: style,
      textDirection: TextDirection.ltr,
    );

    expect(compact, greaterThanOrEqualTo(HistoryYAxisWidth.minimumWidth));
    expect(wide, greaterThan(compact));
  });

  test('never clips representative body and nutrition labels', () {
    for (final labels in const [
      ['90.0kg', '107.5kg'],
      ['0.0%', '34.0%'],
      ['-1500 kcal', '3500 kcal'],
    ]) {
      final width = HistoryYAxisWidth.calculate(
        labels: labels,
        style: style,
        textDirection: TextDirection.ltr,
      );
      for (final label in labels) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        expect(width, greaterThan(painter.width));
      }
    }
  });
}
