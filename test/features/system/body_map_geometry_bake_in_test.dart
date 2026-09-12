import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/widgets/body_map_svg_prototype.dart';

/// Locks the Product Owner's geometry feedback authored against 2fb726a.
void main() {
  const baselineCommit = '2fb726a7b65d9857ace84dc54c9e8e3b0db9c3e3';

  testWidgets('bakes the accepted tuner feedback into canonical SVG paths', (
    tester,
  ) async {
    expect(baselineCommit, '2fb726a7b65d9857ace84dc54c9e8e3b0db9c3e3');
    final front = await loadSvgBodyMap(SvgBodyMapSide.front);
    final back = await loadSvgBodyMap(SvgBodyMapSide.back);
    _expectBounds(front.paths, 'front-shoulder-left', 64.5, 67.5, 89.5, 91.5);
    _expectBounds(front.paths, 'front-biceps-left', 54.2, 92.7, 70.8, 135.3);
    _expectBounds(front.paths, 'front-forearm-left', 46.6, 138.4, 63.4, 183.6);
    _expectBounds(
      front.paths,
      'front-quadriceps-left',
      73.7,
      190.9,
      94.3,
      246.1,
    );
    _expectBounds(back.paths, 'back-trapezius', 85, 62.3, 115, 109.8);
    _expectBounds(back.paths, 'back-lats-left', 70, 97, 99, 154);
    _expectBounds(back.paths, 'back-glutes-left', 73.8, 152.3, 98.3, 186.8);
    _expectBounds(back.paths, 'back-hamstrings-left', 73.5, 191, 93.5, 246);
    _expectBounds(back.paths, 'back-calves-left', 74, 249.3, 92, 300.8);

    expect(front.paths['front-core']!.computeMetrics(), hasLength(6));
    expect(
      front.paths['front-shoulder-left']!.contains(const Offset(77, 79.5)),
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
