import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';

void main() {
  const viewport = Size(390, 844);

  Future<void> pumpAmbient(
    WidgetTester tester,
    FoodAmbientVariant variant,
    double time, {
    Size? surfaceSize,
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize ?? viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: FoodAmbientComparison(variant: variant, debugTime: time),
        ),
      ),
    );
    await tester.pump();
  }

  test('stateful circulation has stable IDs, bounded speed and collisions', () {
    final simulation = OilTimerSimulation(viewport);
    final initial = simulation.snapshot();
    simulation.advanceForTest(60);
    final later = simulation.snapshot();
    expect(initial.drops, hasLength(OilTimerSimulation.dropCount));
    expect(
      later.drops.map((drop) => drop.id),
      orderedEquals(initial.drops.map((drop) => drop.id)),
    );
    expect(later.drops.every((drop) => drop.squashStrength <= .32), isTrue);
    expect(later.collisionCount, greaterThan(0));
    expect(later.landingCount, greaterThanOrEqualTo(2));
    expect(later.reboundCount, greaterThanOrEqualTo(3));
    expect(later.sinkOutCount, greaterThanOrEqualTo(2));
    expect(later.settlingDropCount, greaterThanOrEqualTo(0));
  });

  test('circulation is continuous through a nominal 48-second boundary', () {
    final simulation = OilTimerSimulation(viewport);
    simulation.advanceForTest(47.99);
    final before = simulation.snapshot();
    simulation.advanceForTest(.02);
    final after = simulation.snapshot();
    for (var i = 0; i < before.drops.length; i++) {
      final a = before.drops[i];
      final b = after.drops[i];
      if (a.center.dy >= -a.radius &&
          a.center.dy <= viewport.height + a.radius &&
          b.center.dy >= -b.radius &&
          b.center.dy <= viewport.height + b.radius) {
        expect((a.center - b.center).distance, lessThan(4));
      }
    }
  });

  testWidgets('renders continuous circulation progression golden', (
    tester,
  ) async {
    for (final second in [
      0.0,
      3.0,
      8.0,
      15.0,
      25.0,
      40.0,
      47.99,
      48.01,
      60.0,
    ]) {
      await pumpAmbient(
        tester,
        FoodAmbientVariant.continuousCirculation,
        second,
      );
      await expectLater(
        find.byType(FoodAmbientComparison),
        matchesGoldenFile(
          'goldens/food_continuous_circulation_v41_$second.png',
        ),
      );
    }
  });

  testWidgets('renders restored cellular anatomy golden', (tester) async {
    for (final second in [0.0, 5.0, 10.0, 20.0]) {
      await pumpAmbient(tester, FoodAmbientVariant.metabolicCells, second);
      await expectLater(
        find.byType(FoodAmbientComparison),
        matchesGoldenFile('goldens/food_metabolic_cells_v41_$second.png'),
      );
    }
  });

  for (final width in const [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('renders all V4 ambients without overflow at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final variant in FoodAmbientVariant.values) {
        await pumpAmbient(tester, variant, 7, surfaceSize: Size(width, 844));
        expect(tester.takeException(), isNull);
      }
    });
  }
}
