import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/training_page.dart';
import 'package:or_app/features/training/widgets/training_ambient_comparison.dart';

void main() {
  test('V6.2 has a connected full-viewport gear train', () {
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

  test('V6.2 meshing and drive phases remain mechanically coupled', () {
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

  test('V6.2 distributes connected pivots through training scroll regions', () {
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

  testWidgets('V6.2 kinetic ambient remains active through training scroll', (
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
    'V6.2 full-page mechanical composition remains visible while scrolling',
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
        matchesGoldenFile('goldens/training_kinetic_engine_v6_2_top.png'),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -620),
      );
      await tester.pump(const Duration(milliseconds: 2300));
      await expectLater(
        find.byType(TrainingPage),
        matchesGoldenFile('goldens/training_kinetic_engine_v6_2_middle.png'),
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
