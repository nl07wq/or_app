import 'package:flutter/cupertino.dart';
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

  testWidgets(
    'calendar custom reminders toggle, reselect, and deduplicate in one edit',
    (tester) async {
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

      await tester.tap(
        find.byKey(const ValueKey('calendar-notification-field')),
      );
      await tester.pumpAndSettle();
      for (final offset in [0, 10, 60, 360]) {
        expect(
          find.byKey(ValueKey('calendar-notification-preset-$offset')),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.byKey(const ValueKey('calendar-notification-custom')),
      );
      await tester.pumpAndSettle();
      final pickers = tester.widgetList<CupertinoPicker>(
        find.byType(CupertinoPicker),
      );
      pickers.first.onSelectedItemChanged?.call(6); // 7 minutes.
      await tester.tap(
        find.byKey(const ValueKey('calendar-notification-custom-confirm')),
      );
      await tester.pumpAndSettle();

      final custom = find.byKey(
        const ValueKey('calendar-notification-custom-7'),
      );
      expect(value.offsetsMinutes, [7]);
      expect(custom, findsOneWidget);
      expect(find.text('7分前'), findsAtLeastNWidgets(1));

      await tester.tap(custom);
      await tester.pump();
      expect(value.offsetsMinutes, isEmpty);
      expect(custom, findsOneWidget);

      await tester.tap(custom);
      await tester.pump();
      expect(value.offsetsMinutes, [7]);

      // The same custom time selects its existing item instead of toggling it.
      await tester.tap(
        find.byKey(const ValueKey('calendar-notification-custom')),
      );
      await tester.pumpAndSettle();
      tester
          .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
          .first
          .onSelectedItemChanged
          ?.call(6);
      await tester.tap(
        find.byKey(const ValueKey('calendar-notification-custom-confirm')),
      );
      await tester.pumpAndSettle();
      expect(value.offsetsMinutes, [7]);
      expect(custom, findsOneWidget);
    },
  );

  testWidgets('calendar custom candidates persist only for the open edit', (
    tester,
  ) async {
    var value = NotificationConfiguration(
      offsetsMinutes: const [7, 17],
      timeZone: 'Asia/Tokyo',
    );
    var session = 0;
    late StateSetter hostSetState;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              hostSetState = setState;
              return SharedNotificationEditor(
                key: ValueKey('editor-$session'),
                calendarStyle: true,
                value: value,
                onChanged: (next) => setState(() => value = next),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('calendar-notification-field')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('calendar-notification-custom-7')),
    );
    await tester.pump();
    expect(value.offsetsMinutes, [17]);
    // A deselected candidate remains usable until this editor is closed.
    expect(
      find.byKey(const ValueKey('calendar-notification-custom-7')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    hostSetState(() {
      // Rebuilding a fresh editor models saving then reopening. Only persisted
      // selected offsets may reappear as custom candidates.
      session++;
    });
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('calendar-notification-field')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-notification-custom-7')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('calendar-notification-custom-17')),
      findsOneWidget,
    );
  });
}
