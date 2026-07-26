import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/features/morning/models/morning_initial_values.dart';
import 'package:or_app/features/morning/morning_fact_page.dart';
import 'package:or_app/features/morning/services/morning_fact_initializer.dart';
import 'package:or_app/features/morning/widgets/body_card.dart';
import 'package:or_app/features/morning/widgets/foot_card.dart';
import 'package:or_app/features/morning/widgets/memo_input_card.dart';
import 'package:or_app/features/morning/widgets/recovery_card.dart';
import 'package:or_app/features/morning/widgets/work_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('empty repository produces empty initial values', () async {
    final values = await const MorningFactInitializer().initialize();

    expect(
      values,
      isA<MorningInitialValues>()
          .having((value) => value.weight, 'weight', isEmpty)
          .having((value) => value.bodyFat, 'bodyFat', isEmpty)
          .having((value) => value.sleep, 'sleep', isEmpty)
          .having((value) => value.sleepScore, 'sleepScore', isEmpty),
    );
  });

  test('initializer copies only the latest supported values', () async {
    await MorningRepository.save(
      _record(
        date: DateTime(2026, 7, 24),
        weight: 70,
        bodyFat: 18,
        sleepHours: 7,
        sleepScore: 75,
      ),
    );
    await MorningRepository.save(
      _record(
        date: DateTime(2026, 7, 25),
        weight: 71.5,
        bodyFat: 17.5,
        sleepHours: 7.5,
        sleepScore: 82,
      ),
    );

    final latest = await MorningRepository.loadLatest();
    final values = await const MorningFactInitializer().initialize();

    expect(latest?.date, DateTime(2026, 7, 25).toIso8601String());
    expect(values.weight, '71.5');
    expect(values.bodyFat, '17.5');
    expect(values.sleep, '7:30');
    expect(values.sleepScore, '82');
  });

  test(
    'initializer returns empty values when latest retrieval fails',
    () async {
      final invalid = _record(
        date: DateTime(2026, 7, 25),
        weight: 71.5,
        bodyFat: 17.5,
        sleepHours: 7.5,
        sleepScore: 82,
      ).toJson();
      invalid['date'] = 'invalid-date';
      SharedPreferences.setMockInitialValues({
        'morning_records': [
          jsonEncode(invalid),
          jsonEncode(
            _record(
              date: DateTime(2026, 7, 24),
              weight: 70,
              bodyFat: 18,
              sleepHours: 7,
              sleepScore: 75,
            ).toJson(),
          ),
        ],
      });

      final values = await const MorningFactInitializer().initialize();

      expect(values.weight, isEmpty);
      expect(values.bodyFat, isEmpty);
      expect(values.sleep, isEmpty);
      expect(values.sleepScore, isEmpty);
    },
  );

  testWidgets('new Morning page initializes controllers from latest record', (
    tester,
  ) async {
    await MorningRepository.save(
      _record(
        date: DateTime(2026, 7, 25),
        weight: 71.5,
        bodyFat: 17.5,
        sleepHours: 7.5,
        sleepScore: 82,
        footPain: 9,
        workType: WorkType.holiday,
        memo: 'previous memo',
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: MorningFactPage()));
    await tester.pumpAndSettle();

    final body = tester.widget<BodyCard>(find.byType(BodyCard));
    final recovery = tester.widget<RecoveryCard>(find.byType(RecoveryCard));
    final foot = tester.widget<FootCard>(find.byType(FootCard));
    final work = tester.widget<WorkCard>(find.byType(WorkCard));
    final memo = tester.widget<MemoInputCard>(find.byType(MemoInputCard));

    expect(body.weightController.text, '71.5');
    expect(body.bodyFatController.text, '17.5');
    expect(recovery.sleepController.text, '7:30');
    expect(recovery.sleepScoreController.text, '82');
    expect(foot.controller.text, isEmpty);
    expect(work.workType, WorkType.work);
    expect(work.startController.text, '11:00');
    expect(work.endController.text, '18:00');
    expect(work.breakController.text, '01:00');
    expect(memo.controller.text, isEmpty);
  });

  testWidgets('edit page uses existing data instead of latest record', (
    tester,
  ) async {
    await MorningRepository.save(
      _record(
        date: DateTime(2026, 7, 25),
        weight: 90,
        bodyFat: 30,
        sleepHours: 4,
        sleepScore: 40,
      ),
    );
    final existing = _record(
      date: DateTime(2026, 7, 20),
      weight: 71.5,
      bodyFat: 17.5,
      sleepHours: 7.5,
      sleepScore: 82,
      footPain: 4,
      workType: WorkType.holiday,
      memo: 'edit target',
    );

    await tester.pumpWidget(MaterialApp(home: MorningFactPage(data: existing)));
    await tester.pump();

    final body = tester.widget<BodyCard>(find.byType(BodyCard));
    final recovery = tester.widget<RecoveryCard>(find.byType(RecoveryCard));
    final foot = tester.widget<FootCard>(find.byType(FootCard));
    final work = tester.widget<WorkCard>(find.byType(WorkCard));
    final memo = tester.widget<MemoInputCard>(find.byType(MemoInputCard));

    expect(body.weightController.text, '71.5');
    expect(body.bodyFatController.text, '17.5');
    expect(recovery.sleepController.text, '7:30');
    expect(recovery.sleepScoreController.text, '82');
    expect(foot.controller.text, '4');
    expect(work.workType, WorkType.holiday);
    expect(memo.controller.text, 'edit target');
  });
}

MorningData _record({
  required DateTime date,
  required double weight,
  required double bodyFat,
  required double sleepHours,
  required int sleepScore,
  int footPain = 3,
  WorkType workType = WorkType.work,
  String memo = '',
}) {
  return MorningData(
    date: date.toIso8601String(),
    weight: weight,
    bodyFat: bodyFat,
    sleepHours: sleepHours,
    sleepScore: sleepScore,
    footPain: footPain,
    workType: workType,
    workStart: '06:00',
    workEnd: '14:00',
    workBreak: '00:30',
    workHours: 7.5,
    memo: memo,
  );
}
