import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';

void main() {
  const viewport = Size(390, 844);

  test('shared circulation preserves IDs, collisions and bounded bodies', () {
    final simulation = OilTimerSimulation(viewport);
    final initial = simulation.snapshot();
    simulation.advanceForTest(60);
    final later = simulation.snapshot();
    expect(
      later.drops.map((drop) => drop.id),
      orderedEquals(initial.drops.map((drop) => drop.id)),
    );
    expect(later.drops.every((drop) => drop.squashStrength <= .32), isTrue);
    expect(later.collisionCount, greaterThan(0));
  });

  testWidgets('a debug frame paints the fixed continuous ambient', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(child: FoodAmbientComparison(debugTime: 4)),
      ),
    );
    await tester.pump();
    expect(find.byType(FoodAmbientComparison), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
