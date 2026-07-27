import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/repositories/daily_log_confirmation_repository.dart';
import 'package:or_app/core/services/daily_log_confirmation_service.dart';
import 'package:or_app/core/services/daily_log_confirmation_state.dart';
import 'package:or_app/core/services/daily_log_confirmation_validation.dart';
import 'package:or_app/core/services/daily_state_restore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('confirmation reports every missing required module', () async {
    SharedPreferences.setMockInitialValues({});

    await expectLater(
      DailyLogConfirmationService.confirmToday(),
      throwsA(
        isA<DailyLogValidationException>().having(
          (error) => error.invalidModules,
          'invalidModules',
          [DailyLogModule.status, DailyLogModule.food, DailyLogModule.activity],
        ),
      ),
    );
    expect(
      await DailyLogConfirmationRepository.findByDate(DateTime.now()),
      isNull,
    );
  });

  test('Quick Water alone does not complete FOOD', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues(
      _validSourceValues(today, foodRecords: [_waterJson(today)]),
    );

    await expectLater(
      DailyLogConfirmationService.confirmToday(),
      throwsA(
        isA<DailyLogValidationException>().having(
          (error) => error.invalidModules,
          'invalidModules',
          [DailyLogModule.food],
        ),
      ),
    );
  });

  test(
    'confirmation persists required snapshots and optional Training',
    () async {
      final today = DateTime.now();
      SharedPreferences.setMockInitialValues(_validSourceValues(today));

      final confirmation = await DailyLogConfirmationService.confirmToday(
        estimatedTotalBurnKcal: 2850,
      );
      final stored = await DailyLogConfirmationRepository.findByDate(today);

      expect(confirmation.morning, isNotNull);
      expect(confirmation.food?.mealCount, 1);
      expect(confirmation.activity?.officialSteps, 0);
      expect(confirmation.training, isNull);
      expect(confirmation.estimatedTotalBurnKcal, 2850);
      expect(stored?.estimatedTotalBurnKcal, 2850);
      expect(dailyLogConfirmationNotifier.value.isConfirmed, isTrue);
    },
  );

  test('confirmation snapshots the formal digestive summary', () async {
    final today = DateTime.now();
    final values = _validSourceValues(today);
    final activity = _activityJson(today)
      ..['digestiveEvents'] = [
        {
          'id': 'digestive:today:1',
          'sequence': 1,
          'amount': 1,
          'shape': 2,
          'relief': 0,
          'recordedAt': today.toIso8601String(),
        },
        {
          'id': 'digestive:today:2',
          'sequence': 2,
          'amount': 3,
          'shape': 3,
          'relief': 2,
          'recordedAt': today.add(const Duration(hours: 1)).toIso8601String(),
        },
      ];
    values['activity_records'] = [jsonEncode(activity)];
    SharedPreferences.setMockInitialValues(values);

    final confirmation = await DailyLogConfirmationService.confirmToday();
    final stored = await DailyLogConfirmationRepository.findByDate(today);

    expect(confirmation.activity?.digestiveSummary?.eventCount, 2);
    expect(confirmation.activity?.digestiveSummary?.totalAmount, 4);
    expect(confirmation.activity?.digestiveSummary?.latestShape, 3);
    expect(confirmation.activity?.digestiveSummary?.latestRelief, 2);
    expect(confirmation.activity?.digestiveSummary?.shapeTrend, [2, 3]);
    expect(confirmation.activity?.digestiveSummary?.reliefTrend, [0, 2]);
    expect(
      stored?.activity?.digestiveSummary?.toJson(),
      confirmation.activity?.digestiveSummary?.toJson(),
    );

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('activity_records', [
      jsonEncode(_activityJson(today)),
    ]);
    expect(
      (await DailyLogConfirmationRepository.findByDate(
        today,
      ))?.activity?.digestiveSummary?.toJson(),
      confirmation.activity?.digestiveSummary?.toJson(),
    );
  });

  test('confirmation snapshots calculated FOOD amount nutrition', () async {
    final today = DateTime.now();
    final meal = _mealJson(today)
      ..['items'] = [
        {
          'name': 'Chicken',
          'calories': 165,
          'protein': 31,
          'fat': 3.6,
          'carbohydrate': 0,
          'quantity': 1,
          'amount': 2.5,
          'baseAmount': 100,
          'baseUnit': 'g',
          'amountMode': 'baseMultiplier',
          'calculatedCalories': 412.5,
          'calculatedProtein': 77.5,
          'calculatedFat': 9,
          'calculatedCarbohydrate': 0,
        },
      ];
    SharedPreferences.setMockInitialValues(
      _validSourceValues(today, foodRecords: [meal]),
    );

    final confirmation = await DailyLogConfirmationService.confirmToday();
    expect(confirmation.food?.calories, 412.5);
    expect(confirmation.food?.protein, 77.5);
    expect(confirmation.food?.fat, 9);
    expect(confirmation.food?.carbohydrates, 0);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('meal_records', [
      jsonEncode(_mealJson(today)),
    ]);
    final stored = await DailyLogConfirmationRepository.findByDate(today);
    expect(stored?.food?.calories, 412.5);
    expect(stored?.food?.protein, 77.5);
  });

  test('Activity with inconsistent calculation basis is rejected', () async {
    final today = DateTime.now();
    final values = _validSourceValues(today);
    final previous = DateTime(today.year, today.month, today.day - 1);
    final previousActivity = _activityJson(previous)
      ..['carryOver'] = 10
      ..['carryoverSteps'] = 10;
    values['activity_records'] = [
      jsonEncode(previousActivity),
      jsonEncode(_activityJson(today)),
    ];
    SharedPreferences.setMockInitialValues(values);

    await expectLater(
      DailyLogConfirmationService.confirmToday(),
      throwsA(
        isA<DailyLogValidationException>().having(
          (error) => error.invalidModules,
          'invalidModules',
          [DailyLogModule.activity],
        ),
      ),
    );
  });

  test(
    'corrupt existing Training is not treated as optional missing',
    () async {
      final today = DateTime.now();
      final values = _validSourceValues(today)
        ..['training_sessions'] = ['{"invalid":true}'];
      SharedPreferences.setMockInitialValues(values);

      await expectLater(
        DailyLogConfirmationService.confirmToday(),
        throwsA(anyOf(isA<FormatException>(), isA<TypeError>())),
      );
    },
  );

  test(
    'stored snapshot remains unchanged after live source replacement',
    () async {
      final today = DateTime.now();
      SharedPreferences.setMockInitialValues(_validSourceValues(today));
      await DailyLogConfirmationService.confirmToday(
        estimatedTotalBurnKcal: 2400,
      );

      final updated = _morningJson(today)..['weight'] = 80.0;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList('morning_records', [jsonEncode(updated)]);
      final stored = await DailyLogConfirmationRepository.findByDate(today);

      expect(stored!.morning!.weight, 90.0);
      expect(stored.estimatedTotalBurnKcal, 2400);
    },
  );

  test(
    'startup restore publishes confirmed status with its timestamp',
    () async {
      final today = DateTime.now();
      SharedPreferences.setMockInitialValues(_validSourceValues(today));
      final confirmation = await DailyLogConfirmationService.confirmToday();

      DailyStateRestoreService.resetForTesting();
      await DailyStateRestoreService.restore();

      expect(dailyLogConfirmationNotifier.value.isConfirmed, isTrue);
      expect(
        dailyLogConfirmationNotifier.value.confirmedAt,
        confirmation.confirmedAt,
      );
    },
  );
}

