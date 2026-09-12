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

  testWidgets(
    'keeps the simplified bodies and bilateral regions geometrically sane',
    (tester) async {
      final front = await loadSvgBodyMap(SvgBodyMapSide.front);
      final back = await loadSvgBodyMap(SvgBodyMapSide.back);
      final frontBody = front.paths['front-body']!.getBounds();
      final backBody = back.paths['back-body']!.getBounds();

      expect(frontBody.width, greaterThan(80));
      expect(frontBody.height, greaterThan(250));
      expect(backBody.width, closeTo(frontBody.width, .01));
      expect(backBody.height, closeTo(frontBody.height, .01));

      for (final document in [front, back]) {
        for (final id in document.paths.keys) {
          final bounds = document.paths[id]!.getBounds();
          expect(bounds.width, greaterThan(0), reason: id);
          expect(bounds.height, greaterThan(0), reason: id);
        }
      }

      _expectMirrorPairs(front, const [
        ('front-chest-left', 'front-chest-right'),
        ('front-shoulder-left', 'front-shoulder-right'),
        ('front-biceps-left', 'front-biceps-right'),
        ('front-forearm-left', 'front-forearm-right'),
        ('front-quadriceps-left', 'front-quadriceps-right'),
      ]);
      _expectMirrorPairs(back, const [
        ('back-lats-left', 'back-lats-right'),
        ('back-shoulder-left', 'back-shoulder-right'),
        ('back-triceps-left', 'back-triceps-right'),
        ('back-forearm-left', 'back-forearm-right'),
        ('back-glutes-left', 'back-glutes-right'),
        ('back-hamstrings-left', 'back-hamstrings-right'),
        ('back-calves-left', 'back-calves-right'),
      ]);
    },
  );
}

void _expectMirrorPairs(
  SvgBodyMapDocument document,
  List<(String, String)> pairs,
) {
  for (final (leftId, rightId) in pairs) {
    final left = document.paths[leftId]!.getBounds();
    final right = document.paths[rightId]!.getBounds();
    expect(left.width, closeTo(right.width, .01), reason: '$leftId width');
    expect(left.height, closeTo(right.height, .01), reason: '$leftId height');
    expect(
      left.center.dx + right.center.dx,
      closeTo(200, .01),
      reason: '$leftId center',
    );
    expect(
      left.center.dy,
      closeTo(right.center.dy, .01),
      reason: '$leftId top',
    );
  }
}
