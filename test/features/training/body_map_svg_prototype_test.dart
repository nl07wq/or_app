import 'dart:ui' show Path, PathOperation;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:or_app/core/theme/app_colors.dart';
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

  test('uses one canonical visual color for every recovery state', () {
    expect(bodyMapRecoveryColor(RecoveryStatus.loaded), AppColors.danger);
    expect(bodyMapRecoveryColor(RecoveryStatus.recovering), AppColors.warning);
    expect(bodyMapRecoveryColor(RecoveryStatus.nearReady), AppColors.primary);
    expect(
      bodyMapRecoveryColor(RecoveryStatus.estimatedReady),
      AppColors.success,
    );
    expect(bodyMapRecoveryColor(RecoveryStatus.noData), AppColors.secondary);
  });

  test(
    'unions connected trapezius subpaths but preserves core panels',
    () async {
      final back = await loadSvgBodyMap(SvgBodyMapSide.back);
      final trapezius = back.paths['back-trapezius']!;
      expect(
        svgBodyMapPathCompositionFor('back-trapezius'),
        SvgBodyMapPathComposition.connectedComposite,
      );
      expect(
        svgBodyMapPathCompositionFor('front-core'),
        SvgBodyMapPathComposition.disconnectedMultiPanel,
      );
      expect(
        svgBodyMapPathCompositionFor('front-chest-left'),
        SvgBodyMapPathComposition.single,
      );
      expect(trapezius.contains(const Offset(100, 70)), isTrue);
      expect(trapezius.contains(const Offset(100, 87)), isTrue);
      expect(trapezius.contains(const Offset(100, 55)), isFalse);
    },
  );

  test('connected composite parsing removes the internal overlap contour', () {
    final document = parseSvgBodyMap(
      '<svg><path id="back-trapezius" d="M0 0 L10 0 L10 10 L0 10 Z M5 5 L15 5 L15 15 L5 15 Z"/></svg>',
    );
    final path = document.paths['back-trapezius']!;
    expect(path.computeMetrics(), hasLength(1));
    expect(path.contains(const Offset(2, 2)), isTrue);
    expect(path.contains(const Offset(12, 12)), isTrue);
    expect(path.contains(const Offset(20, 20)), isFalse);
  });

  testWidgets('keeps six visual core panels as one logical core path', (
    tester,
  ) async {
    const corePanels = [
      Offset(90, 132),
      Offset(110, 132),
      Offset(90, 151),
      Offset(110, 151),
      Offset(90, 170),
      Offset(110, 170),
    ];
    final core = (await loadSvgBodyMap(
      SvgBodyMapSide.front,
    )).paths['front-core']!;

    final components = core.computeMetrics().toList();
    expect(components, hasLength(6));
    expect(components.every((component) => component.length > 0), isTrue);
    for (final point in corePanels) {
      expect(core.contains(point), isTrue, reason: '$point is a core panel');
    }
    expect(core.contains(const Offset(100, 132)), isFalse);
    expect(
      svgBodyMapMuscles[SvgBodyMapSide.front]!['front-core'],
      MuscleGroup.core,
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
    expect(frontDocument.paths['front-core']!.computeMetrics(), hasLength(6));
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

  testWidgets(
    'uses one mechanically equivalent body silhouette on both sides',
    (tester) async {
      final frontSvg = await rootBundle.loadString(
        'assets/body_map/body_map_front.svg',
      );
      final backSvg = await rootBundle.loadString(
        'assets/body_map/body_map_back.svg',
      );

      expect(
        _bodyPathData(frontSvg, 'front-body'),
        _bodyPathData(backSvg, 'back-body'),
      );
    },
  );

  testWidgets('keeps adjacent torso regions visibly separate', (tester) async {
    final front = await loadSvgBodyMap(SvgBodyMapSide.front);
    final back = await loadSvgBodyMap(SvgBodyMapSide.back);

    expect(
      _hasNoOverlap(
        front.paths['front-chest-left']!,
        front.paths['front-shoulder-left']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        front.paths['front-chest-right']!,
        front.paths['front-shoulder-right']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        front.paths['front-shoulder-left']!,
        front.paths['front-biceps-left']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        front.paths['front-shoulder-right']!,
        front.paths['front-biceps-right']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        front.paths['front-biceps-left']!,
        front.paths['front-forearm-left']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        front.paths['front-biceps-right']!,
        front.paths['front-forearm-right']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-trapezius']!,
        back.paths['back-shoulder-left']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-trapezius']!,
        back.paths['back-shoulder-right']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-shoulder-left']!,
        back.paths['back-triceps-left']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-shoulder-right']!,
        back.paths['back-triceps-right']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-triceps-left']!,
        back.paths['back-forearm-left']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-triceps-right']!,
        back.paths['back-forearm-right']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-trapezius']!,
        back.paths['back-lats-left']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-lats-left']!,
        back.paths['back-lats-right']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        front.paths['front-core']!,
        front.paths['front-quadriceps-left']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        front.paths['front-core']!,
        front.paths['front-quadriceps-right']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-lats-left']!,
        back.paths['back-glutes-left']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-glutes-left']!,
        back.paths['back-hamstrings-left']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-glutes-left']!,
        back.paths['back-glutes-right']!,
      ),
      isTrue,
    );
    expect(
      _hasNoOverlap(
        back.paths['back-hamstrings-left']!,
        back.paths['back-calves-left']!,
      ),
      isTrue,
    );
  });

  testWidgets('keeps arm regions aligned to the shared limb axis', (
    tester,
  ) async {
    final front = await loadSvgBodyMap(SvgBodyMapSide.front);
    final back = await loadSvgBodyMap(SvgBodyMapSide.back);

    _expectArmAxis(
      front,
      'front-shoulder-left',
      'front-biceps-left',
      'front-forearm-left',
    );
    _expectArmAxis(
      back,
      'back-shoulder-left',
      'back-triceps-left',
      'back-forearm-left',
    );
    expect(
      front.paths['front-shoulder-left']!.getBounds(),
      equals(back.paths['back-shoulder-left']!.getBounds()),
    );
    expect(
      front.paths['front-shoulder-right']!.getBounds(),
      equals(back.paths['back-shoulder-right']!.getBounds()),
    );
  });

  testWidgets('keeps deltoids in shoulder territory and trapezius central', (
    tester,
  ) async {
    final front = await loadSvgBodyMap(SvgBodyMapSide.front);
    final back = await loadSvgBodyMap(SvgBodyMapSide.back);
    final frontDeltoid = front.paths['front-shoulder-left']!;
    final backDeltoid = back.paths['back-shoulder-left']!;
    final trapezius = back.paths['back-trapezius']!;
    final deltoidBounds = frontDeltoid.getBounds();
    final trapeziusBounds = trapezius.getBounds();

    expect(deltoidBounds.width, greaterThanOrEqualTo(10));
    expect(deltoidBounds.top, lessThan(80));
    expect(frontDeltoid.contains(const Offset(67, 88)), isTrue);
    expect(backDeltoid.contains(const Offset(67, 88)), isTrue);
    expect(_isContainedBy(frontDeltoid, front.paths['front-body']!), isTrue);
    expect(_isContainedBy(backDeltoid, back.paths['back-body']!), isTrue);
    for (final (document, id) in [
      (front, 'front-shoulder-left'),
      (front, 'front-shoulder-right'),
      (back, 'back-shoulder-left'),
      (back, 'back-shoulder-right'),
      (front, 'front-biceps-left'),
      (front, 'front-biceps-right'),
      (back, 'back-triceps-left'),
      (back, 'back-triceps-right'),
      (front, 'front-forearm-left'),
      (front, 'front-forearm-right'),
      (back, 'back-forearm-left'),
      (back, 'back-forearm-right'),
      (back, 'back-glutes-left'),
      (back, 'back-glutes-right'),
    ]) {
      final region = document.paths[id]!;
      expect(region.contains(region.getBounds().center), isTrue, reason: id);
    }
    for (final (document, bodyId, forearmId) in [
      (front, 'front-body', 'front-forearm-left'),
      (back, 'back-body', 'back-forearm-left'),
    ]) {
      final forearm = document.paths[forearmId]!;
      expect(forearm.getBounds().width, closeTo(12.89, .02), reason: forearmId);
      expect(_isContainedBy(forearm, document.paths[bodyId]!), isTrue);
    }
    expect(trapeziusBounds.width, lessThan(50));
    expect(trapeziusBounds.center.dx, closeTo(100, .01));
    expect(trapezius.contains(const Offset(100, 85)), isTrue);
  });

  testWidgets('raises the lower-body semantic stack', (tester) async {
    final front = await loadSvgBodyMap(SvgBodyMapSide.front);
    final back = await loadSvgBodyMap(SvgBodyMapSide.back);
    final body = front.paths['front-body']!;
    final trapezius = back.paths['back-trapezius']!.getBounds();
    final leftLats = back.paths['back-lats-left']!.getBounds();
    final rightLats = back.paths['back-lats-right']!.getBounds();
    final leftQuadriceps = front.paths['front-quadriceps-left']!.getBounds();
    final leftGlutes = back.paths['back-glutes-left']!.getBounds();
    final leftHamstrings = back.paths['back-hamstrings-left']!.getBounds();
    final leftCalves = back.paths['back-calves-left']!.getBounds();
    final rightGlutes = back.paths['back-glutes-right']!.getBounds();

    expect(body.contains(const Offset(71, 150)), isFalse);
    expect(body.contains(const Offset(74, 188)), isTrue);
    expect(body.contains(const Offset(100, 188)), isTrue);
    expect(body.contains(const Offset(100, 192)), isFalse);
    expect(leftLats.top, lessThan(102));
    expect((leftLats.top - trapezius.bottom).abs(), lessThan(12));
    expect(leftLats.height, greaterThan(30));
    expect(leftLats.height, closeTo(67, .02));
    expect(rightLats.height, closeTo(leftLats.height, .01));
    expect(leftLats.bottom, lessThan(160));
    expect(leftQuadriceps.top, lessThan(193));
    expect(leftGlutes.top, lessThan(162));
    expect(leftHamstrings.top, lessThan(200));
    expect(leftGlutes.top - leftLats.bottom, lessThan(8));
    expect(leftHamstrings.top - leftGlutes.bottom, lessThan(14));
    expect(leftCalves.top - leftHamstrings.bottom, lessThan(7));
    expect(rightGlutes.left - leftGlutes.right, closeTo(3.5, .02));
    expect(leftGlutes.bottom, closeTo(186.75, .02));
    expect(body.contains(Offset(100, leftGlutes.bottom + 2)), isTrue);
  });
}

bool _isContainedBy(Path region, Path body) {
  return Path.combine(
    PathOperation.difference,
    region,
    body,
  ).computeMetrics().isEmpty;
}

String _bodyPathData(String svg, String id) {
  final match = RegExp('<path id="$id" d="([^"]+)"/>').firstMatch(svg);
  expect(match, isNotNull, reason: '$id is required');
  return match!.group(1)!;
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

bool _hasNoOverlap(Path first, Path second) => Path.combine(
  PathOperation.intersect,
  first,
  second,
).computeMetrics().isEmpty;

void _expectArmAxis(
  SvgBodyMapDocument document,
  String shoulderId,
  String upperArmId,
  String forearmId,
) {
  final shoulder = document.paths[shoulderId]!.getBounds().center;
  final upperArm = document.paths[upperArmId]!.getBounds().center;
  final forearm = document.paths[forearmId]!.getBounds().center;
  final upperSlope = (shoulder.dx - upperArm.dx) / (upperArm.dy - shoulder.dy);
  final forearmSlope = (upperArm.dx - forearm.dx) / (forearm.dy - upperArm.dy);

  expect(upperArm.dx, lessThan(shoulder.dx), reason: upperArmId);
  expect(forearm.dx, lessThan(upperArm.dx), reason: forearmId);
  // The final Product Owner feedback explicitly defines the two arm centers.
  // Keep their ordered, outward-continuing limb chain locked to that payload.
  expect(upperSlope, closeTo(.27586, .01));
  expect(forearmSlope, closeTo(.13415, .01));
}
