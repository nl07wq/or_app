import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/bat_side_profile_shape_poc.dart';

void main() {
  test('BAT V3 declares body-first bat identity geometry', () {
    expect(BatSideProfileShapeV3.authoritativePaths, hasLength(4));
    expect(BatSideProfileShapeV3.anatomyGuides, hasLength(6));
    expect(BatSideProfileShapeV3.nearEarTip.dy, lessThan(46));
    expect(BatSideProfileShapeV3.farEarTip.dy, lessThan(55));
    expect(BatSideProfileShapeV3.muzzleTip.dx, greaterThan(170));
    expect(BatSideProfileShapeV3.nearWingTip.dx, greaterThan(195));
    expect(BatSideProfileShapeV3.productionScale, .26);
  });

  testWidgets(
    'BAT V3 exposes silhouette, anatomy, body-only, directions, zooms, and 48px preview',
    (tester) async {
      await tester.pumpWidget(_host());
      expect(
        find.text('STATIC POSE V3 · IDENTITY / SILHOUETTE CANDIDATE'),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('bat-shape-production-preview')))
            .height,
        48,
      );

      for (final mode in ['silhouette', 'anatomy', 'body-only']) {
        await tester.tap(find.byKey(ValueKey('bat-shape-mode-$mode')));
        await tester.pump();
        expect(_mainPainter(tester).mode, switch (mode) {
          'silhouette' => BatInspectionMode.silhouette,
          'anatomy' => BatInspectionMode.anatomy,
          _ => BatInspectionMode.bodyOnly,
        });
      }

      await tester.tap(find.byKey(const ValueKey('bat-shape-direction-rtl')));
      await tester.pump();
      for (final zoom in [1, 2, 4]) {
        final button = find.byKey(ValueKey('bat-shape-zoom-$zoom'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(
          find.byKey(ValueKey('bat-shape-inspection-$zoom')),
          findsOneWidget,
        );
      }
      expect(_productionPainter(tester).leftToRight, isFalse);
      expect(_productionPainter(tester).mode, BatInspectionMode.silhouette);
    },
  );

  testWidgets('BAT V3 remains layout-safe at 320, 390, and 900', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_host());
      await tester.tap(find.byKey(const ValueKey('bat-shape-mode-anatomy')));
      await tester.tap(find.byKey(const ValueKey('bat-shape-zoom-4')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bat-shape-production-preview')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}

Widget _host() => MaterialApp(
  home: Scaffold(body: ListView(children: const [BatSideProfileShapePoc()])),
);

BatSideProfilePainter _mainPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const ValueKey('bat-shape-inspection-1')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as BatSideProfilePainter;

BatSideProfilePainter _productionPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const ValueKey('bat-shape-production-preview')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as BatSideProfilePainter;
