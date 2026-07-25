import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/activity/services/bowel_movement_resolver.dart';
import 'package:or_app/features/activity/services/morning_fact_activity_mapper.dart';

void main() {
  const resolver = BowelMovementResolver();
  const mapper = MorningFactActivityMapper();

  test(
    'reads legacy Morning bowel data without converting missing to none',
    () {
      final legacy = MorningData.fromJson(_morningJson(bowelAmount: 2));
      final missing = MorningData.fromJson(_morningJson());

      expect(
        resolver.resolve(legacyMorning: legacy).status,
        BowelMovementStatus.recorded,
      );
      expect(
        resolver.resolve(legacyMorning: missing).status,
        BowelMovementStatus.unconfirmed,
      );
    },
  );

  test('new Activity bowel wins over legacy Morning bowel', () {
    final morning = MorningData.fromJson(_morningJson(bowelAmount: 2));
    final activity = ActivityData(
      date: DateTime(2026, 7, 25),
      measuredSteps: 1000,
      bowelMovement: const BowelMovementRecord.none(),
    );

    expect(
      resolver.resolve(activity: activity, legacyMorning: morning).status,
      BowelMovementStatus.none,
    );
  });

  test('legacy repository text remains readable as fallback', () {
    final result = resolver.resolve(legacyMorningBowel: 'normal');

    expect(result.status, BowelMovementStatus.recorded);
    expect(result.amount, isNull);
  });

  test('Morning creates an incomplete Activity initial value', () {
    final morning = MorningData.fromJson(_morningJson());

    final activity = mapper.initialize(morning: morning);

    expect(activity.date, DateTime(2026, 7, 25));
    expect(activity.rawSteps, isNull);
    expect(activity.carryoverSteps, isNull);
    expect(activity.plannedWork, contains('work'));
    expect(activity.bowelMovement.status, BowelMovementStatus.unconfirmed);
  });

  test('Morning initialization never overwrites an existing Activity', () {
    final morning = MorningData.fromJson(_morningJson());
    final existing = ActivityData(
      date: DateTime(2026, 7, 25),
      measuredSteps: 9000,
      plannedWork: 'custom',
      bowelMovement: BowelMovementRecord.recorded(amount: 2, shape: 1),
    );

    final result = mapper.initialize(
      morning: morning,
      existingActivity: existing,
    );

    expect(identical(result, existing), isTrue);
    expect(result.measuredSteps, 9000);
    expect(result.plannedWork, 'custom');
    expect(result.bowelMovement.amount, 2);
    expect(result.bowelMovement.shape, 1);
  });
}

Map<String, dynamic> _morningJson({int? bowelAmount}) {
  final json = <String, dynamic>{
    'date': '2026-07-25T06:00:00.000',
    'weight': 72.5,
    'bodyFat': 18.0,
    'sleepHours': 7.5,
    'sleepScore': 80,
    'footPain': 2,
    'workType': WorkType.work.name,
    'workStart': '11:00',
    'workEnd': '18:00',
    'workBreak': '01:00',
    'workHours': 6.0,
    'memo': '',
  };
  if (bowelAmount != null) {
    json['bowelAmount'] = bowelAmount;
    json['bowelShape'] = 1;
  }
  return json;
}
