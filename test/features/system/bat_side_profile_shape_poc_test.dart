import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/bat_side_profile_shape_poc.dart';

void main() {
  test('BAT has one vector-only asymmetric side-profile source pose', () {
    expect(BatSideProfileShapeV1.authoritativePaths, hasLength(4));
    expect(BatSideProfileShapeV1.productionScale, .26);
    expect(BatSideProfileShapeV1.nearWingColor, isNot(BatSideProfileShapeV1.farWingColor));
  });

  testWidgets('BAT POC exposes mirrored directions, 1×/2×/4×, and 48px preview', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: const [BatSideProfileShapePoc()]))));
    expect(find.text('BAT SIDE PROFILE'), findsOneWidget);
    expect(find.byKey(const ValueKey('bat-shape-production-preview')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('bat-shape-production-preview'))).height, 48);
    await tester.tap(find.byKey(const ValueKey('bat-shape-direction-rtl')));
    await tester.pump();
    for (final zoom in [1, 2, 4]) {
      final button = find.byKey(ValueKey('bat-shape-zoom-$zoom'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(find.byKey(ValueKey('bat-shape-inspection-$zoom')), findsOneWidget);
    }
    final painter = tester.widget<CustomPaint>(find.descendant(of: find.byKey(const ValueKey('bat-shape-production-preview')), matching: find.byType(CustomPaint))).painter! as BatSideProfilePainter;
    expect(painter.leftToRight, isFalse);
  });

  testWidgets('BAT POC is responsive at 320, 390, and 900', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: const [BatSideProfileShapePoc()]))));
      await tester.tap(find.byKey(const ValueKey('bat-shape-zoom-4')));
      await tester.pump();
      expect(find.byKey(const ValueKey('bat-shape-production-preview')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
