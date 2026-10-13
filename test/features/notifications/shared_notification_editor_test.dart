import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/notifications/models/notification_configuration.dart';
import 'package:or_app/features/notifications/widgets/shared_notification_editor.dart';

void main() {
  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('shared notification editor supports $width width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var value = NotificationConfiguration(
        offsetsMinutes: const [],
        timeZone: 'Asia/Tokyo',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: SharedNotificationEditor(
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('notification-preset-15')));
      await tester.pump();
      expect(value.offsetsMinutes, [15]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('calendar selector keeps multiple preset notifications', (
    tester,
  ) async {
    var value = NotificationConfiguration(
      offsetsMinutes: const [60],
      timeZone: 'Asia/Tokyo',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SharedNotificationEditor(
              calendarStyle: true,
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('calendar-notification-field')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-notification-preset-60')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('calendar-notification-preset-10')),
    );
    await tester.pump();
    expect(value.offsetsMinutes, [10, 60]);
    await tester.tap(
      find.byKey(const ValueKey('calendar-notification-preset-60')),
    );
    await tester.pump();
    expect(value.offsetsMinutes, [10]);
  });

  testWidgets('calendar selector adds a wheel-selected custom offset', (
    tester,
  ) async {
    var value = NotificationConfiguration(timeZone: 'Asia/Tokyo');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SharedNotificationEditor(
              calendarStyle: true,
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('calendar-notification-field')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('calendar-notification-custom')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('calendar-notification-custom-confirm')),
    );
    await tester.pumpAndSettle();
    expect(value.offsetsMinutes, [10]);
  });
}
