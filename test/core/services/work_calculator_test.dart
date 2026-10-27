import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/work_calculator.dart';

void main() {
  group('WorkCalculator civil-day boundaries', () {
    test('preserves noon, end-of-day, and overnight work intervals', () {
      expect(
        WorkCalculator.calculate(
          start: '12:00',
          end: '18:00',
          workBreak: '00:00',
        ),
        6,
      );
      expect(
        WorkCalculator.calculate(
          start: '18:00',
          end: '24:00',
          workBreak: '00:00',
        ),
        6,
      );
      expect(
        WorkCalculator.calculate(
          start: '22:00',
          end: '02:00',
          workBreak: '00:00',
        ),
        4,
      );
      expect(
        WorkCalculator.calculate(
          start: '00:00',
          end: '08:00',
          workBreak: '00:00',
        ),
        8,
      );
    });

    test('accepts only the exact 24:00 end-of-day boundary', () {
      expect(WorkCalculator.isValidClockTime('24:00'), isTrue);
      expect(WorkCalculator.isValidClockTime('24:01'), isFalse);
      expect(WorkCalculator.isValidClockTime('12:00'), isTrue);
      expect(WorkCalculator.isValidClockTime('00:00'), isTrue);
    });
  });
}
