import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';

void main() {
  const viewport = Size(390, 844);

  Future<void> pumpAmbient(
    WidgetTester tester,
    FoodAmbientVariant variant,
    double time,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: FoodAmbientComparison(variant: variant, debugTime: time),
        ),
      ),
    );
    await tester.pump();
  }

  test('gravity flip has a continuous 48-second loop', () {
    final start = OilTimerMotion.gravityFlipFrame(viewport, 0);
    final end = OilTimerMotion.gravityFlipFrame(
      viewport,
      OilTimerMotion.cycleSeconds,
    );

    expect(start.drops, hasLength(OilTimerMotion.dropCount));
    expect(end.drops, hasLength(OilTimerMotion.dropCount));
    for (var index = 0; index < start.drops.length; index++) {
      expect(
        (start.drops[index].center - end.drops[index].center).distance,
        lessThan(.001),
      );
      expect(start.drops[index].radius, end.drops[index].radius);
    }
  });

  test('oil timer contact only compresses and separates droplets', () {
    final frame = OilTimerMotion.gravityFlipFrame(viewport, 9.5);
    var contacts = 0;
    for (var first = 0; first < frame.drops.length - 1; first++) {
      for (var second = first + 1; second < frame.drops.length; second++) {
        final a = frame.drops[first];
        final b = frame.drops[second];
        if ((a.center - b.center).distance < a.radius + b.radius) {
          contacts++;
          expect(a.color, isNot(b.color));
        }
      }
    }
    expect(contacts, lessThanOrEqualTo(OilTimerMotion.maximumContactCount));
    expect(frame.drops.every((drop) => drop.squashStrength <= .58), isTrue);
  });

  test('continuous circulation only wraps outside the visible viewport', () {
    final before = OilTimerMotion.continuousCirculationFrame(viewport, 0);
    final later = OilTimerMotion.continuousCirculationFrame(viewport, 8);

    expect(before.drops, hasLength(OilTimerMotion.dropCount));
    expect(later.drops, hasLength(OilTimerMotion.dropCount));
    expect(
      before.drops.any((drop) => drop.center.dy < 0) &&
          before.drops.any((drop) => drop.center.dy > viewport.height),
      isTrue,
    );
  });

  testWidgets('renders gravity flip progression golden', (tester) async {
    await pumpAmbient(tester, FoodAmbientVariant.gravityFlip, 0);
    await expectLater(
      find.byType(FoodAmbientComparison),
      matchesGoldenFile('goldens/food_gravity_flip_v4_start.png'),
    );
    await pumpAmbient(tester, FoodAmbientVariant.gravityFlip, 17);
    await expectLater(
      find.byType(FoodAmbientComparison),
      matchesGoldenFile('goldens/food_gravity_flip_v4_flip.png'),
    );
    await pumpAmbient(tester, FoodAmbientVariant.gravityFlip, 26);
    await expectLater(
      find.byType(FoodAmbientComparison),
      matchesGoldenFile('goldens/food_gravity_flip_v4_settle.png'),
    );
  });

  testWidgets('renders continuous circulation progression golden', (
    tester,
  ) async {
    await pumpAmbient(tester, FoodAmbientVariant.continuousCirculation, 1);
    await expectLater(
      find.byType(FoodAmbientComparison),
      matchesGoldenFile('goldens/food_continuous_circulation_v4_top.png'),
    );
    await pumpAmbient(tester, FoodAmbientVariant.continuousCirculation, 16);
    await expectLater(
      find.byType(FoodAmbientComparison),
      matchesGoldenFile('goldens/food_continuous_circulation_v4_lower.png'),
    );
  });

  testWidgets('renders restored cellular anatomy golden', (tester) async {
    await pumpAmbient(tester, FoodAmbientVariant.metabolicCells, 6);
    await expectLater(
      find.byType(FoodAmbientComparison),
      matchesGoldenFile('goldens/food_metabolic_cells_v4_anatomy.png'),
    );
  });

  for (final width in const [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('renders all V4 ambients without overflow at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final variant in FoodAmbientVariant.values) {
        await pumpAmbient(tester, variant, 7);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
