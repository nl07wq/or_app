import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';

void main() {
  const viewport = Size(390, 844);

  test('V2 uses a bounded large, medium, and small droplet field', () {
    final frame = ChromaticFluidMetaballs.frame(viewport, 4.5);

    expect(frame.drops, hasLength(ChromaticFluidMetaballs.dropCount));
    expect(frame.bridges.length, lessThanOrEqualTo(3));
    expect(
      frame.drops.where((drop) => drop.size == ChromaticFluidDropSize.large),
      hasLength(3),
    );
    expect(
      frame.drops.where((drop) => drop.size == ChromaticFluidDropSize.medium),
      hasLength(3),
    );
    expect(
      frame.drops.where((drop) => drop.size == ChromaticFluidDropSize.small),
      hasLength(6),
    );
    expect(ChromaticFluidMetaballs.maximumBridgeCount, 3);
  });

  test('responsive iPhone layouts retain full-height distribution', () {
    for (final size in const [Size(375, 812), Size(390, 844), Size(430, 932)]) {
      final frame = ChromaticFluidMetaballs.frame(size, 7.25);
      final thirds = <bool>[false, false, false];
      for (final drop in frame.drops) {
        expect(
          drop.center.dx,
          inInclusiveRange(-drop.radius, size.width + drop.radius),
        );
        expect(
          drop.center.dy,
          inInclusiveRange(-drop.radius, size.height + drop.radius),
        );
        thirds[(drop.center.dy / (size.height / 3)).floor().clamp(0, 2)] = true;
      }
      expect(thirds, everyElement(isTrue));
      expect(frame.bridges.length, lessThanOrEqualTo(3));
    }
  });

  test(
    'contact strength produces continuous approach, fusion, and separation',
    () {
      final samples = <double>[
        for (final distance in [1.5, 1.4, 1.2, 1.0, .8, .6])
          ChromaticFluidMetaballs.contactStrength(distance),
      ];

      expect(samples.first, 0);
      expect(samples.last, greaterThan(.98));
      for (var index = 1; index < samples.length; index++) {
        expect(samples[index], greaterThanOrEqualTo(samples[index - 1]));
      }
      final beforeFusion = ChromaticFluidMetaballs.frame(viewport, 4.45);
      final fusion = ChromaticFluidMetaballs.frame(viewport, 4.5);
      final afterFusion = ChromaticFluidMetaballs.frame(viewport, 4.55);
      expect(fusion.bridges, isNotEmpty);
      expect(
        (fusion.drops.first.center - beforeFusion.drops.first.center).distance,
        lessThan(2),
      );
      expect(
        (afterFusion.drops.first.center - fusion.drops.first.center).distance,
        lessThan(2),
      );
    },
  );

  test(
    'bridge neck and mixed colour follow contact without residual state',
    () {
      final separated = ChromaticFluidMetaballs.frame(viewport, -4.5);
      final fused = ChromaticFluidMetaballs.frame(viewport, 4.5);
      final pair = fused.bridges.firstWhere(
        (bridge) => bridge.first.id == 0 && bridge.second.id == 1,
      );

      expect(
        separated.bridges.where(
          (bridge) => bridge.first.id == 0 && bridge.second.id == 1,
        ),
        isEmpty,
      );
      expect(pair.strength, greaterThan(.98));
      expect(pair.neckWidth, greaterThan(pair.second.radius * .3));
      expect(pair.path.computeMetrics().single.length, greaterThan(20));
      expect(
        pair.mixedColor,
        Color.lerp(pair.first.color, pair.second.color, .5),
      );
    },
  );

  test('surface deformation evolves independently of center translation', () {
    final first = ChromaticFluidMetaballs.frame(viewport, 2).drops.first;
    final evolved = ChromaticFluidDrop(
      id: first.id,
      center: first.center,
      radius: first.radius,
      color: first.color,
      size: first.size,
      surfacePhase: first.surfacePhase + .8,
    );
    final firstBounds = ChromaticFluidMetaballs.dropPath(first).getBounds();
    final evolvedBounds = ChromaticFluidMetaballs.dropPath(evolved).getBounds();

    expect((firstBounds.width - evolvedBounds.width).abs(), greaterThan(.1));
    expect((firstBounds.height - evolvedBounds.height).abs(), greaterThan(.1));
    expect(first.center, evolved.center);
  });

  testWidgets('animation advances and disposes without lifecycle errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FoodAmbientComparison(variant: FoodAmbientVariant.chromaticFluid),
      ),
    );
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('V2 fusion sequence exposes all six liquid stages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const stages = <(String, double)>[
      ('SEPARATED', -4.5),
      ('APPROACH', -2.0),
      ('BRIDGE', 0.0),
      ('FUSED', 4.5),
      ('NECKING', 9.0),
      ('SEPARATED AGAIN', 13.5),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ColoredBox(
          color: Colors.black,
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 390 / 422,
            children: [
              for (final stage in stages)
                FoodAmbientComparison(
                  key: ValueKey(stage.$1),
                  variant: FoodAmbientVariant.chromaticFluid,
                  debugTime: stage.$2,
                ),
            ],
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(GridView),
      matchesGoldenFile('goldens/food_chromatic_fluid_v2_stages.png'),
    );
  });

  for (final position in const ['top', 'middle', 'lower']) {
    testWidgets('FOOD UI $position keeps V2 readable and populated', (
      tester,
    ) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: FoodPage()));
      await tester.pump(const Duration(milliseconds: 1600));
      final scrollable = find.byType(SingleChildScrollView);
      if (position == 'middle') {
        await tester.drag(scrollable, const Offset(0, -520));
        await tester.pump();
      } else if (position == 'lower') {
        await tester.drag(scrollable, const Offset(0, -1100));
        await tester.pump();
      }

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/food_chromatic_fluid_v2_ui_$position.png'),
      );
    });
  }
}
