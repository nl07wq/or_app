import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/repositories/daily_log_confirmation_repository.dart';
import 'package:or_app/core/services/daily_log_confirmation_service.dart';
import 'package:or_app/core/services/daily_log_confirmation_state.dart';
import 'package:or_app/core/services/daily_state_restore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Map<String, dynamic> morningJson(DateTime date) => {
    'date': date.toIso8601String(), 'weight': 90.0, 'bodyFat': 30.0,
    'sleepHours': 7.0, 'sleepScore': 0, 'footPain': 0,
    'bowelAmount': 0, 'bowelShape': 0, 'workType': 'work',
    'workStart': '', 'workEnd': '', 'workBreak': '', 'workHours': 0.0, 'memo': '',
  };

  test('confirmation requires Morning data', () async {
    SharedPreferences.setMockInitialValues({});
    expect(DailyLogConfirmationService.confirmToday(), throwsStateError);
  });

  test('confirmation persists Morning and preserves missing optional modules', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'morning_records': [jsonEncode(morningJson(today))],
    });
    final confirmation = await DailyLogConfirmationService.confirmToday();
    final stored = await DailyLogConfirmationRepository.findByDate(today);
    expect(confirmation.morning, isNotNull);
    expect(stored?.food, isNull);
    expect(stored?.activity, isNull);
    expect(stored?.training, isNull);
    expect(dailyLogConfirmationNotifier.value.isConfirmed, isTrue);
  });

  test('recorded zero-step Activity is preserved in the snapshot', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'morning_records': [jsonEncode(morningJson(today))],
      'activity_records': [jsonEncode({'date': today.toIso8601String(), 'steps': 0})],
    });
    final confirmation = await DailyLogConfirmationService.confirmToday();
    expect(confirmation.activity, isNotNull);
    expect(confirmation.activity!.isRecorded, isTrue);
    expect(confirmation.activity!.steps, 0);
  });

  test('stored snapshot remains unchanged after live source replacement', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'morning_records': [jsonEncode(morningJson(today))],
    });
    await DailyLogConfirmationService.confirmToday();
    final updated = morningJson(today)..['weight'] = 80.0;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('morning_records', [jsonEncode(updated)]);
    final stored = await DailyLogConfirmationRepository.findByDate(today);
    expect(stored!.morning!.weight, 90.0);
  });

  test('startup restore publishes confirmed status with its timestamp', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'morning_records': [jsonEncode(morningJson(today))],
    });
    final confirmation = await DailyLogConfirmationService.confirmToday();
    DailyStateRestoreService.resetForTesting();
    await DailyStateRestoreService.restore();
    expect(dailyLogConfirmationNotifier.value.isConfirmed, isTrue);
    expect(dailyLogConfirmationNotifier.value.confirmedAt, confirmation.confirmedAt);
  });
}
