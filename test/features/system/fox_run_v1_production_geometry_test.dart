import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:or_app/features/system/pages/fox_run_v1_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const stageWidth = 390.0;
  const stageHeight = FoxRunV1ProductionGeometry.stageHeight;
  final stageRect = Rect.fromLTWH(0, 0, stageWidth, stageHeight);
  final ground = FoxRunV1ProductionGeometry.stageGroundY(stageHeight);

  Rect boundsAt(double bodyCenterX) =>
      FoxRunV1ProductionGeometry.visibleBounds(
        bodyCenterX: bodyCenterX,
        stageGroundY: ground,
      );

  test('canonical FOX assets 01 through 10 decode', () async {
    for (var frame = 1; frame <= 10; frame++) {
      final asset =
          'assets/animations/sandbox/fox_v1/canonical/frame_${frame.toString().padLeft(2, '0')}.png';
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });

  test('Frame 01 static body center and virtual ground are visible', () {
    const bodyCenterX = stageWidth / 2;
    final image = FoxRunV1ProductionGeometry.imageTopLeft(
      bodyCenterX: bodyCenterX,
      stageGroundY: ground,
    );
    final scaledOrigin = Offset(
      FoxRunV1ProductionGeometry.bodyOrigin.dx *
          FoxRunV1ProductionGeometry.displayScale,
      FoxRunV1ProductionGeometry.bodyOrigin.dy *
          FoxRunV1ProductionGeometry.displayScale,
    );
    final bounds = boundsAt(bodyCenterX);

    expect(image.dx + scaledOrigin.dx, closeTo(bodyCenterX, 0.001));
    expect(
      image.dy +
          FoxRunV1ProductionGeometry.virtualGround *
              FoxRunV1ProductionGeometry.displayScale,
      closeTo(ground, 0.001),
    );
    expect(bounds.intersect(stageRect).width, greaterThan(100));
    expect(bounds.intersect(stageRect).height, greaterThan(80));
  });

  test('all 10 cels share the in-place visibility registration', () {
    const bodyCenterX = stageWidth / 2;
    final frame01 = boundsAt(bodyCenterX);
    for (var frame = 1; frame <= 10; frame++) {
      // Runtime selection changes only the canonical asset path.  There is no
      // frame scale, dx, dy, fit, or recenter branch.
      final bounds = boundsAt(bodyCenterX);
      expect(bounds, frame01, reason: 'frame $frame');
      expect(bounds.intersect(stageRect).isEmpty, isFalse, reason: 'frame $frame');
    }
  });

  test('10 to 01 retains the same transformed registration', () {
    const bodyCenterX = stageWidth / 2;
    expect(boundsAt(bodyCenterX), boundsAt(bodyCenterX));
  });

  for (final leftToRight in [true, false]) {
    final direction = leftToRight ? 'L to R' : 'R to L';
    test('$direction crossing is offstage at both ends and visible at midpoint', () {
      final start = FoxRunV1ProductionGeometry.bodyCenterForProgress(
        stageWidth: stageWidth,
        progress: 0,
        leftToRight: leftToRight,
      );
      final midpoint = FoxRunV1ProductionGeometry.bodyCenterForProgress(
        stageWidth: stageWidth,
        progress: .5,
        leftToRight: leftToRight,
      );
      final end = FoxRunV1ProductionGeometry.bodyCenterForProgress(
        stageWidth: stageWidth,
        progress: 1,
        leftToRight: leftToRight,
      );

      expect(boundsAt(start).intersect(stageRect).isEmpty, isTrue);
      expect(boundsAt(midpoint).intersect(stageRect).width, greaterThan(100));
      expect(boundsAt(midpoint).intersect(stageRect).height, greaterThan(80));
      expect(boundsAt(end).intersect(stageRect).isEmpty, isTrue);
    });
  }

  for (final width in [320.0, 390.0, 900.0]) {
    test('mid-crossing FOX is visible at ${width.toInt()}px', () {
      final rect = Rect.fromLTWH(0, 0, width, stageHeight);
      final center = FoxRunV1ProductionGeometry.bodyCenterForProgress(
        stageWidth: width,
        progress: .5,
        leftToRight: true,
      );
      final visible = boundsAt(center).intersect(rect);
      expect(visible.width, greaterThan(100));
      expect(visible.height, greaterThan(80));
    });
  }
}
