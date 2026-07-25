import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/morning_fact/services/morning_fact_builder.dart';

void main() {
  test('builder passes raw values into an immutable MorningFact', () {
    final date = DateTime(2026, 7, 25);

    final fact = MorningFactBuilder.build(
      date: date,
      weight: 72.5,
      bodyFat: 18.2,
      sleepDuration: const Duration(hours: 7, minutes: 30),
      sleepScore: 82,
      footPain: 2,
      condition: 4,
      hydration: 500,
      workSchedule: '11:00-18:00',
      previousCarryoverConfirmed: true,
      note: 'Ready',
    );

    expect(fact.date, same(date));
    expect(fact.weight, 72.5);
    expect(fact.bodyFat, 18.2);
    expect(fact.sleepDuration, const Duration(hours: 7, minutes: 30));
    expect(fact.sleepScore, 82);
    expect(fact.footPain, 2);
    expect(fact.condition, 4);
    expect(fact.bowel, isNull);
    expect(fact.hydration, 500);
    expect(fact.workSchedule, '11:00-18:00');
    expect(fact.previousCarryoverConfirmed, isTrue);
    expect(fact.note, 'Ready');
  });

  test('all MorningFact values may be absent', () {
    final fact = MorningFactBuilder.build();

    expect(fact.date, isNull);
    expect(fact.weight, isNull);
    expect(fact.bodyFat, isNull);
    expect(fact.sleepDuration, isNull);
    expect(fact.sleepScore, isNull);
    expect(fact.footPain, isNull);
    expect(fact.condition, isNull);
    expect(fact.bowel, isNull);
    expect(fact.hydration, isNull);
    expect(fact.workSchedule, isNull);
  });
}
