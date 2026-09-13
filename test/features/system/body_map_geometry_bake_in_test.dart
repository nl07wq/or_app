import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/widgets/body_map_svg_prototype.dart';

/// Locks the complete Product Owner feedback authored against 58bf285.
void main() {
  const baselineCommit = '58bf285';

  testWidgets('bakes the accepted tuner feedback into canonical SVG paths', (
    tester,
  ) async {
    expect(baselineCommit, '58bf285');
    final front = await loadSvgBodyMap(SvgBodyMapSide.front);
    final back = await loadSvgBodyMap(SvgBodyMapSide.back);
    _expectBounds(
      front.paths,
      'front-shoulder-left',
      64.09,
      75.75,
      76.91,
      94.25,
    );
    _expectBounds(
      front.paths,
      'front-biceps-left',
      54.95,
      97.26,
      70.05,
      130.74,
    );
    _expectBounds(
      front.paths,
      'front-forearm-left',
      50.55,
      132.45,
      63.45,
      177.55,
    );
    _expectBounds(
      front.paths,
      'front-quadriceps-left',
      73.23,
      185.63,
      93.78,
      249.35,
    );
    _expectBounds(back.paths, 'back-trapezius', 75.5, 62.25, 124.5, 91.75);
    _expectBounds(back.paths, 'back-lats-left', 72.46, 82.5, 99.5, 149.5);
    _expectBounds(back.paths, 'back-glutes-left', 73.8, 152.3, 98.3, 186.8);
    _expectBounds(back.paths, 'back-hamstrings-left', 73.5, 191, 93.5, 246);
    _expectBounds(back.paths, 'back-calves-left', 74, 249.3, 92, 300.8);

    expect(front.paths['front-core']!.computeMetrics(), hasLength(6));
    expect(
      front.paths['front-shoulder-left']!.contains(const Offset(70.5, 85)),
      isTrue,
    );
    expect(
      back.paths['back-trapezius']!.contains(const Offset(100, 70)),
      isTrue,
    );
    expect(
      back.paths['back-trapezius']!.contains(const Offset(100, 86)),
      isTrue,
    );
  });
}

void _expectBounds(
  Map<String, Path> paths,
  String id,
  double left,
  double top,
  double right,
  double bottom,
) {
  final bounds = paths[id]!.getBounds();
  expect(bounds.left, closeTo(left, .11), reason: '$id left');
  expect(bounds.top, closeTo(top, .11), reason: '$id top');
  expect(bounds.right, closeTo(right, .11), reason: '$id right');
  expect(bounds.bottom, closeTo(bottom, .11), reason: '$id bottom');
}
