import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/body_history/services/data_center_history_range_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  DataCenterHistoryRangePreference preference() =>
      DataCenterHistoryRangePreference(
        preferencesLoader: () async => preferences,
      );

  test('defaults to one week when no valid preference exists', () async {
    expect((await preference().load()).period, BodyHistoryPeriod.oneWeek);

    await preferences.setString(
      DataCenterHistoryRangePreference.storageKey,
      '{"version":1,"period":"unknown"}',
    );
    expect((await preference().load()).period, BodyHistoryPeriod.oneWeek);
  });

  test(
    'shares a persisted period across independent History readers',
    () async {
      await preference().save(BodyHistoryPeriod.oneMonth);

      final bodySelection = await preference().load();
      final nutritionSelection = await preference().load();
      expect(bodySelection.period, BodyHistoryPeriod.oneMonth);
      expect(nutritionSelection.period, BodyHistoryPeriod.oneMonth);

      await preference().save(BodyHistoryPeriod.oneWeek);
      expect((await preference().load()).period, BodyHistoryPeriod.oneWeek);
    },
  );

  test(
    'restores valid custom dates and rejects incomplete custom state',
    () async {
      final custom = DateTimeRange(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 5),
      );
      await preference().save(BodyHistoryPeriod.custom, customRange: custom);

      final restored = await preference().load();
      expect(restored.period, BodyHistoryPeriod.custom);
      expect(restored.customRange, custom);

      await preferences.setString(
        DataCenterHistoryRangePreference.storageKey,
        '{"version":1,"period":"custom","customStart":"2026-09-01"}',
      );
      expect((await preference().load()).period, BodyHistoryPeriod.oneWeek);
    },
  );
}
