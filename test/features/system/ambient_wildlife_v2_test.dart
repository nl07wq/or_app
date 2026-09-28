import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:or_app/core/theme/app_theme.dart';
import 'package:or_app/features/system/pages/ambient_wildlife_v2.dart';
import 'package:or_app/features/system/pages/bat_v3_flight_motion_poc.dart';
import 'package:or_app/features/system/pages/bat_v3_source_data.dart';
import 'package:or_app/features/system/pages/cat_run_v23_production_preview.dart';

void main() {
  test('V2 registry exposes only CAT and BAT to RANDOM', () {
    expect(AmbientWildlifeV2Registry.availableSpecies, const [
      AmbientWildlifeV2Species.cat,
      AmbientWildlifeV2Species.bat,
    ]);
    expect(
      AmbientWildlifeV2Registry.available(AmbientWildlifeV2Species.fox),
      isFalse,
    );
    expect(
      AmbientWildlifeV2Registry.available(AmbientWildlifeV2Species.birds),
      isFalse,
    );
  });

  test('CAT policy retains its production 5% glitch authority', () {
    final glitch = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.cat,
      leftToRight: true,
      nextInt: (max) => 0,
    );
    final normal = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.cat,
      leftToRight: false,
      nextInt: (max) => max == 20 ? 1 : 0,
    );
    expect(CatRunProductionEventPolicy.glitchProbability, .05);
    expect(glitch.isGlitch, isTrue);
    expect(glitch.catPlan!.crossings, hasLength(10));
    expect(normal.isGlitch, isFalse);
    expect(normal.catPlan!.allowsRecursiveContinuation, isTrue);
  });

  test('BAT policy resolves normal count and replaces it with GLITCH ×10', () {
    final normal = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.bat,
      leftToRight: true,
      nextInt: (max) => max == 20 ? 1 : 85,
    );
    final glitch = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.bat,
      leftToRight: false,
      nextInt: (_) => 0,
    );
    expect(normal.isGlitch, isFalse);
    expect(normal.batInstances, hasLength(3));
    expect(normal.batInstances.map((instance) => instance.phaseOffset), [
      0,
      2,
      5,
    ]);
    expect(glitch.isGlitch, isTrue);
    expect(glitch.batInstances, BatV3ProductionFlight.glitchInstances);
    expect(glitch.batInstances, hasLength(10));
  });

  test('BAT normal count policy uses exact 50/30/20 branches', () {
    expect(BatV3ProductionEventPolicy.normalCountForRoll(0), 1);
    expect(BatV3ProductionEventPolicy.normalCountForRoll(49), 1);
    expect(BatV3ProductionEventPolicy.normalCountForRoll(50), 2);
    expect(BatV3ProductionEventPolicy.normalCountForRoll(79), 2);
    expect(BatV3ProductionEventPolicy.normalCountForRoll(80), 3);
    expect(BatV3ProductionEventPolicy.normalCountForRoll(99), 3);
  });

  testWidgets('neutral species art keeps the shared environment visible', (
    tester,
  ) async {
    Future<void> pumpNeutral(AmbientWildlifeV2Species species) =>
        tester.pumpWidget(
          MaterialApp(
            home: AmbientWildlifeV2Stage(
              plan: null,
              requestId: 0,
              neutral: true,
              neutralSpecies: species,
              paused: false,
              leftToRight: true,
            ),
          ),
        );

    await pumpNeutral(AmbientWildlifeV2Species.cat);
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-environment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-neutral-cat')),
      findsOneWidget,
    );
    final catPainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('ambient-wildlife-v2-neutral-cat')),
                )
                .painter!
            as CatRunV23StagePainter;
    expect(catPainter.neutralFrame02, isTrue);
    expect(catPainter.catUnit, CatRunV23Travel.catUnit);
    expect(catPainter.showGroundLine, isTrue);
    expect(catPainter.groundInset, AmbientWildlifeV2Stage.groundInset);
    expect(catPainter.groundLineColor, AmbientWildlifeV2Stage.groundLineColor);

    await pumpNeutral(AmbientWildlifeV2Species.bat);
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-environment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-neutral-bat')),
      findsOneWidget,
    );
    final bat = tester.widget<BatV3CanonicalFrame>(
      find.byType(BatV3CanonicalFrame),
    );
    expect(bat.pose, BatV3SourceSet.poses[1]);
    expect(find.byType(BatV3ProductionStage), findsNothing);
  });

  testWidgets('CAT production preview restores the FOX ground treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StandardTheme.theme,
        home: const SingleChildScrollView(child: CatRunV23ProductionPreview()),
      ),
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('cat-run-v23-stage')),
                )
                .painter!
            as CatRunV23StagePainter;
    expect(painter.showGroundLine, isTrue);
    expect(painter.groundLineColor, const Color(0xFF43474E));
    expect(painter.groundInset, 5);
    expect(CatRunV23Travel.stageHeight, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CAT motion keeps production size and shared ground', (
    tester,
  ) async {
    final plan = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.cat,
      leftToRight: true,
      nextInt: (max) => max == 20 ? 1 : 0,
    );
    await tester.pumpWidget(_stageHost(plan: null, requestId: 0));
    await tester.pumpWidget(_stageHost(plan: plan, requestId: 1));
    await tester.pump(const Duration(milliseconds: 80));
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('ambient-wildlife-v2-cat-stage')),
                )
                .painter!
            as CatRunV23StagePainter;
    expect(painter.catUnit, CatRunV23Travel.catUnit);
    expect(painter.showGroundLine, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'BAT motion fills the shared stage and enters visibly in both directions',
    (tester) async {
      for (final leftToRight in [true, false]) {
        final plan = AmbientWildlifeV2EventPlan.resolve(
          species: AmbientWildlifeV2Species.bat,
          leftToRight: leftToRight,
          nextInt: (max) => max == 20 ? 1 : 0,
        );

        await tester.pumpWidget(_stageHost(plan: null, requestId: 0));
        await tester.pumpWidget(_stageHost(plan: plan, requestId: 1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1100));

        final stage = find.byKey(const ValueKey('ambient-wildlife-v2-stage'));
        final environment = find.byKey(
          const ValueKey('ambient-wildlife-v2-environment'),
        );
        final bat = find.byKey(const ValueKey('bat-v3-production-instance-0'));
        expect(stage, findsOneWidget);
        expect(environment, findsOneWidget);
        expect(find.byType(BatV3ProductionStage), findsOneWidget);
        expect(bat, findsOneWidget, reason: '$leftToRight');
        expect(tester.getRect(environment), tester.getRect(stage));
        expect(tester.getRect(bat).overlaps(tester.getRect(stage)), isTrue);
        expect(find.byType(Image), findsWidgets);
        expect(
          AmbientWildlifeV2Stage.environmentBackground,
          const Color(0xFF101010),
        );
        expect(AmbientWildlifeV2Stage.groundLineColor, const Color(0xFF383838));
        expect(AmbientWildlifeV2Stage.groundInset, 5);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('BAT normal groups and GLITCH use the shared visible stage', (
    tester,
  ) async {
    for (final configuration in [
      (countRoll: 50, expected: <int>[0, 2]),
      (countRoll: 80, expected: <int>[0, 2, 5]),
      (countRoll: 0, expected: List<int>.generate(10, (index) => index)),
    ]) {
      final plan = AmbientWildlifeV2EventPlan.resolve(
        species: AmbientWildlifeV2Species.bat,
        leftToRight: true,
        nextInt: (max) => max == 20
            ? (configuration.expected.length == 10 ? 0 : 1)
            : configuration.countRoll,
      );
      await tester.pumpWidget(_stageHost(plan: null, requestId: 0));
      await tester.pumpWidget(_stageHost(plan: plan, requestId: 1));
      await tester.pump(const Duration(milliseconds: 1500));

      for (final identifier in configuration.expected) {
        expect(
          find.byKey(ValueKey('bat-v3-production-instance-$identifier')),
          findsOneWidget,
          reason: 'instance $identifier',
        );
      }
      expect(
        find.byKey(const ValueKey('ambient-wildlife-v2-environment')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('BAT remains visible in the fixed stage at target widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plan = AmbientWildlifeV2EventPlan.resolve(
      species: AmbientWildlifeV2Species.bat,
      leftToRight: true,
      nextInt: (max) => max == 20 ? 1 : 0,
    );
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 300);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _stageHost(plan: null, requestId: 0, width: width),
      );
      await tester.pumpWidget(
        _stageHost(plan: plan, requestId: 1, width: width),
      );
      await tester.pump(const Duration(milliseconds: 1100));

      final stage = find.byKey(const ValueKey('ambient-wildlife-v2-stage'));
      final environment = find.byKey(
        const ValueKey('ambient-wildlife-v2-environment'),
      );
      final bat = find.byKey(const ValueKey('bat-v3-production-instance-0'));
      expect(tester.getSize(stage).width, width);
      expect(tester.getRect(environment), tester.getRect(stage));
      expect(tester.getRect(bat).overlaps(tester.getRect(stage)), isTrue);
      expect(tester.takeException(), isNull, reason: '$width');
    }
  });

  testWidgets('neutral CAT and BAT fit the stage at target widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 300);
      tester.view.devicePixelRatio = 1;
      for (final species in [
        AmbientWildlifeV2Species.cat,
        AmbientWildlifeV2Species.bat,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: width,
              child: AmbientWildlifeV2Stage(
                plan: null,
                requestId: 0,
                neutral: true,
                neutralSpecies: species,
                paused: false,
                leftToRight: true,
              ),
            ),
          ),
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('ambient-wildlife-v2-stage')))
              .width,
          width,
        );
        expect(tester.takeException(), isNull, reason: '$species at $width');
      }
    }
  });
}

Widget _stageHost({
  required AmbientWildlifeV2EventPlan? plan,
  required int requestId,
  double width = 390,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      child: AmbientWildlifeV2Stage(
        plan: plan,
        requestId: requestId,
        neutral: false,
        neutralSpecies: AmbientWildlifeV2Species.bat,
        paused: false,
        leftToRight: plan?.leftToRight ?? true,
      ),
    ),
  ),
);
