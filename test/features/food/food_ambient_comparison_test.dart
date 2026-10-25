import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';
import 'package:or_app/features/food/widgets/food_feature_chrome.dart';

void main() {
  test('continuous circulation keeps the approved 22 sphere population', () {
    final frame = OilTimerMotion.continuousCirculationFrame(
      const Size(390, 844),
      0,
    );
    expect(frame.drops, hasLength(22));
  });

  testWidgets('FOOD chrome has one fixed ambient and no selector controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FoodFeatureScaffold(
          appBar: foodFeatureAppBar(title: 'FOOD DATABASE'),
          body: const SizedBox.expand(),
        ),
      ),
    );
    expect(find.byType(FoodAmbientComparison), findsOneWidget);
    expect(find.text('METABOLIC CELLS'), findsNothing);
    expect(find.text('THERMAL CURRENT'), findsNothing);
    expect(find.bySemanticsLabel('FOOD DATABASE'), findsOneWidget);
  });
}
