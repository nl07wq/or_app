import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';

void main() {
  testWidgets('FOOD ambient comparison exposes and switches all candidates', (
    tester,
  ) async {
    FoodAmbientVariant selected = FoodAmbientVariant.continuousCirculation;
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
    expect(find.text('GRAVITY FLIP'), findsNothing);
    expect(find.text('CONTINUOUS CIRCULATION'), findsOneWidget);
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

  test('migrates removed GRAVITY FLIP preference to circulation', () {
    expect(
      FoodAmbientVariant.fromPersistedName('gravityFlip'),
      FoodAmbientVariant.continuousCirculation,
    );
    expect(
      FoodAmbientVariant.fromPersistedName('metabolicCells'),
      FoodAmbientVariant.metabolicCells,
    );
    expect(
      FoodAmbientVariant.fromPersistedName('thermalCurrent'),
      FoodAmbientVariant.thermalCurrent,
    );
  });

  test('iridescent circulation keeps 18 IDs at exactly 1.50x radius', () {
    const size = Size(390, 844);
    final frame = OilTimerMotion.continuousCirculationFrame(size, 0);
    expect(frame.drops, hasLength(OilTimerSimulation.dropCount));
    for (final drop in frame.drops) {
      final h = OilTimerMotion.hash(drop.id, 13);
      final baseline = size.shortestSide * (.032 + .050 * h) * 1.18;
      expect(drop.radius / baseline, closeTo(1.50, .001));
    }
  });

  test('film phase is deterministic and continuous across short samples', () {
    const size = Size(390, 844);
    final first = OilTimerMotion.continuousCirculationFrame(size, 4.0);
    final next = OilTimerMotion.continuousCirculationFrame(size, 4.1);
    expect(first.drops, hasLength(next.drops.length));
    for (var index = 0; index < first.drops.length; index++) {
      expect(next.drops[index].surfacePhase - first.drops[index].surfacePhase,
          closeTo(.032, .001));
    }
  });
}
