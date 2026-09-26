import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/bat_side_profile_shape_poc.dart';

void main() {
  test('BAT V2 has one vector-only body-first asymmetric source pose', () {
    expect(BatSideProfileShapeV2.authoritativePaths, hasLength(4));
    expect(BatSideProfileShapeV2.productionScale, .26);
    expect(
      BatSideProfileShapeV2.nearWingColor,
      isNot(BatSideProfileShapeV2.farWingColor),
    );
    expect(BatSideProfileShapeV2.fingerGuides, hasLength(4));
  });

  testWidgets(
    'BAT V2 exposes inspection modes, directions, zooms, and 48px preview',
    (tester) async {
      await tester.pumpWidget(_host());
      expect(
        find.text('STATIC POSE V2 · REFERENCE-DRIVEN CANDIDATE'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bat-shape-production-preview')),
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
    },
  );

  testWidgets('BAT V2 remains layout-safe at 320, 390, and 900', (
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
