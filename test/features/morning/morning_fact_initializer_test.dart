import 'dart:async';
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
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../operation_date/operation_date_test_fixture.dart';

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

  test('initializer resolves the latest valid value for each field', () async {
    await MorningRepository.save(
      _record(
        date: DateTime(2026, 8, 20),
        weight: 95.8,
        bodyFat: 32.1,
        sleepHours: 7 + 20 / 60,
        sleepScore: 84,
      ),
    );
    await MorningRepository.save(
      _record(
        date: DateTime(2026, 8, 21),
        weight: null,
        bodyFat: null,
        sleepHours: 6 + 10 / 60,
        sleepScore: 72,
      ),
    );
    await MorningRepository.save(
      _record(
        date: DateTime(2026, 8, 22),
        weight: null,
        bodyFat: 31.9,
        sleepHours: null,
        sleepScore: null,
      ),
    );

    final values = await const MorningFactInitializer().initialize(
      beforeOrOnLocalDate: '2026-08-23',
    );

    expect(values.weight, '95.8');
    expect(values.bodyFat, '31.9');
    expect(values.sleep, '6:10');
    expect(values.sleepScore, '72');
    final saved = await MorningRepository.getAll();
    expect(saved.first.weight, isNull);
    expect(saved.first.sleepHours, isNull);
  });

  test(
    'initializer skips an invalid dated record and uses valid history',
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

      expect(values.weight, '70.0');
      expect(values.bodyFat, '18.0');
      expect(values.sleep, '7:00');
      expect(values.sleepScore, '75');
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

    await tester.pumpWidget(
      MaterialApp(
        home: MorningFactPage(
          operationDateService: await operationDateServiceFor('2026-07-31'),
        ),
      ),
    );
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

  testWidgets('unmeasured toggles restore the latest measured STATUS values', (
    tester,
  ) async {
    await MorningRepository.save(
      _record(
        date: DateTime(2026, 7, 25),
        weight: 71.5,
        bodyFat: 17.5,
        sleepHours: 7.5,
        sleepScore: 82,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MorningFactPage(
          operationDateService: await operationDateServiceFor('2026-07-31'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var body = tester.widget<BodyCard>(find.byType(BodyCard));
    body.onWeightUnmeasured();
    await tester.pump();
    body = tester.widget<BodyCard>(find.byType(BodyCard));
    expect(body.weightController.text, isEmpty);
    expect(body.bodyFatController.text, isEmpty);
    body.onWeightMeasured();
    await tester.pump();
    body = tester.widget<BodyCard>(find.byType(BodyCard));
    expect(body.weightController.text, '71.5');
    expect(body.bodyFatController.text, '17.5');

    body.weightController.text = '72.1';
    body.bodyFatController.text = '17.2';
    body.onWeightUnmeasured();
    await tester.pump();
    body = tester.widget<BodyCard>(find.byType(BodyCard));
    body.onWeightMeasured();
    await tester.pump();
    body = tester.widget<BodyCard>(find.byType(BodyCard));
    expect(body.weightController.text, '72.1');
    expect(body.bodyFatController.text, '17.2');

    var recovery = tester.widget<RecoveryCard>(find.byType(RecoveryCard));
    recovery.onSleepTimeUnmeasured();
    await tester.pump();
    recovery = tester.widget<RecoveryCard>(find.byType(RecoveryCard));
    expect(recovery.sleepController.text, isEmpty);
    expect(recovery.sleepScoreController.text, isEmpty);
    recovery.onSleepTimeMeasured();
    await tester.pump();
    recovery = tester.widget<RecoveryCard>(find.byType(RecoveryCard));
    expect(recovery.sleepController.text, '7:30');
    expect(recovery.sleepScoreController.text, '82');

    recovery.sleepController.text = '8:05';
    recovery.sleepScoreController.text = '91';
    recovery.onSleepTimeUnmeasured();
    await tester.pump();
    recovery = tester.widget<RecoveryCard>(find.byType(RecoveryCard));
    recovery.onSleepTimeMeasured();
    await tester.pump();
    recovery = tester.widget<RecoveryCard>(find.byType(RecoveryCard));
    expect(recovery.sleepController.text, '8:05');
    expect(recovery.sleepScoreController.text, '91');
  });

  testWidgets('Operation Date gate hides new STATUS form until resolved', (
    tester,
  ) async {
    final operationState = Completer<OperationState>();
    await tester.pumpWidget(
      MaterialApp(
        home: MorningFactPage(
          operationDateService: operationDateServiceFromFuture(
            operationState.future,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(BodyCard), findsNothing);

    operationState.complete(operationStateForTest('2026-07-31'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(BodyCard), findsOneWidget);
  });

  testWidgets('Operation Date failure shows only STATUS error', (tester) async {
    final operationState = Completer<OperationState>();
    await tester.pumpWidget(
      MaterialApp(
        home: MorningFactPage(
          operationDateService: operationDateServiceFromFuture(
            operationState.future,
          ),
        ),
      ),
    );
    await tester.pump();
    operationState.completeError(StateError('missing operation state'));
    await tester.pumpAndSettle();

    expect(find.text('Operation Dateを取得できませんでした。'), findsOneWidget);
    expect(find.byType(BodyCard), findsNothing);
    expect(find.text('SAVE STATUS'), findsNothing);
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
  required double? weight,
  required double? bodyFat,
  required double? sleepHours,
  required int? sleepScore,
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
