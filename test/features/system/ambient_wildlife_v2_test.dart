import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/ambient_wildlife_v2.dart';
import 'package:or_app/features/system/pages/bat_v3_flight_motion_poc.dart';
import 'package:or_app/features/system/pages/cat_run_v23_production_preview.dart';

void main() {
  test('V2 registry exposes only CAT and BAT to AUTO', () {
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
      nextInt: (max) => max == 20 ? 1 : 2,
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
}
