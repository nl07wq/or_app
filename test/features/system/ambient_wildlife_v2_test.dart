import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:or_app/features/system/pages/ambient_wildlife_v2.dart';
import 'package:or_app/features/system/pages/bat_v3_flight_motion_poc.dart';
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

    await pumpNeutral(AmbientWildlifeV2Species.bat);
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-environment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ambient-wildlife-v2-neutral-bat')),
      findsOneWidget,
    );
    expect(find.byType(BatV3ProductionStage), findsNothing);
  });
}
