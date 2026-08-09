import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/services/body_history_chart_engine.dart';

void main() {
  const engine = BodyHistoryChartEngine();

  test('eight points fit the available chart width', () {
    final width = engine.chartWidth(pointCount: 8, availableWidth: 268);

    expect(width, 268);
  });

  test('thirty points retain candidate spacing and require scrolling', () {
    final width = engine.chartWidth(pointCount: 30, availableWidth: 268);

    expect(width, 30 * BodyHistoryChartEngine.pointSpacingCandidate);
    expect(width, greaterThan(268));
  });

  test('chart width is capped by the existing maximum candidate', () {
    final width = engine.chartWidth(pointCount: 1000, availableWidth: 268);

    expect(width, BodyHistoryChartEngine.maximumChartWidthCandidate);
  });
}
