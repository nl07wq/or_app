import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/core/widgets/operation_card.dart';
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

  test('V11.1 tooth envelope is taller and tips are narrower than V11', () {
    final primary = TrainingAmbientComparison.kineticGearGeometryFor(
      const Size(390, 788),
    );
    final rear = TrainingAmbientComparison.kineticBackgroundGearGeometryFor(
      const Size(390, 788),
    );
    final previousHeight =
        TrainingAmbientComparison.v11ToothRootDedendum +
        TrainingAmbientComparison.v11ToothTipAddendum;
    final currentHeight =
        TrainingAmbientComparison.kineticToothRootDedendum +
        TrainingAmbientComparison.kineticToothTipAddendum;

    expect(currentHeight, greaterThan(previousHeight));
    expect(
      TrainingAmbientComparison.kineticToothTipAngularWidthFraction,
      lessThan(TrainingAmbientComparison.v11ToothTipAngularWidthFraction),
    );
    for (final gear in [...primary, ...rear]) {
      expect(gear.renderedToothTipCount, gear.toothCount);
      expect(gear.pitchRadius, closeTo(gear.module * gear.toothCount, .000001));
      expect(
        gear.tipRadius - gear.pitchRadius,
        closeTo(
          gear.module * TrainingAmbientComparison.kineticToothTipAddendum,
          .000001,
        ),
      );
      expect(
        gear.pitchRadius - gear.rootRadius,
        closeTo(
          gear.module * TrainingAmbientComparison.kineticToothRootDedendum,
          .000001,
        ),
      );
    }
  });

  test('V11.1 tall teeth retain bounded mesh engagement and V11 interiors', () {
    final gears = TrainingAmbientComparison.kineticGearGeometryFor(
      const Size(390, 788),
    );
    final byId = {for (final gear in gears) gear.id: gear};
    for (var i = 0; i < gears.length; i++) {
      final gear = gears[i];
      expect(
        TrainingAmbientComparison.kineticGearVisualVariantFor(gear, i),
        isA<KineticGearVisualVariant>(),
      );
      expect(
        TrainingAmbientComparison.kineticSpokeCountFor(gear, i),
        anyOf(3, 4, 5, 6, 8),
      );
      if (gear.parentId case final parentId?) {
        final parent = byId[parentId]!;
        final centerDistance = (gear.center - parent.center).distance;
        // Tips enter only the partner's dedendum, never by more than .40m.
        expect(
          gear.tipRadius + parent.rootRadius,
          lessThanOrEqualTo(centerDistance + gear.module * .401),
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

  test(
    'V11 assigns dense graphic silhouettes without changing 54 gear geometry',
    () {
      final primary = TrainingAmbientComparison.kineticGearGeometryFor(
        const Size(390, 788),
      );
      final rear = TrainingAmbientComparison.kineticBackgroundGearGeometryFor(
        const Size(390, 788),
      );
      final variants = <KineticGearVisualVariant>{
        for (var i = 0; i < primary.length; i++)
          TrainingAmbientComparison.kineticGearVisualVariantFor(primary[i], i),
        for (var i = 0; i < rear.length; i++)
          TrainingAmbientComparison.kineticGearVisualVariantFor(
            rear[i],
            i,
            background: true,
          ),
      };

      expect([...primary, ...rear], hasLength(54));
      expect(variants, containsAll(KineticGearVisualVariant.values));
      final spokeCounts = <int>{
        for (var i = 0; i < primary.length; i++)
          TrainingAmbientComparison.kineticSpokeCountFor(primary[i], i),
        for (var i = 0; i < rear.length; i++)
          TrainingAmbientComparison.kineticSpokeCountFor(rear[i], i),
      };
      expect(spokeCounts, containsAll([3, 4, 5, 6, 8]));
      expect(
        TrainingAmbientComparison.kineticGearVisualVariantFor(primary.first, 0),
        TrainingAmbientComparison.kineticGearVisualVariantFor(primary.first, 0),
      );
      expect(primary.first.renderedToothTipCount, 40);
    },
  );

  test('V11.3 preserves V11.2 rim boundaries for every silhouette', () {
    expect(
      TrainingAmbientComparison.kineticRimInnerRadiusFactorFor(
        KineticGearVisualVariant.openSpoke,
      ),
      .85,
    );
    expect(
      TrainingAmbientComparison.kineticRimInnerRadiusFactorFor(
        KineticGearVisualVariant.thinRim,
      ),
      .88,
    );
    expect(
      TrainingAmbientComparison.kineticRimInnerRadiusFactorFor(
        KineticGearVisualVariant.ringShortSpoke,
      ),
      .86,
    );
    expect(
      TrainingAmbientComparison.kineticRimInnerRadiusFactorFor(
        KineticGearVisualVariant.cutoutDisc,
      ),
      .84,
    );
    expect(
      TrainingAmbientComparison.kineticRimInnerRadiusFactorFor(
        KineticGearVisualVariant.pinion,
      ),
      .76,
    );
    expect(
      TrainingAmbientComparison.kineticRimInnerRadiusFactorFor(
        KineticGearVisualVariant.asymmetric,
      ),
      .84,
    );
  });

  test('V11.4 assigns four unmistakable interior families on-screen', () {
    final gears = TrainingAmbientComparison.kineticGearGeometryFor(
      const Size(390, 844),
    );
    final byId = {for (final gear in gears) gear.id: gear};
    int indexOf(String id) => gears.indexWhere((gear) => gear.id == id);

    expect(
      TrainingAmbientComparison.kineticGearVisualVariantFor(
        byId['upper-left']!,
        indexOf('upper-left'),
      ),
      KineticGearVisualVariant.openSpoke,
    );
    expect(
      TrainingAmbientComparison.kineticGearVisualVariantFor(
        byId['left-transfer']!,
        indexOf('left-transfer'),
      ),
      KineticGearVisualVariant.thinRim,
    );
    expect(
      TrainingAmbientComparison.kineticGearVisualVariantFor(
        byId['main-drive']!,
        indexOf('main-drive'),
      ),
      KineticGearVisualVariant.ringShortSpoke,
    );
    expect(
      TrainingAmbientComparison.kineticGearVisualVariantFor(
        byId['left-crown']!,
        indexOf('left-crown'),
      ),
      KineticGearVisualVariant.cutoutDisc,
    );
    expect(
      TrainingAmbientComparison.kineticGearVisualVariantFor(
        byId['left-pinion']!,
        indexOf('left-pinion'),
      ),
      KineticGearVisualVariant.pinion,
    );
    expect(
      TrainingAmbientComparison.kineticGearVisualVariantFor(
        byId['upper-right']!,
        indexOf('upper-right'),
      ),
      KineticGearVisualVariant.asymmetric,
    );
  });

  test('V11.5 locomotive linkage stays constrained and reciprocates', () {
    final gears = TrainingAmbientComparison.kineticGearGeometryFor(
      const Size(390, 844),
    );
    final drive = gears.singleWhere((gear) => gear.id == 'mid-crown');
    final reference = TrainingAmbientComparison.kineticSteamLinkagePoseFor(
      drive,
      0,
    );
    final crossheadXs = <double>[];
    final connectingRodAngles = <double>[];

    expect(reference.axleCenters, hasLength(3));
    expect(reference.crankPins, hasLength(3));
    for (final phase in [0.0, math.pi / 2, math.pi, math.pi * 1.5]) {
      final pose = TrainingAmbientComparison.kineticSteamLinkagePoseFor(
        drive,
        phase,
      );
      for (var i = 0; i < pose.crankPins.length; i++) {
        expect(
          (pose.crankPins[i] - pose.axleCenters[i]).distance,
          closeTo(pose.crankRadius, .000001),
        );
      }
      for (var i = 0; i < pose.rodLengths.length; i++) {
        expect(pose.rodLengths[i], closeTo(reference.rodLengths[i], .000001));
      }
      expect(
        (pose.crosshead - pose.crankPins.last).distance,
        closeTo(pose.connectingRodLength, .000001),
      );
      expect(pose.crosshead.dy, closeTo(pose.guideStart.dy, .000001));
      expect(pose.crosshead.dy, closeTo(pose.guideEnd.dy, .000001));
      crossheadXs.add(pose.crosshead.dx);
      connectingRodAngles.add((pose.crosshead - pose.crankPins.last).direction);
    }
    expect(
      crossheadXs.reduce(math.max) - crossheadXs.reduce(math.min),
      greaterThan(reference.crankRadius * 1.5),
    );
    expect(
      connectingRodAngles.reduce(math.max) -
          connectingRodAngles.reduce(math.min),
      greaterThan(.15),
    );
  });

  test('V11.5 rocker keeps both articulated members connected', () {
    final gears = TrainingAmbientComparison.kineticGearGeometryFor(
      const Size(390, 844),
    );
    final drive = gears.singleWhere((gear) => gear.id == 'right-crown');
    for (final phase in [0.0, math.pi / 2, math.pi, math.pi * 1.5]) {
      final pose = TrainingAmbientComparison.kineticRockerLinkagePoseFor(
        drive,
        phase,
      );
      expect(
        (pose.rockerJoint - pose.crankPin).distance,
        closeTo(pose.couplerLength, .000001),
      );
      expect(
        (pose.rockerJoint - pose.fixedPivot).distance,
        closeTo(pose.rockerLength, .000001),
      );
    }
  });

  test('V11.6 hub glow cycles continuously with deterministic ID offsets', () {
    expect(TrainingAmbientComparison.kineticHubGlowPeriodSeconds, 24);
    const id = 'main-drive';
    final offset = TrainingAmbientComparison.kineticHubGlowPhaseOffsetFor(id);
    double timeForPhase(double phase) =>
        ((phase - offset) % 1) *
        TrainingAmbientComparison.kineticHubGlowPeriodSeconds;
    void expectColorClose(Color actual, Color target) {
      expect(actual.r, closeTo(target.r, .001));
      expect(actual.g, closeTo(target.g, .001));
      expect(actual.b, closeTo(target.b, .001));
    }

    expectColorClose(
      TrainingAmbientComparison.kineticHubGlowStateFor(
        id,
        timeForPhase(0),
      ).color,
      const Color(0xffff9f43),
    );
    expectColorClose(
      TrainingAmbientComparison.kineticHubGlowStateFor(
        id,
        timeForPhase(.25),
      ).color,
      const Color(0xffeefcff),
    );
    expectColorClose(
      TrainingAmbientComparison.kineticHubGlowStateFor(
        id,
        timeForPhase(.5),
      ).color,
      const Color(0xff35dcff),
    );
    final beforeLoop = TrainingAmbientComparison.kineticHubGlowStateFor(
      id,
      timeForPhase(1) - .0001,
    ).color;
    final afterLoop = TrainingAmbientComparison.kineticHubGlowStateFor(
      id,
      timeForPhase(0) + .0001,
    ).color;
    expect((beforeLoop.r - afterLoop.r).abs(), lessThan(.001));
    expect((beforeLoop.g - afterLoop.g).abs(), lessThan(.001));
    expect((beforeLoop.b - afterLoop.b).abs(), lessThan(.001));

    final offsets = {
      for (final gearId in const [
        'main-drive',
        'upper-left',
        'right-crown',
        'bottom-crown',
      ])
        TrainingAmbientComparison.kineticHubGlowPhaseOffsetFor(gearId),
    };
    expect(offsets, hasLength(4));
    final simultaneousColors = {
      for (final gearId in const [
        'main-drive',
        'upper-left',
        'right-crown',
        'bottom-crown',
      ])
        TrainingAmbientComparison.kineticHubGlowStateFor(gearId, 7.5).color,
    };
    expect(simultaneousColors.length, greaterThan(1));
  });

  test('V11.6 covers occupy distinct corners with real aperture metadata', () {
    final covers = TrainingAmbientComparison.kineticMechanicalCoversFor(
      const Size(390, 844),
    );
    expect(covers, hasLength(2));
    expect(covers[0].id, 'upper-right-support-bridge');
    expect(covers[0].bounds.top, 0);
    expect(covers[0].bounds.right, 390);
    expect(covers[0].apertureCount, 2);
    expect(covers[0].mounts, hasLength(2));
    expect(covers[1].id, 'lower-left-curved-cover');
    expect(covers[1].bounds.left, 0);
    expect(covers[1].bounds.bottom, 844);
    expect(covers[1].apertureCount, 3);
    expect(covers[1].mounts, hasLength(2));
    expect(covers[0].bounds.overlaps(covers[1].bounds), isFalse);
  });

  test('V11.3 keeps tooth and transmission geometry frozen', () {
    final primary = TrainingAmbientComparison.kineticGearGeometryFor(
      const Size(390, 2200),
    );
    final rear = TrainingAmbientComparison.kineticBackgroundGearGeometryFor(
      const Size(390, 2200),
    );
    expect(primary, hasLength(22));
    expect(rear, hasLength(32));
    expect(primary.first.toothCount, 40);
    expect(primary.first.renderedToothTipCount, 40);
    expect(TrainingAmbientComparison.kineticToothRootDedendum, 1.45);
    expect(TrainingAmbientComparison.kineticToothTipAddendum, 1.85);
    expect(TrainingAmbientComparison.kineticToothTipAngularWidthFraction, .33);
  });

  test('V11 preserves exactly the original transmission inventory', () {
    final primary = TrainingAmbientComparison.kineticGearGeometryFor(
      const Size(390, 788),
    );
    final rear = TrainingAmbientComparison.kineticBackgroundGearGeometryFor(
      const Size(390, 788),
    );

    // V10's separate compound/carrier and thin linkage geometry is removed:
    // the only animated toothed inventory is the frozen 22 + 32 transmission.
    expect(primary, hasLength(22));
    expect(rear, hasLength(32));
    expect([...primary, ...rear].map((gear) => gear.id), hasLength(54));
    expect(
      primary.where((gear) => gear.id == 'main-drive').single.toothCount,
      40,
    );
  });

  test('V9 static anime background asset is bundled unchanged', () async {
    expect(
      TrainingAmbientComparison.kineticEngineBackgroundAsset,
      'assets/images/training/kinetic_engine_v9_background.png',
    );
    final asset = await rootBundle.load(
      TrainingAmbientComparison.kineticEngineBackgroundAsset,
    );
    expect(asset.lengthInBytes, greaterThan(100000));
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

  testWidgets('V11.6 covers and multi-color hubs render through four phases', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _precacheKineticBackground(tester);
    for (var phase = 0; phase < 4; phase++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainingAmbientComparison(
              key: const ValueKey('v11-6-kinetic-phase'),
              variant: TrainingAmbientVariant.kineticEngine,
              debugTime: phase * 12,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byKey(const ValueKey('v11-6-kinetic-phase')),
        matchesGoldenFile(
          'goldens/training_kinetic_engine_v11_6_phase_$phase.png',
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'V11.6 kinetic ambient fills the header viewport and remains fixed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _precacheKineticBackground(tester);
      await tester.pumpWidget(const MaterialApp(home: TrainingPage()));
      await tester.tap(
        find.byKey(const ValueKey('training-ambient-kineticEngine')),
      );
      await tester.pump(const Duration(milliseconds: 240));
      final ambient = find.byType(TrainingAmbientComparison);
      expect(ambient, findsOneWidget);
      final ambientHeight = tester.getSize(ambient).height;
      expect(ambientHeight, tester.view.physicalSize.height);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -620),
      );
      await tester.pump(const Duration(milliseconds: 360));
      expect(tester.getSize(ambient).height, ambientHeight);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('V11.6 UI goldens show transparent header while scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _precacheKineticBackground(tester);
    await tester.pumpWidget(const MaterialApp(home: TrainingPage()));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.extendBodyBehindAppBar, isTrue);
    final appBar = tester.widget<AppBar>(
      find.byKey(const ValueKey('training-page-transparent-appbar')),
    );
    expect(appBar.backgroundColor, Colors.transparent);
    expect(appBar.surfaceTintColor, Colors.transparent);
    await tester.tap(
      find.byKey(const ValueKey('training-ambient-kineticEngine')),
    );
    await tester.pump(const Duration(milliseconds: 1450));
    await tester.pump();
    await expectLater(
      find.byType(TrainingPage),
      matchesGoldenFile('goldens/training_kinetic_engine_v11_6_top.png'),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -620),
    );
    await tester.pump(const Duration(milliseconds: 2300));
    await expectLater(
      find.byType(TrainingPage),
      matchesGoldenFile('goldens/training_kinetic_engine_v11_6_middle.png'),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pump(const Duration(milliseconds: 1700));
    await expectLater(
      find.byType(TrainingPage),
      matchesGoldenFile('goldens/training_kinetic_engine_v11_6_lower.png'),
    );
  });

  testWidgets('TRAINING actions use STATUS glass buttons without outer cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: TrainingPage()));

    for (final label in const [
      'TRAINING ENTRY',
      'TRAINING PLAN',
      'RECORD',
      'TRAINING ANALYSIS REPORT',
      'SYNC TRAINING',
    ]) {
      final buttonFinder = find.byWidgetPredicate(
        (widget) => widget is OperationButton && widget.text == label,
      );
      expect(buttonFinder, findsOneWidget);
      expect(
        tester.widget<OperationButton>(buttonFinder).dashboardGlass,
        isTrue,
      );
      expect(
        find.ancestor(of: buttonFinder, matching: find.byType(OperationCard)),
        findsNothing,
      );
    }
  });

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

Future<void> _precacheKineticBackground(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (value) {
          context = value;
          return const SizedBox.expand();
        },
      ),
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage(TrainingAmbientComparison.kineticEngineBackgroundAsset),
      context,
    ),
  );
}
