import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/morning/widgets/foot_card.dart';

void main() {
  Widget app(TextEditingController controller) => MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SingleChildScrollView(child: FootCard(controller: controller)),
    ),
  );

  testWidgets(
    'missing value opens the 1 through 10 rail and does not invent a level',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      expect(find.byKey(const Key('foot-pain-scale')), findsOneWidget);
      expect(find.byKey(const Key('foot-pain-levels-1-5')), findsNothing);
      expect(find.byKey(const Key('foot-pain-levels-6-10')), findsNothing);
      expect(controller.text, isEmpty);
    },
  );

  testWidgets(
    'selection completes into cyan readout and reopens with same value',
    (tester) async {
      final controller = TextEditingController(text: '3');
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      expect(find.byKey(const Key('foot-pain-scale')), findsNothing);
      await tester.tap(find.byKey(const Key('foot-pain-current-value-button')));
      await tester.pump();
      final scale = find.byKey(const Key('foot-pain-scale'));
      final rect = tester.getRect(scale);
      await tester.tapAt(
        Offset(rect.left + rect.width * 6 / 9, rect.center.dy),
      );
      expect(controller.text, '7');
      await tester.tap(find.byKey(const Key('foot-pain-done')));
      await tester.pump();
      expect(find.text('LV.7 /10'), findsOneWidget);
      expect(find.byKey(const Key('foot-pain-scale')), findsNothing);
      await tester.tap(find.byKey(const Key('foot-pain-current-value-button')));
      await tester.pump();
      expect(find.byKey(const Key('foot-pain-scale')), findsOneWidget);
    },
  );

  testWidgets('new seeded FOOT draft remains editable until completion', (
    tester,
  ) async {
    final controller = TextEditingController(text: '3');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FootCard(controller: controller, initiallyExpanded: true),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('foot-pain-scale')), findsOneWidget);
    await tester.tap(find.byKey(const Key('foot-pain-done')));
    await tester.pump();
    expect(
      find.byKey(const Key('foot-pain-current-value-button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'external controller updates are reflected without reopening stale data',
    (tester) async {
      final controller = TextEditingController(text: '2');
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      controller.text = '9';
      await tester.pump();
      expect(find.text('LV.9 /10'), findsOneWidget);
    },
  );

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('horizontal pain rail fits at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('foot-pain-scale'))).height,
        greaterThanOrEqualTo(44),
      );
    });
  }

  testWidgets(
    'tap and horizontal drag select only the formal 1 through 10 range',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      final scale = find.byKey(const Key('foot-pain-scale'));
      final rect = tester.getRect(scale);
      await tester.tapAt(Offset(rect.left, rect.center.dy));
      expect(controller.text, '1');
      final gesture = await tester.startGesture(
        Offset(rect.left + 1, rect.center.dy),
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(Offset(rect.width - 22, 0));
      await tester.pump();
      await gesture.up();
      expect(controller.text, '10');
    },
  );
}
