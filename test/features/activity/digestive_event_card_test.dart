import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/activity/models/activity_draft.dart';
import 'package:or_app/features/activity/widgets/digestive_event_card.dart';

void main() {
  ActivityDraftDigestiveEvent event({int? relief}) =>
      ActivityDraftDigestiveEvent(
        id: 'digestive-relief',
        sequence: 1,
        amount: 1,
        relief: relief,
        recordedAt: DateTime.utc(2026, 10, 21),
      );

  Future<void> pumpCard(
    WidgetTester tester, {
    required double width,
    double textScale = 1,
    int? relief,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var current = event(relief: relief);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: StatefulBuilder(
                builder: (context, setState) => DigestiveEventCard(
                  event: current,
                  onChanged: (next) => setState(() => current = next),
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final width in const [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('Relief controls remain one row at $width', (tester) async {
      await pumpCard(tester, width: width, textScale: 1.3, relief: 1);
      final buttons = [
        find.byKey(const ValueKey('digestive-digestive-relief-relief-0')),
        find.byKey(const ValueKey('digestive-digestive-relief-relief-1')),
        find.byKey(const ValueKey('digestive-digestive-relief-relief-2')),
      ];
      final rects = buttons.map(tester.getRect).toList();
      expect(rects.map((rect) => rect.top).toSet().length, 1);
      expect(rects.every((rect) => rect.height == 46), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Relief keeps values zero, one, and two selectable', (
    tester,
  ) async {
    await pumpCard(tester, width: 390);
    for (final value in [0, 1, 2]) {
      final control = find.byKey(
        ValueKey('digestive-digestive-relief-relief-$value'),
      );
      await tester.tap(control);
      await tester.pump();
      expect(
        tester.getSemantics(control).label,
        contains(['残便感', '普通', 'スッキリ'][value]),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
