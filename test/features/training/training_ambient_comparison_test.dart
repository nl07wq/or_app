import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/training_page.dart';
import 'package:or_app/features/training/widgets/training_ambient_comparison.dart';

void main() {
  test('V7 preserves the connected full-viewport primary gear train', () {
    final gears = TrainingAmbientComparison.kineticGearGeometryFor(
      const Size(390, 2200),
    );
    final main = gears.singleWhere((gear) => gear.id == 'main-drive');

    expect(gears, hasLength(22));
    expect(main.toothCount, 40);
    expect(main.renderedToothTipCount, 40);
    expect(
      TrainingAmbientComparison.kineticGearToothCounts,
      orderedEquals(gears.map((gear) => gear.toothCount)),
    );
    expect(gears.where((gear) => gear.parentId == null), hasLength(1));
    expect(gears.where((gear) => gear.parentId != null), hasLength(21));
    for (final gear in gears) {
      expect(gear.renderedToothTipCount, gear.toothCount);
      expect(gear.tipRadius, greaterThan(gear.pitchRadius));
      expect(gear.rootRadius, lessThan(gear.pitchRadius));
      expect(gear.module, closeTo(main.module, .000001));
    }
  });

  test('V7 primary meshing and drive phases remain mechanically coupled', () {
    final gears = TrainingAmbientComparison.kineticGearGeometryFor(
      const Size(390, 2200),
    );
    final byId = {for (final gear in gears) gear.id: gear};
    for (final child in gears.where((gear) => gear.parentId != null)) {
      final parent = byId[child.parentId]!;
      expect(
        (child.center - parent.center).distance,
        closeTo(child.pitchRadius + parent.pitchRadius, .000001),
      );
      expect(
        child.driveRatio,
        closeTo(
          -parent.driveRatio * parent.toothCount / child.toothCount,
          .000001,
        ),
      );
      for (final phase in [0.0, 1.3, 6.7]) {
        expect(
          child.phaseAt(phase) - child.phaseAt(0),
          closeTo(
            -(parent.phaseAt(phase) - parent.phaseAt(0)) *
                parent.toothCount /
                child.toothCount,
            .000001,
          ),
        );
      }
    }
  });

  test(
    'V7 primary train distributes connected pivots through scroll regions',
    () {
      final gears = TrainingAmbientComparison.kineticGearGeometryFor(
        const Size(390, 2200),
      );
      for (final band in [(0.0, 550.0), (550.0, 1300.0), (1300.0, 2200.0)]) {
        expect(
          gears.where(
            (gear) => gear.center.dy >= band.$1 && gear.center.dy < band.$2,
          ),
          isNotEmpty,
        );
      }
    },
  );

  test('V7 background adds dense, mechanically connected drive groups', () {
    final background =
        TrainingAmbientComparison.kineticBackgroundGearGeometryFor(
          const Size(390, 2200),
        );
    final byId = {for (final gear in background) gear.id: gear};
    final roots = background.where((gear) => gear.parentId == null).toList();

    expect(background, hasLength(32));
    expect(roots, hasLength(4));
    expect(background.map((gear) => gear.id).toSet(), hasLength(32));
    for (final gear in background) {
      expect(gear.renderedToothTipCount, gear.toothCount);
      expect(gear.module, greaterThan(0));
      final parentId = gear.parentId;
      if (parentId == null) continue;
      final parent = byId[parentId]!;
      expect(
        (gear.center - parent.center).distance,
        closeTo(gear.pitchRadius + parent.pitchRadius, .000001),
      );
      expect(
        gear.driveRatio,
        closeTo(
          -parent.driveRatio * parent.toothCount / gear.toothCount,
          .000001,
        ),
      );
    }
  });

  test('V7 background covers both sides across the training scroll extent', () {
    final gears = TrainingAmbientComparison.kineticBackgroundGearGeometryFor(
      const Size(390, 2200),
    );
    for (final band in [(0.0, 550.0), (550.0, 1300.0), (1300.0, 2200.0)]) {
      final inBand = gears
          .where(
            (gear) =>
                gear.center.dy >= band.$1 - 160 &&
                gear.center.dy < band.$2 + 160,
          )
          .toList();
      expect(inBand.where((gear) => gear.center.dx < 195), isNotEmpty);
      expect(inBand.where((gear) => gear.center.dx >= 195), isNotEmpty);
    }
  });

  test('V8 baseplate mounts and bridges resolve to frozen V7 gear pivots', () {
    const size = Size(390, 2200);
    final primary = TrainingAmbientComparison.kineticGearGeometryFor(size);
    final background =
        TrainingAmbientComparison.kineticBackgroundGearGeometryFor(size);
    final plates = TrainingAmbientComparison.kineticBaseplateGeometryFor(
      size,
      primaryGears: primary,
      backgroundGears: background,
    );
    final ids = {...primary.map((gear) => gear.id), ...background.map((gear) => gear.id)};

    expect(primary, hasLength(22));
    expect(background, hasLength(32));
    expect(plates, hasLength(5));
    expect(plates.expand((plate) => plate.mountGearIds), isNotEmpty);
    expect(plates.expand((plate) => plate.bridgeGearIds), isNotEmpty);
    for (final plate in plates) {
      expect(plate.plate.length, greaterThanOrEqualTo(5));
      expect(plate.plate.every((point) => point.dx > -.1 && point.dx < 1.1), isTrue);
      expect(plate.plate.every((point) => point.dy > -.1 && point.dy < 1.1), isTrue);
      expect(plate.mountGearIds.every(ids.contains), isTrue);
      for (final bridge in plate.bridgeGearIds) {
        expect(ids.contains(bridge.$1), isTrue);
        expect(ids.contains(bridge.$2), isTrue);
      }
    }
  });

  test('V8 baseplate spans top, middle and lower scroll regions', () {
    const size = Size(390, 2200);
    final plates = TrainingAmbientComparison.kineticBaseplateGeometryFor(size);
    for (final band in [(0.0, 550.0), (550.0, 1300.0), (1300.0, 2200.0)]) {
      expect(
        plates.where((plate) {
          final top = plate.plate.map((point) => point.dy * size.height).reduce(math.min);
          final bottom = plate.plate.map((point) => point.dy * size.height).reduce(math.max);
          return bottom >= band.$1 && top <= band.$2;
        }),
        isNotEmpty,
      );
    }
  });

  testWidgets(
    'V6 kinetic painter terminates across multiple animation frames',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrainingAmbientComparison(
              variant: TrainingAmbientVariant.kineticEngine,
            ),
          ),
        ),
      );

      for (var frame = 0; frame < 12; frame += 1) {
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('V7 kinetic ambient remains active through training scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: TrainingPage()));
    await tester.tap(
      find.byKey(const ValueKey('training-ambient-kineticEngine')),
    );
    await tester.pump(const Duration(milliseconds: 240));
    final ambient = find.byType(TrainingAmbientComparison);
    expect(ambient, findsOneWidget);
    final contentHeight = tester.getSize(ambient).height;
    expect(contentHeight, greaterThan(tester.view.physicalSize.height));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -620),
    );
    await tester.pump(const Duration(milliseconds: 360));
    expect(tester.getSize(ambient).height, contentHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'V8 baseplate remains behind both V7 gear layers while scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: TrainingPage()));
      await tester.tap(
        find.byKey(const ValueKey('training-ambient-kineticEngine')),
      );
      await tester.pump(const Duration(milliseconds: 1450));
      await expectLater(
        find.byType(TrainingPage),
        matchesGoldenFile('goldens/training_kinetic_engine_v8_top.png'),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -620),
      );
      await tester.pump(const Duration(milliseconds: 2300));
      await expectLater(
        find.byType(TrainingPage),
        matchesGoldenFile('goldens/training_kinetic_engine_v8_middle.png'),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -700),
      );
      await tester.pump(const Duration(milliseconds: 1700));
      await expectLater(
        find.byType(TrainingPage),
        matchesGoldenFile('goldens/training_kinetic_engine_v8_lower.png'),
      );
    },
  );

  test('meshed kinetic gears retain opposite tooth-count velocity ratio', () {
    expect(
      TrainingAmbientComparison.meshedAngularVelocity(
        driveVelocity: .72,
        driveTeeth: 28,
        drivenTeeth: 20,
      ),
      closeTo(-1.008, .0001),
    );
  });

  testWidgets(
    'TRAINING ambient comparison exposes and switches all candidates',
    (tester) async {
      TrainingAmbientVariant selected = TrainingAmbientVariant.magneticFlux;
      late StateSetter update;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: Stack(
                  children: [
                    TrainingAmbientComparison(variant: selected),
                    TrainingAmbientComparisonSelector(
                      selected: selected,
                      onChanged: (variant) =>
                          setState(() => selected = variant),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(TrainingAmbientVariant.values, hasLength(3));
      expect(find.byType(TrainingAmbientComparison), findsOneWidget);
      expect(find.text('MAGNETIC FLUX'), findsOneWidget);
      expect(find.text('KINETIC ENGINE'), findsOneWidget);
      expect(find.text('VECTOR IMPULSE'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('training-ambient-vectorImpulse')),
      );
      await tester.pump();

      expect(selected, TrainingAmbientVariant.vectorImpulse);
      for (final variant in TrainingAmbientVariant.values) {
        expect(
          TrainingAmbientComparison.motionSignatureFor(variant, 0),
          isNot(TrainingAmbientComparison.motionSignatureFor(variant, 3.75)),
        );
        update(() => selected = variant);
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);
      }
    },
  );
}
