import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';
import 'package:or_app/features/training/widgets/training_ambient_comparison.dart';

void main() {
  Future<void> pumpFood(
    WidgetTester tester,
    FoodAmbientVariant variant, [
    Duration elapsed = const Duration(milliseconds: 1600),
  ]) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: FoodAmbientComparison(
            variant: variant,
            debugTime: elapsed.inMicroseconds / Duration.microsecondsPerSecond,
          ),
        ),
      ),
    );
    await tester.pump(elapsed);
  }

  Future<void> pumpTraining(
    WidgetTester tester,
    TrainingAmbientVariant variant, [
    Duration elapsed = const Duration(milliseconds: 1600),
  ]) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: TrainingAmbientComparison(variant: variant),
        ),
      ),
    );
    await tester.pump(elapsed);
  }

  testWidgets('CONTINUOUS CIRCULATION V4.2 visual frame is stable', (
    tester,
  ) async {
    await pumpFood(tester, FoodAmbientVariant.continuousCirculation);
    await expectLater(
      find.descendant(
        of: find.byType(FoodAmbientComparison),
        matching: find.byType(RepaintBoundary),
      ),
      matchesGoldenFile('goldens/food_continuous_circulation_v42_phase_a.png'),
    );
  });

  testWidgets('METABOLIC CELLS V4 visual frame is stable', (tester) async {
    await pumpFood(tester, FoodAmbientVariant.metabolicCells);
    await expectLater(
      find.descendant(
        of: find.byType(FoodAmbientComparison),
        matching: find.byType(RepaintBoundary),
      ),
      matchesGoldenFile('goldens/food_metabolic_cells_v41.png'),
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

  testWidgets('CONTINUOUS CIRCULATION V4.2 remains deterministic later', (
    tester,
  ) async {
    await pumpFood(
      tester,
      FoodAmbientVariant.continuousCirculation,
      const Duration(milliseconds: 5100),
    );
    await expectLater(
      find.descendant(
        of: find.byType(FoodAmbientComparison),
        matching: find.byType(RepaintBoundary),
      ),
      matchesGoldenFile('goldens/food_continuous_circulation_v42_phase_b.png'),
    );
  });

  testWidgets('METABOLIC CELLS V4 remains deterministic at a later phase', (
    tester,
  ) async {
    await pumpFood(
      tester,
      FoodAmbientVariant.metabolicCells,
      const Duration(milliseconds: 5100),
    );
    await expectLater(
      find.descendant(
        of: find.byType(FoodAmbientComparison),
        matching: find.byType(RepaintBoundary),
      ),
      matchesGoldenFile('goldens/food_metabolic_cells_v41_phase_b.png'),
    );
  });

  testWidgets('V4 TRAINING renderers remain deterministic at a later phase', (
    tester,
  ) async {
    for (final variant in const [
      TrainingAmbientVariant.magneticFlux,
      TrainingAmbientVariant.kineticEngine,
    ]) {
      await pumpTraining(tester, variant, const Duration(milliseconds: 5100));
      await expectLater(
        find.descendant(
          of: find.byType(TrainingAmbientComparison),
          matching: find.byType(RepaintBoundary),
        ),
        matchesGoldenFile('goldens/training_${variant.name}_v4_phase_b.png'),
      );
    }
  });
}
