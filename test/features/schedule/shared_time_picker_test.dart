import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/schedule/widgets/shared_time_picker.dart';

void main() {
  group('OperationOrbitalTimeMapping', () {
    test('duration dial uses conventional clockwise 12-hour geometry', () {
      const expectedHours = [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
      for (var position = 0; position < 12; position++) {
        final hour = OperationOrbitalTimeMapping.durationHourForDialPosition(
          position,
        );
        expect(hour, expectedHours[position]);
        expect(
          OperationOrbitalTimeMapping.durationDialPositionForHour(hour),
          position,
        );
      }
    });

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

  group('OperationCivilTime', () {
    test('keeps 00:00, 12:00, and 24:00 distinct', () {
      expect(OperationCivilTime.tryParse('00:00')?.clockString, '00:00');
      expect(OperationCivilTime.tryParse('12:00')?.clockString, '12:00');
      expect(OperationCivilTime.tryParse('24:00')?.clockString, '24:00');
      expect(OperationCivilTime.tryParse('24:01'), isNull);
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

  testWidgets(
    'hour dial follows one pointer until release before minute mode',
    (tester) async {
      await showPicker(tester, const TimeOfDay(hour: 13, minute: 35));
      final dial = find.byKey(const ValueKey('orbital-time-picker-dial'));
      final center = tester.getRect(dial).center;
      Offset atHour(int hour) {
        final angle = hour * 2 * math.pi / 12 - math.pi / 2;
        return center + Offset(88 * math.cos(angle), 88 * math.sin(angle));
      }

      final gesture = await tester.createGesture(pointer: 41);
      await gesture.down(atHour(1));
      await tester.pump();
      expect(find.text('13'), findsWidgets);
      expect(find.text('HOUR SELECT'), findsOneWidget);
      await gesture.moveTo(atHour(2));
      await tester.pump();
      expect(find.text('14'), findsWidgets);
      expect(find.text('HOUR SELECT'), findsOneWidget);
      await gesture.moveTo(atHour(4));
      await tester.pump();
      expect(find.text('16'), findsWidgets);
      await gesture.up();
      await tester.pump();
      expect(find.text('MINUTE SELECT'), findsOneWidget);
      expect(find.text('35'), findsWidgets);
    },
  );

  testWidgets('hour center dead zone and cancellation do not change mode', (
    tester,
  ) async {
    await showPicker(tester, const TimeOfDay(hour: 13, minute: 7));
    final center = tester
        .getRect(find.byKey(const ValueKey('orbital-time-picker-dial')))
        .center;
    final gesture = await tester.createGesture(pointer: 42);
    await gesture.down(center);
    await gesture.moveTo(center + const Offset(0, -88));
    await gesture.up();
    await tester.pump();
    expect(find.text('HOUR SELECT'), findsOneWidget);
    expect(find.text('13'), findsWidgets);

    final cancelled = await tester.createGesture(pointer: 43);
    await cancelled.down(center + const Offset(0, -88));
    await cancelled.cancel();
    await tester.pump();
    expect(find.text('HOUR SELECT'), findsOneWidget);
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

  testWidgets('duration mode preserves elapsed time without AM or PM', (
    tester,
  ) async {
    Duration? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showSharedDurationPicker(
                context,
                initialDuration: const Duration(hours: 6, minutes: 30),
              );
            },
            child: const Text('OPEN DURATION'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN DURATION'));
    await tester.pumpAndSettle();
    expect(find.text('DURATION HOUR'), findsOneWidget);
    expect(find.textContaining('AM  /'), findsNothing);
    expect(find.textContaining('PM  /'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('orbital-time-picker-keyboard')),
    );
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '7');
    await tester.enterText(fields.last, '05');
    await tester.tap(find.byKey(const ValueKey('orbital-time-picker-ok')));
    await tester.pumpAndSettle();
    expect(result, const Duration(hours: 7, minutes: 5));
  });

  testWidgets('duration dial selection and readout agree for every hour', (
    tester,
  ) async {
    for (var hour = 1; hour <= 12; hour++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showSharedDurationPicker(
                context,
                initialDuration: const Duration(hours: 1),
              ),
              child: const Text('OPEN DURATION'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN DURATION'));
      await tester.pumpAndSettle();
      final dial = tester.getRect(
        find.byKey(const ValueKey('orbital-time-picker-dial')),
      );
      final position = OperationOrbitalTimeMapping.durationDialPositionForHour(
        hour,
      );
      final angle = position * 2 * math.pi / 12 - math.pi / 2;
      await tester.tapAt(
        dial.center + Offset(88 * math.cos(angle), 88 * math.sin(angle)),
      );
      await tester.pump();
      expect(find.text(hour.toString().padLeft(2, '0')), findsWidgets);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('duration mode keeps keyboard-entered long durations', (
    tester,
  ) async {
    Duration? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showSharedDurationPicker(
                context,
                initialDuration: const Duration(hours: 25, minutes: 30),
              );
            },
            child: const Text('OPEN LONG DURATION'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN LONG DURATION'));
    await tester.pumpAndSettle();
    expect(find.text('25'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('orbital-time-picker-ok')));
    await tester.pumpAndSettle();
    expect(result, const Duration(hours: 25, minutes: 30));
  });

  testWidgets('STATUS work picker returns the explicit 24:00 boundary', (
    tester,
  ) async {
    OperationCivilTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showSharedStatusWorkTimePicker(
                context,
                initialTime: const OperationCivilTime(hour: 24, minute: 0),
              );
            },
            child: const Text('OPEN WORK'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN WORK'));
    await tester.pumpAndSettle();
    expect(find.text('24'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('orbital-time-picker-ok')));
    await tester.pumpAndSettle();
    expect(result?.clockString, '24:00');
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