Map<String, Object> _validSourceValues(
  DateTime date, {
  List<Map<String, dynamic>>? foodRecords,
}) {
  return {
    'morning_records': [jsonEncode(_morningJson(date))],
    'meal_records': [
      for (final record in foodRecords ?? [_mealJson(date)]) jsonEncode(record),
    ],
    'activity_records': [jsonEncode(_activityJson(date))],
  };
}

Map<String, dynamic> _morningJson(DateTime date) => {
  'date': date.toIso8601String(),
  'weight': 90.0,
  'bodyFat': 30.0,
  'sleepHours': 7.0,
  'sleepScore': 80,
  'footPain': 1,
  'bowelAmount': 0,
  'bowelShape': 0,
  'workType': 'work',
  'workStart': '09:00',
  'workEnd': '18:00',
  'workBreak': '01:00',
  'workHours': 8.0,
  'memo': '',
};

Map<String, dynamic> _mealJson(DateTime date) => {
  'id': 'meal-1',
  'date': date.toIso8601String().split('T').first,
  'mealType': 'Breakfast',
  'items': <Object>[],
  'memo': '',
};

Map<String, dynamic> _waterJson(DateTime date) => {
  'id': 'water-1',
  'date': date.toIso8601String().split('T').first,
  'mealType': 'Water',
  'items': <Object>[],
  'memo': '',
  'waterMl': 500.0,
};

Map<String, dynamic> _activityJson(DateTime date) => {
  'id': date.toIso8601String().split('T').first,
  'date': date.toIso8601String(),
  'steps': 0,
  'measuredSteps': 0,
  'rawSteps': 0,
  'stepsEntered': true,
  'carryOver': 0,
  'carryoverSteps': 0,
  'carryOverEntered': true,
  'trainingStatus': 'unconfirmed',
  'bowelMovement': {'status': 'none'},
  'createdAt': date.toIso8601String(),
  'updatedAt': date.toIso8601String(),
};
