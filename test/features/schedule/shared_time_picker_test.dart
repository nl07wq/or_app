import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/schedule/widgets/shared_time_picker.dart';

void main() {
  group('OperationOrbitalTimeMapping', () {
    test('maps the AM and PM display contract without persisting 24', () {
      final cases = <TimeOfDay, int>{
        const TimeOfDay(hour: 0, minute: 0): 12,
        const TimeOfDay(hour: 11, minute: 35): 11,
        const TimeOfDay(hour: 12, minute: 0): 24,
        const TimeOfDay(hour: 12, minute: 15): 24,
        const TimeOfDay(hour: 13, minute: 0): 13,
        const TimeOfDay(hour: 23, minute: 59): 23,
      };
      for (final entry in cases.entries) {
        expect(
          OperationOrbitalTimeMapping.displayHour(entry.key.hour),
          entry.value,
        );
        expect(
          OperationOrbitalTimeMapping.fromDialHour(
            dialHour: OperationOrbitalTimeMapping.dialHour(entry.key.hour),
            pm: OperationOrbitalTimeMapping.isPm(entry.key.hour),
          ),
          entry.key.hour,
        );
      }
    });

    test('period changes preserve dial position', () {
      expect(
        OperationOrbitalTimeMapping.fromDialHour(dialHour: 11, pm: true),
        23,
      );
      expect(
        OperationOrbitalTimeMapping.fromDialHour(dialHour: 12, pm: true),
        12,
      );
      expect(
        OperationOrbitalTimeMapping.fromDialHour(dialHour: 12, pm: false),
        0,
      );
    });
  });

  Future<TimeOfDay?> showPicker(
    WidgetTester tester,
    TimeOfDay initial, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    TimeOfDay? result;
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async => result = await showSharedTimePicker(
                    context,
                    initialTime: initial,
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('cancel returns null and PM 24 reopens as noon', (tester) async {
    await showPicker(tester, const TimeOfDay(hour: 12, minute: 15));
    expect(find.text('24'), findsWidgets);
    expect(find.text('PM  /  13–24'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('orbital-time-picker-dial')),
      findsNothing,
    );
  });

  testWidgets(
    'period switch keeps the clock position and OK returns TimeOfDay',
    (tester) async {
      await showPicker(tester, const TimeOfDay(hour: 11, minute: 35));
      await tester.tap(find.byKey(const ValueKey('orbital-time-picker-pm')));
      await tester.pump();
      expect(find.text('23'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('orbital-time-picker-ok')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('dial minute drag retains one minute precision', (tester) async {
    await showPicker(tester, const TimeOfDay(hour: 23, minute: 0));
    await tester.tap(find.byKey(const ValueKey('orbital-time-picker-minute')));
    await tester.pump();
    final dial = find.byKey(const ValueKey('orbital-time-picker-dial'));
    final box = tester.getRect(dial);
    final center = box.center;
    final angle = 37 * 2 * 3.14159265359 / 60 - 3.14159265359 / 2;
    final target = center + Offset(88 * math.cos(angle), 88 * math.sin(angle));
    await tester.dragFrom(
      center + const Offset(0, -90),
      target - (center + const Offset(0, -90)),
    );
    await tester.pump();
    expect(find.text('37'), findsWidgets);
  });

  testWidgets('invalid keyboard input disables confirmation', (tester) async {
    await showPicker(tester, const TimeOfDay(hour: 23, minute: 35));
    await tester.tap(
      find.byKey(const ValueKey('orbital-time-picker-keyboard')),
    );
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '25');
    await tester.pump();
    expect(find.text('Invalid'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('orbital-time-picker-ok')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('fits narrow, short and enlarged-text viewports', (tester) async {
    for (final size in [
      const Size(320, 560),
      const Size(375, 700),
      const Size(390, 844),
      const Size(430, 844),
    ]) {
      await showPicker(
        tester,
        const TimeOfDay(hour: 11, minute: 0),
        size: size,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('orbital dialog golden states', (tester) async {
    await showPicker(tester, const TimeOfDay(hour: 23, minute: 0));
    await expectLater(
      find.byType(OperationOrbitalTimePickerDialog),
      matchesGoldenFile('goldens/orbital_time_picker_pm23_hour.png'),
    );
    await tester.tap(find.byKey(const ValueKey('orbital-time-picker-minute')));
    await tester.pump();
    await expectLater(
      find.byType(OperationOrbitalTimePickerDialog),
      matchesGoldenFile('goldens/orbital_time_picker_pm23_minute.png'),
    );
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    await showPicker(tester, const TimeOfDay(hour: 11, minute: 0));
    await expectLater(
      find.byType(OperationOrbitalTimePickerDialog),
      matchesGoldenFile('goldens/orbital_time_picker_am11_hour.png'),
    );
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    await showPicker(tester, const TimeOfDay(hour: 12, minute: 15));
    await expectLater(
      find.byType(OperationOrbitalTimePickerDialog),
      matchesGoldenFile('goldens/orbital_time_picker_pm24_hour.png'),
    );
    await tester.tap(
      find.byKey(const ValueKey('orbital-time-picker-keyboard')),
    );
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '25');
    await tester.pump();
    await expectLater(
      find.byType(OperationOrbitalTimePickerDialog),
      matchesGoldenFile('goldens/orbital_time_picker_keyboard_invalid.png'),
    );
  });
}
