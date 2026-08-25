import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/status/services/status_latest_valid_values_resolver.dart';

void main() {
  test('resolves every nullable STATUS field independently', () {
    final resolved = StatusLatestValidValuesResolver.resolve([
      _status(
        '2026-08-20',
        weight: 95.8,
        bodyFat: 32.1,
        sleepHours: 7 + 20 / 60,
        sleepScore: 84,
      ),
      _status('2026-08-21', sleepHours: 6 + 10 / 60, sleepScore: 72),
      _status('2026-08-22', bodyFat: 31.9),
    ], beforeOrOnLocalDate: '2026-08-23');

    expect(resolved.weight?.value, 95.8);
    expect(resolved.weight?.localDate, '2026-08-20');
    expect(resolved.bodyFat?.value, 31.9);
    expect(resolved.bodyFat?.localDate, '2026-08-22');
    expect(resolved.sleepHours?.value, closeTo(6 + 10 / 60, 1e-12));
    expect(resolved.sleepHours?.localDate, '2026-08-21');
    expect(resolved.sleepScore?.value, 72);
    expect(resolved.sleepScore?.localDate, '2026-08-21');
  });

  test(
    'ignores future and invalid values without modifying source records',
    () {
      final current = _status('2026-08-22');
      final resolved = StatusLatestValidValuesResolver.resolve([
        _status('2026-08-20', weight: 95.8),
        current,
        _status('2026-08-24', weight: 100),
      ], beforeOrOnLocalDate: '2026-08-23');

      expect(resolved.weight?.value, 95.8);
      expect(current.weight, isNull);
      expect(current.bodyFat, isNull);
      expect(current.sleepHours, isNull);
      expect(current.sleepScore, isNull);
    },
  );

  test('returns null fields when no valid formal value exists', () {
    final resolved = StatusLatestValidValuesResolver.resolve([
      _status('2026-08-22'),
    ]);

    expect(resolved.weight, isNull);
    expect(resolved.bodyFat, isNull);
    expect(resolved.sleepHours, isNull);
    expect(resolved.sleepScore, isNull);
  });
}

MorningData _status(
  String localDate, {
  double? weight,
  double? bodyFat,
  double? sleepHours,
  int? sleepScore,
}) => MorningData(
  date: '${localDate}T07:00:00',
  weight: weight,
  bodyFat: bodyFat,
  sleepHours: sleepHours,
  sleepScore: sleepScore,
  footPain: 0,
  workType: WorkType.work,
  workStart: '09:00',
  workEnd: '18:00',
  workBreak: '01:00',
  workHours: 8,
  memo: '',
);
