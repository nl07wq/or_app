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

  testWidgets('missing value opens two rows and does not invent a level', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    expect(find.byKey(const Key('foot-pain-levels-1-5')), findsOneWidget);
    expect(find.byKey(const Key('foot-pain-levels-6-10')), findsOneWidget);
    expect(find.byKey(const Key('foot-pain-chip-1')), findsOneWidget);
    expect(find.byKey(const Key('foot-pain-chip-10')), findsOneWidget);
    expect(controller.text, isEmpty);
  });

  testWidgets(
    'selection completes into cyan readout and reopens with same value',
    (tester) async {
      final controller = TextEditingController(text: '3');
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      expect(find.byKey(const Key('foot-pain-levels-1-5')), findsNothing);
      await tester.tap(find.byKey(const Key('foot-pain-current-value-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('foot-pain-chip-7')));
      expect(controller.text, '7');
      await tester.tap(find.byKey(const Key('foot-pain-done')));
      await tester.pump();
      expect(find.text('LV.7 /10'), findsOneWidget);
      expect(find.byKey(const Key('foot-pain-levels-6-10')), findsNothing);
      await tester.tap(find.byKey(const Key('foot-pain-current-value-button')));
      await tester.pump();
      expect(find.byKey(const Key('foot-pain-levels-6-10')), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );

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
    testWidgets('two editing rows fit at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      expect(tester.takeException(), isNull);
      for (var value = 1; value <= 10; value++) {
        expect(
          tester.getSize(find.byKey(Key('foot-pain-chip-$value'))).height,
          greaterThanOrEqualTo(44),
        );
      }
    });
  }
}
