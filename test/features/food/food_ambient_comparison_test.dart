import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';

void main() {
  testWidgets('FOOD ambient comparison exposes and switches all candidates', (
    tester,
  ) async {
    FoodAmbientVariant selected = FoodAmbientVariant.chromaticFluid;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: Stack(
                children: [
                  FoodAmbientComparison(variant: selected),
                  FoodAmbientComparisonSelector(
                    selected: selected,
                    onChanged: (variant) => setState(() => selected = variant),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    expect(FoodAmbientVariant.values, hasLength(3));
    expect(find.byType(FoodAmbientComparison), findsOneWidget);
    expect(find.text('CHROMATIC FLUID'), findsOneWidget);
    expect(find.text('METABOLIC CELLS'), findsOneWidget);
    expect(find.text('THERMAL CURRENT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('food-ambient-metabolicCells')));
    await tester.pump();

    expect(selected, FoodAmbientVariant.metabolicCells);
    for (final variant in FoodAmbientVariant.values) {
      expect(
        FoodAmbientComparison.motionSignatureFor(variant, 0),
        isNot(FoodAmbientComparison.motionSignatureFor(variant, 3.75)),
      );
      update(() => selected = variant);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
    }
  });
}
