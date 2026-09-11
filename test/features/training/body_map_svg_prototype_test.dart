import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/services/training_history_domain_service.dart';
import 'package:or_app/features/training/widgets/body_map_svg_prototype.dart';

void main() {
  const front =
      '''<svg><path id="front-body" d="M0 0 L200 0 L200 340 L0 340 Z"/><path id="front-chest-left" d="M10 10 L90 10 L90 90 L10 90 Z"/></svg>''';
  test('parses closed vector paths and rejects raster embeds', () {
    final document = parseSvgBodyMap(front);
    expect(
      document.paths['front-chest-left']!.contains(const Offset(50, 50)),
      isTrue,
    );
    expect(
      document.paths['front-chest-left']!.contains(const Offset(110, 50)),
      isFalse,
    );
    expect(
      () => parseSvgBodyMap('<svg><image href="fake.png"/></svg>'),
      throwsFormatException,
    );
  });

  test('maps semantic regions without a duplicate hit geometry', () {
    expect(
      svgBodyMapMuscles[SvgBodyMapSide.front]!['front-forearm-left'],
      MuscleGroup.forearms,
    );
    expect(
      svgBodyMapMuscles[SvgBodyMapSide.back]!['back-lats-right'],
      MuscleGroup.lats,
    );
    expect(
      svgBodyMapMuscles[SvgBodyMapSide.front]!.keys,
      containsAll([
        'front-chest-left',
        'front-chest-right',
        'front-core',
        'front-quadriceps-left',
        'front-quadriceps-right',
      ]),
    );
    expect(
      svgBodyMapMuscles[SvgBodyMapSide.back]!.keys,
      containsAll([
        'back-trapezius',
        'back-glutes-left',
        'back-hamstrings-right',
        'back-calves-left',
      ]),
    );
  });

  testWidgets('loads both shipped body-map assets with their stable regions', (
    tester,
  ) async {
    final frontDocument = await loadSvgBodyMap(SvgBodyMapSide.front);
    final backDocument = await loadSvgBodyMap(SvgBodyMapSide.back);
    expect(
      frontDocument.paths.keys,
      containsAll(svgBodyMapMuscles[SvgBodyMapSide.front]!.keys),
    );
    expect(
      backDocument.paths.keys,
      containsAll(svgBodyMapMuscles[SvgBodyMapSide.back]!.keys),
    );
    expect(frontDocument.paths['front-body'], isNotNull);
    expect(backDocument.paths['back-body'], isNotNull);
  });
}
