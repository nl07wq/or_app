import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';

void main() {
  const viewport = Size(390, 844);

  double polygonArea(List<Offset> points) {
    var area = 0.0;
    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      area += current.dx * next.dy - next.dx * current.dy;
    }
    return area.abs() * .5;
  }

  double colorDistance(Color first, Color second) =>
      (first.r - second.r).abs() +
      (first.g - second.g).abs() +
      (first.b - second.b).abs();

  test(
    'V3.4 uses bounded dynamic fields for large, medium, and small drops',
    () {
      final frame = ChromaticFluidMetaballs.frame(viewport, 4.5);
      final field = ChromaticFluidMetaballs.buildField(viewport, frame);

      expect(frame.drops, hasLength(ChromaticFluidMetaballs.dropCount));
      expect(
        frame.contacts.length,
        lessThanOrEqualTo(ChromaticFluidMetaballs.maximumContactCount),
      );
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
      expect(frame.particles, hasLength(26));
      expect(field.groupCount, lessThanOrEqualTo(12));
      expect(
        field.groupCount,
        lessThanOrEqualTo(ChromaticFluidMetaballs.maximumFieldGroupCount),
      );
      expect(
        field.sampleCount,
        lessThanOrEqualTo(ChromaticFluidMetaballs.maximumFieldSampleCount),
      );
      expect(field.contours, isNotEmpty);
    },
  );

  test('responsive iPhone layouts retain full-height distribution', () {
    for (final size in const [
      Size(320, 568),
      Size(375, 812),
      Size(390, 844),
      Size(430, 932),
    ]) {
      final frame = ChromaticFluidMetaballs.frame(size, 7.25);
      final field = ChromaticFluidMetaballs.buildField(size, frame);
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
      expect(
        field.groupCount,
        lessThanOrEqualTo(ChromaticFluidMetaballs.maximumFieldGroupCount),
      );
      expect(
        field.sampleCount,
        lessThanOrEqualTo(ChromaticFluidMetaballs.maximumFieldSampleCount),
      );
    }
  });

  test(
    'dynamic neighbourhood selection produces two and three-drop fields',
    () {
      final contactedPairs = <String>{};
      var sawThreeDropField = false;
      for (var step = 0; step <= 240; step++) {
        final frame = ChromaticFluidMetaballs.frame(viewport, step * .25);
        final field = ChromaticFluidMetaballs.buildField(viewport, frame);
        for (final contact in frame.contacts) {
          final ids = [contact.first.id, contact.second.id]..sort();
          contactedPairs.add('${ids.first}:${ids.last}');
        }
        sawThreeDropField |= field.contours.any(
          (contour) => contour.dropIds.length >= 3,
        );
      }
      expect(contactedPairs.length, greaterThanOrEqualTo(5));
      expect(sawThreeDropField, isTrue);
    },
  );

  test(
    'small drops continuously absorb, separate, and retain a particle layer',
    () {
      var sawAbsorption = false;
      var sawSeparation = false;
      var sawBubble = false;
      var sawLightParticle = false;
      for (var step = 0; step <= 600; step++) {
        final frame = ChromaticFluidMetaballs.frame(viewport, step * .1);
        for (final drop in frame.drops.where(
          (drop) => drop.size == ChromaticFluidDropSize.small,
        )) {
          sawAbsorption |= drop.absorption > .85 && drop.hostId != null;
          sawSeparation |=
              drop.absorption < .05 && drop.radius > drop.baseRadius * .95;
          expect(drop.radius, greaterThan(drop.baseRadius * .16));
          expect(drop.radius, lessThanOrEqualTo(drop.baseRadius));
        }
        sawBubble |= frame.particles.any((particle) => particle.isBubble);
        sawLightParticle |= frame.particles.any(
          (particle) => !particle.isBubble,
        );
      }
      expect(sawAbsorption, isTrue);
      expect(sawSeparation, isTrue);
      expect(sawBubble, isTrue);
      expect(sawLightParticle, isTrue);
    },
  );

  test(
    'V3.4 keeps every absorbed small-drop field contribution continuous',
    () {
      for (var step = 0; step <= 900; step++) {
        final frame = ChromaticFluidMetaballs.frame(viewport, step / 10);
        for (final drop in frame.drops) {
          expect(drop.radius, greaterThanOrEqualTo(drop.baseRadius * .48));
          expect(drop.center.dx.isFinite && drop.center.dy.isFinite, isTrue);
        }
        final field = ChromaticFluidMetaballs.buildField(viewport, frame);
        expect(field.contours, isNotEmpty);
      }
    },
  );

  test('V3.4 reconstructs one smooth multi-pigment velocity-density fluid', () {
    final first = HighFidelityChromaticFluid.frame(viewport, 2.0);
    final later = HighFidelityChromaticFluid.frame(viewport, 7.0);
    expect(first.cells, isNotEmpty);
    expect(
      first.sampleCount,
      lessThanOrEqualTo(HighFidelityChromaticFluid.maximumSampleCount),
    );
    expect(first.outline.getBounds().overlaps(Offset.zero & viewport), isTrue);
    expect(
      first.cells.map((cell) => cell.color).toSet(),
      isNot(equals(later.cells.map((cell) => cell.color).toSet())),
    );
    expect(
      first.cells.map((cell) => cell.color).toSet().length,
      greaterThan(12),
    );
    expect(
      first.cells.map((cell) => cell.radius).reduce(math.min),
      greaterThan(0),
    );
    expect(first.cells.any((cell) => cell.velocity.distance > .1), isTrue);
    expect(first.ribbons, hasLength(5));
  });

  test('V3.4 preserves geometry, pigment, and flow across loop boundaries', () {
    final start = ChromaticFluidMetaballs.frame(viewport, 0);
    final end = ChromaticFluidMetaballs.frame(
      viewport,
      ChromaticFluidMetaballs.cycleSeconds,
    );
    expect(end.drops, hasLength(start.drops.length));
    for (var index = 0; index < start.drops.length; index++) {
      expect(
        (start.drops[index].center - end.drops[index].center).distance,
        lessThan(.001),
      );
      expect(
        (start.drops[index].radius - end.drops[index].radius).abs(),
        lessThan(.001),
      );
      expect(
        colorDistance(start.drops[index].color, end.drops[index].color),
        lessThan(.001),
      );
    }
    expect(end.particles, hasLength(start.particles.length));
    for (var index = 0; index < start.particles.length; index++) {
      expect(
        (start.particles[index].center - end.particles[index].center).distance,
        lessThan(.001),
      );
      expect(
        (start.particles[index].opacity - end.particles[index].opacity).abs(),
        lessThan(.001),
      );
    }

    final startField = ChromaticFluidMetaballs.buildField(viewport, start);
    final endField = ChromaticFluidMetaballs.buildField(viewport, end);
    expect(endField.sampleCount, startField.sampleCount);
    expect(endField.contours.length, startField.contours.length);
    final startArea = startField.contours.fold<double>(
      0,
      (sum, contour) => sum + polygonArea(contour.samplePoints),
    );
    final endArea = endField.contours.fold<double>(
      0,
      (sum, contour) => sum + polygonArea(contour.samplePoints),
    );
    expect((startArea - endArea).abs(), lessThan(.01));

    final startFluid = HighFidelityChromaticFluid.frame(viewport, 0);
    final endFluid = HighFidelityChromaticFluid.frame(
      viewport,
      HighFidelityChromaticFluid.cycleSeconds,
    );
    expect(
      (startFluid.bounds.center - endFluid.bounds.center).distance,
      lessThan(.001),
    );
    expect(startFluid.cells.length, endFluid.cells.length);
    for (var index = 0; index < startFluid.cells.length; index += 19) {
      final first = startFluid.cells[index];
      final last = endFluid.cells[index];
      expect((first.center - last.center).distance, lessThan(.001));
      expect((first.density - last.density).abs(), lessThan(.001));
      expect(colorDistance(first.color, last.color), lessThan(.001));
      expect((first.velocity - last.velocity).distance, lessThan(.001));
    }

    final before = ChromaticFluidMetaballs.frame(
      viewport,
      ChromaticFluidMetaballs.cycleSeconds - .05,
    );
    final after = ChromaticFluidMetaballs.frame(viewport, .05);
    for (var index = 0; index < before.drops.length; index++) {
      expect(
        (before.drops[index].center - after.drops[index].center).distance,
        lessThan(viewport.shortestSide * .04),
      );
    }

    // The enclosing controller repeats at 48 seconds, exactly two field
    // cycles. Verify that its own seam carries the same state as frame zero.
    final controllerEnd = ChromaticFluidMetaballs.frame(viewport, 48);
    for (var index = 0; index < start.drops.length; index++) {
      expect(
        (start.drops[index].center - controllerEnd.drops[index].center)
            .distance,
        lessThan(.001),
      );
    }
  });

  test('V3.4 high-fidelity fluid remains a bounded local workload', () {
    final stopwatch = Stopwatch()..start();
    var maximumSamples = 0;
    for (var frameIndex = 0; frameIndex < 90; frameIndex++) {
      final frame = HighFidelityChromaticFluid.frame(viewport, frameIndex / 5);
      maximumSamples = math.max(maximumSamples, frame.sampleCount);
      expect(frame.ribbons, hasLength(5));
    }
    stopwatch.stop();
    debugPrint(
      'V3.4 fluid benchmark: 90 frames in '
      '${stopwatch.elapsedMicroseconds} us, max samples $maximumSamples',
    );
    expect(
      maximumSamples,
      lessThanOrEqualTo(HighFidelityChromaticFluid.maximumSampleCount),
    );
    expect(stopwatch.elapsedMilliseconds, lessThan(3000));
  });

  test('contact strength is monotonic and leaves no residual mixed state', () {
    final samples = <double>[
      for (final distance in [1.5, 1.4, 1.2, 1.0, .8, .6])
        ChromaticFluidMetaballs.contactStrength(distance),
    ];
    expect(samples.first, 0);
    expect(samples.last, greaterThan(.98));
    for (var index = 1; index < samples.length; index++) {
      expect(samples[index], greaterThanOrEqualTo(samples[index - 1]));
    }

    final fused = List.generate(
      240,
      (step) => ChromaticFluidMetaballs.frame(viewport, step * .25),
    ).firstWhere((frame) => frame.contacts.isNotEmpty);
    final contact = fused.contacts.first;
    expect(
      contact.mixedColor,
      Color.lerp(contact.first.color, contact.second.color, .5),
    );
  });

  test(
    'dynamic boundary frames have closed smooth contours without spikes or gaps',
    () {
      final transitions = <double>[];
      int? previousCount;
      for (var step = 0; step <= 600; step++) {
        final time = step * .1;
        final frame = ChromaticFluidMetaballs.frame(viewport, time);
        final field = ChromaticFluidMetaballs.buildField(
          viewport,
          frame,
          spacing: 5.2,
        );
        final count = field.contours.length;
        if (previousCount != null && count != previousCount) {
          transitions.add(time);
        }
        previousCount = count;
      }
      expect(transitions, hasLength(greaterThanOrEqualTo(4)));
      debugPrint('V3.4 dynamic topology transitions: $transitions');

      for (final transition in transitions.take(3)) {
        final areas = <double>[];
        for (final offset in [-.08, -.04, 0.0, .04, .08]) {
          final frame = ChromaticFluidMetaballs.frame(
            viewport,
            transition + offset,
          );
          final field = ChromaticFluidMetaballs.buildField(
            viewport,
            frame,
            spacing: 4,
          );
          final contours = field.contours;
          expect(contours, isNotEmpty);
          areas.add(
            contours.fold(
              0,
              (sum, contour) => sum + polygonArea(contour.samplePoints),
            ),
          );
          for (final contour in contours) {
            expect(contour.path.computeMetrics(), hasLength(1));
            expect(contour.pointCount, greaterThanOrEqualTo(12));
            for (var index = 0; index < contour.samplePoints.length; index++) {
              final current = contour.samplePoints[index];
              final next = contour
                  .samplePoints[(index + 1) % contour.samplePoints.length];
              expect((next - current).distance, lessThan(5.8));
              expect(current.dx.isFinite && current.dy.isFinite, isTrue);
            }
          }
        }
        for (var index = 1; index < areas.length; index++) {
          final relativeChange =
              (areas[index] - areas[index - 1]).abs() /
              math.max(areas[index], areas[index - 1]);
          expect(relativeChange, lessThan(.18));
        }
      }
    },
  );

  test('field construction remains bounded across animation frames', () {
    final stopwatch = Stopwatch()..start();
    var maximumSamples = 0;
    for (var frameIndex = 0; frameIndex < 90; frameIndex++) {
      final frame = ChromaticFluidMetaballs.frame(viewport, frameIndex / 5);
      final field = ChromaticFluidMetaballs.buildField(viewport, frame);
      maximumSamples = math.max(maximumSamples, field.sampleCount);
      expect(field.contours.length, lessThanOrEqualTo(12));
    }
    stopwatch.stop();
    debugPrint(
      'V3.4 field benchmark: 90 frames in '
      '${stopwatch.elapsedMicroseconds} us, max samples $maximumSamples',
    );
    expect(
      maximumSamples,
      lessThanOrEqualTo(ChromaticFluidMetaballs.maximumFieldSampleCount),
    );
    expect(stopwatch.elapsedMilliseconds, lessThan(3000));
  });

  testWidgets('animation advances, respects TickerMode, and disposes cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(
          enabled: false,
          child: FoodAmbientComparison(
            variant: FoodAmbientVariant.chromaticFluid,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 750));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('painter sustains a bounded multi-frame workload', (
    tester,
  ) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: FoodAmbientComparison(variant: FoodAmbientVariant.chromaticFluid),
      ),
    );
    final stopwatch = Stopwatch()..start();
    for (var index = 0; index < 60; index++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    stopwatch.stop();
    debugPrint(
      'V3.4 painter benchmark: 60 frames in '
      '${stopwatch.elapsedMicroseconds} us',
    );
    expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('V3.4 fusion sequence exposes organic dynamic field stages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const stages = <(String, double)>[
      ('DYNAMIC A', 0.0),
      ('DYNAMIC B', 8.0),
      ('DYNAMIC C', 16.0),
      ('DYNAMIC D', 28.0),
      ('DYNAMIC E', 40.0),
      ('DYNAMIC F', 52.0),
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
      matchesGoldenFile('goldens/food_chromatic_fluid_v3_4_stages.png'),
    );
  });

  testWidgets('V3.4 boundary frames remain continuous around dynamic fusion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(3120, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const times = [
      10.00,
      10.05,
      10.10,
      10.15,
      10.20,
      10.25,
      10.30,
      10.35,
      31.00,
      31.05,
      31.10,
      31.15,
      31.20,
      31.25,
      31.30,
      31.35,
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 8,
          childAspectRatio: 390 / 422,
          children: [
            for (final time in times)
              FoodAmbientComparison(
                variant: FoodAmbientVariant.chromaticFluid,
                debugTime: time,
              ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(GridView),
      matchesGoldenFile(
        'goldens/food_chromatic_fluid_v3_4_boundary_frames.png',
      ),
    );
  });

  testWidgets('V3.4 loop boundary has no visual rewind', (tester) async {
    tester.view.physicalSize = const Size(2340, 422);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const times = [23.70, 23.85, 23.95, 0.0, .05, .15];
    await tester.pumpWidget(
      MaterialApp(
        home: GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 6,
          childAspectRatio: 390 / 422,
          children: [
            for (final time in times)
              FoodAmbientComparison(
                variant: FoodAmbientVariant.chromaticFluid,
                debugTime: time,
              ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(GridView),
      matchesGoldenFile('goldens/food_chromatic_fluid_v3_4_loop_boundary.png'),
    );
  });

  for (final position in const ['top', 'middle', 'lower']) {
    testWidgets('FOOD UI $position keeps V3.4 readable and populated', (
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
        matchesGoldenFile('goldens/food_chromatic_fluid_v3_4_ui_$position.png'),
      );
    });
  }

  testWidgets('FOOD V3.4 has no overflow at supported iPhone widths', (
    tester,
  ) async {
    for (final size in const [
      Size(320, 568),
      Size(375, 812),
      Size(390, 844),
      Size(430, 932),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: FoodPage()));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: 'viewport $size');
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'scrolled viewport $size');
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
