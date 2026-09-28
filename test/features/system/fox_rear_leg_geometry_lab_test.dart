import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:or_app/features/system/pages/fox_rear_leg_geometry_lab.dart';

void main() {
  Future<void> pumpLab(WidgetTester tester, double width) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(Size(width, 1400));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FoxRearLegGeometryLab()),
        ),
      ),
    );
  }

  Future<void> addQuadrilateral(WidgetTester tester) async {
    final stage = tester.getRect(
      find.byKey(const ValueKey('fox-rear-leg-stage')),
    );
    for (final fraction in const [
      Offset(.32, .42),
      Offset(.54, .40),
      Offset(.58, .75),
      Offset(.30, .78),
    ]) {
      await tester.tapAt(
        Offset(
          stage.left + stage.width * fraction.dx,
          stage.top + stage.height * fraction.dy,
        ),
      );
      await tester.pump();
    }
  }

  testWidgets('all five frames begin with no guessed geometry', (tester) async {
    await pumpLab(tester, 390);
    expect(find.textContaining('REGION: NOT CONFIGURED'), findsWidgets);
    expect(find.textContaining('ROOT: NOT CONFIGURED'), findsWidgets);
    expect(find.textContaining('FOOT: NOT CONFIGURED'), findsWidgets);
    for (final frame in FoxRearLegGeometryLab.frames.skip(1)) {
      await tester.tap(find.byKey(ValueKey('fox-rear-leg-frame-$frame')));
      await tester.pump();
      expect(find.textContaining('REGION: NOT CONFIGURED'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'FREE TAP candidate is isolated until APPLY and frames stay independent',
    (tester) async {
      await pumpLab(tester, 390);
      await addQuadrilateral(tester);
      expect(find.text('REGION INPUT: 4 points'), findsOneWidget);
      expect(find.textContaining('REGION: NOT CONFIGURED'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fox-rear-leg-close')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fox-rear-leg-apply')));
      await tester.pump();
      expect(find.textContaining('REGION: 8 points'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('fox-rear-leg-frame-3')));
      await tester.pump();
      expect(find.textContaining('REGION: NOT CONFIGURED'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fox-rear-leg-frame-1')));
      await tester.pump();
      expect(find.textContaining('REGION: 8 points'), findsOneWidget);
    },
  );

  testWidgets('ROOT and FOOT tap independently, nudge, reset, and copy data', (
    tester,
  ) async {
    String? copiedText;
    final platform = SystemChannels.platform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform, null),
    );
    await pumpLab(tester, 390);
    await addQuadrilateral(tester);
    await tester.tap(find.byKey(const ValueKey('fox-rear-leg-close')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fox-rear-leg-apply')));
    await tester.pump();
    expect(find.textContaining('REGION: 8 points'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fox-rear-leg-mode-root')));
    await tester.pump();
    final stage = tester.getRect(
      find.byKey(const ValueKey('fox-rear-leg-stage')),
    );
    await tester.tapAt(Offset(stage.left + 90, stage.top + 80));
    await tester.pump();
    expect(find.text('ROOT: tap, drag, or nudge 1px'), findsOneWidget);
    await tester.tap(find.text('→'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('fox-rear-leg-mode-foot')));
    await tester.pump();
    await tester.tapAt(Offset(stage.left + 180, stage.top + 140));
    await tester.pump();
    expect(find.text('FOOT: tap, drag, or nudge 1px'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fox-rear-leg-copy')));
    await tester.pump();
    expect(copiedText, startsWith('FOX REAR LEG DATA\nversion: 1'));
    expect(copiedText, contains('FRAME 01'));
    expect(copiedText, contains('POINT_COUNT: 8'));
    expect(copiedText, contains('ROOT x='));
    expect(copiedText, contains('FOOT x='));
    expect(copiedText, contains('FRAME 07'));
    expect(copiedText, contains('ROOT: NOT CONFIGURED'));

    await tester.tap(find.byKey(const ValueKey('fox-rear-leg-reset-frame')));
    await tester.pump();
    expect(find.textContaining('REGION: NOT CONFIGURED'), findsWidgets);
    expect(find.textContaining('ROOT: NOT CONFIGURED'), findsWidgets);
    expect(find.textContaining('FOOT: NOT CONFIGURED'), findsWidgets);
  });

  testWidgets('TRACE, 6/8/10/12 targets, and focal zoom stay responsive', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      await pumpLab(tester, width);
      await tester.tap(find.byKey(const ValueKey('fox-rear-leg-input-trace')));
      await tester.pump();
      final stage = tester.getRect(
        find.byKey(const ValueKey('fox-rear-leg-stage')),
      );
      final gesture = await tester.startGesture(
        Offset(stage.left + stage.width * .3, stage.top + stage.height * .4),
      );
      await gesture.moveTo(
        Offset(stage.left + stage.width * .6, stage.top + stage.height * .4),
      );
      await gesture.moveTo(
        Offset(stage.left + stage.width * .5, stage.top + stage.height * .75),
      );
      await gesture.up();
      await tester.pump();
      for (final count in [6, 8, 10, 12]) {
        await tester.tap(find.byKey(ValueKey('fox-rear-leg-points-$count')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${width}px/$count');
      }
      await tester.tap(find.byKey(const ValueKey('fox-rear-leg-zoom-4.0')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${width}px zoom');
    }
  });
}
