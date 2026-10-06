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
}
