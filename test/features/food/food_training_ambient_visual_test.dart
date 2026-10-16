import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';
import 'package:or_app/features/training/widgets/training_ambient_comparison.dart';

void main() {
  Future<void> pumpFood(WidgetTester tester, FoodAmbientVariant variant) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(child: FoodAmbientComparison(variant: variant)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1600));
  }

  Future<void> pumpTraining(
    WidgetTester tester,
    TrainingAmbientVariant variant,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: TrainingAmbientComparison(variant: variant),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1600));
  }

  testWidgets('CHROMATIC FLUID visual frame is stable', (tester) async {
    await pumpFood(tester, FoodAmbientVariant.chromaticFluid);
    await expectLater(
      find.descendant(
        of: find.byType(FoodAmbientComparison),
        matching: find.byType(RepaintBoundary),
      ),
      matchesGoldenFile('goldens/food_chromatic_fluid_v3.png'),
    );
  });

  testWidgets('METABOLIC CELLS visual frame is stable', (tester) async {
    await pumpFood(tester, FoodAmbientVariant.metabolicCells);
    await expectLater(
      find.descendant(
        of: find.byType(FoodAmbientComparison),
        matching: find.byType(RepaintBoundary),
      ),
      matchesGoldenFile('goldens/food_metabolic_cells_v3.png'),
    );
  });

  testWidgets('MAGNETIC FLUX visual frame is stable', (tester) async {
    await pumpTraining(tester, TrainingAmbientVariant.magneticFlux);
    await expectLater(
      find.descendant(
        of: find.byType(TrainingAmbientComparison),
        matching: find.byType(RepaintBoundary),
      ),
      matchesGoldenFile('goldens/training_magnetic_flux_v3.png'),
    );
  });

  testWidgets('KINETIC ENGINE visual frame is stable', (tester) async {
    await pumpTraining(tester, TrainingAmbientVariant.kineticEngine);
    await expectLater(
      find.descendant(
        of: find.byType(TrainingAmbientComparison),
        matching: find.byType(RepaintBoundary),
      ),
      matchesGoldenFile('goldens/training_kinetic_engine_v3.png'),
    );
  });
}
