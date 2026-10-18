import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/food/widgets/food_ambient_comparison.dart';

void main() {
  const viewport = Size(390, 844);

  List<ChromaticFluidFieldContour> pairContours(
    ChromaticFluidField field,
    int first,
    int second,
  ) => field.contours
      .where(
        (contour) =>
            contour.dropIds.contains(first) && contour.dropIds.contains(second),
      )
      .toList();

  double polygonArea(List<Offset> points) {
    var area = 0.0;
    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      area += current.dx * next.dy - next.dx * current.dy;
    }
    return area.abs() * .5;
  }

  test('V3 uses bounded local fields for large, medium, and small drops', () {
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
    expect(field.groupCount, 9);
    expect(
      field.groupCount,
      lessThanOrEqualTo(ChromaticFluidMetaballs.maximumFieldGroupCount),
    );
    expect(
      field.sampleCount,
      lessThanOrEqualTo(ChromaticFluidMetaballs.maximumFieldSampleCount),
    );
    expect(field.contours, isNotEmpty);
  });

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
      expect(field.groupCount, 9);
      expect(
        field.sampleCount,
        lessThanOrEqualTo(ChromaticFluidMetaballs.maximumFieldSampleCount),
      );
    }
  });

  test('implicit topology continuously fuses and separates the same pair', () {
    final separatedFrame = ChromaticFluidMetaballs.frame(viewport, -4.5);
    final separated = ChromaticFluidMetaballs.buildField(
      viewport,
      separatedFrame,
    );
    final fusedFrame = ChromaticFluidMetaballs.frame(viewport, 4.5);
    final fused = ChromaticFluidMetaballs.buildField(viewport, fusedFrame);

    expect(pairContours(separated, 0, 1), hasLength(2));
    expect(pairContours(fused, 0, 1), hasLength(1));
    expect(fusedFrame.contacts, isNotEmpty);
    expect(
      fusedFrame.contacts
          .firstWhere(
            (contact) => contact.first.id == 0 && contact.second.id == 1,
          )
          .strength,
      greaterThan(.98),
    );
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

    final separated = ChromaticFluidMetaballs.frame(viewport, -4.5);
    final fused = ChromaticFluidMetaballs.frame(viewport, 4.5);
    expect(
      separated.contacts.where(
        (contact) => contact.first.id == 0 && contact.second.id == 1,
      ),
      isEmpty,
    );
    final contact = fused.contacts.firstWhere(
      (candidate) => candidate.first.id == 0 && candidate.second.id == 1,
    );
    expect(
      contact.mixedColor,
      Color.lerp(contact.first.color, contact.second.color, .5),
    );
  });

  test(
    'boundary frames have closed smooth contours without spikes or gaps',
    () {
      final transitions = <double>[];
      int? previousCount;
      for (var step = 0; step <= 180; step++) {
        final time = -4.5 + step * .1;
        final frame = ChromaticFluidMetaballs.frame(viewport, time);
        final field = ChromaticFluidMetaballs.buildField(
          viewport,
          frame,
          spacing: 5.2,
        );
        final count = pairContours(field, 0, 1).length;
        if (previousCount != null && count != previousCount) {
          transitions.add(time);
        }
        previousCount = count;
      }
      expect(transitions, hasLength(greaterThanOrEqualTo(2)));
      debugPrint('V3 pair-0 topology transitions: $transitions');

      for (final transition in transitions.take(2)) {
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
          final contours = pairContours(field, 0, 1);
          expect(contours, isNotEmpty);
          areas.add(
            contours.fold(
              0,
              (sum, contour) => sum + polygonArea(contour.samplePoints),
            ),
          );
          for (final contour in contours) {
            expect(contour.path.computeMetrics(), hasLength(1));
            expect(contour.pointCount, greaterThan(12));
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
          expect(relativeChange, lessThan(.045));
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
      'V3 field benchmark: 90 frames in '
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
      'V3 painter benchmark: 60 frames in '
      '${stopwatch.elapsedMicroseconds} us',
    );
    expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('V3 fusion sequence exposes all six continuous field stages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const stages = <(String, double)>[
      ('SEPARATED', -4.5),
      ('APPROACH', -2.0),
      ('FIELD CONTACT', 0.0),
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
      matchesGoldenFile('goldens/food_chromatic_fluid_v3_stages.png'),
    );
  });

  testWidgets('V3 boundary frames remain continuous around fusion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(3120, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const times = [
      -1.55,
      -1.50,
      -1.45,
      -1.40,
      -1.35,
      -1.30,
      -1.25,
      -1.20,
      10.25,
      10.30,
      10.35,
      10.40,
      10.45,
      10.50,
      10.55,
      10.60,
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
      matchesGoldenFile('goldens/food_chromatic_fluid_v3_boundary_frames.png'),
    );
  });

  for (final position in const ['top', 'middle', 'lower']) {
    testWidgets('FOOD UI $position keeps V3 readable and populated', (
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
        matchesGoldenFile('goldens/food_chromatic_fluid_v3_ui_$position.png'),
      );
    });
  }

  testWidgets('FOOD V3 has no overflow at supported iPhone widths', (
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
