import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/body_history/services/data_center_history_range_preference.dart';
import 'package:or_app/features/training/services/training_history_overview_adapter.dart';
import 'package:or_app/features/training/services/training_history_range_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  TrainingHistoryRangePreference trainingPreference() =>
      TrainingHistoryRangePreference(
        preferencesLoader: () async => preferences,
      );

  DataCenterHistoryRangePreference bodyPreference() =>
      DataCenterHistoryRangePreference(
        preferencesLoader: () async => preferences,
      );

  test('defaults to one week and restores each preset independently', () async {
    expect(
      (await trainingPreference().load()).period,
      TrainingHistoryOverviewPeriod.oneWeek,
    );

    for (final period in [
      TrainingHistoryOverviewPeriod.threeMonths,
      TrainingHistoryOverviewPeriod.oneYear,
      TrainingHistoryOverviewPeriod.all,
    ]) {
      await trainingPreference().save(period);
      expect((await trainingPreference().load()).period, period);
    }
  });

  test(
    'restores a valid custom range and rejects incomplete custom state',
    () async {
      final range = DateTimeRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      await trainingPreference().save(
        TrainingHistoryOverviewPeriod.custom,
        customRange: range,
      );

      final restored = await trainingPreference().load();
      expect(restored.period, TrainingHistoryOverviewPeriod.custom);
      expect(restored.customRange, range);

      await preferences.setString(
        TrainingHistoryRangePreference.storageKey,
        '{"version":1,"period":"custom","customStart":"2026-08-01"}',
      );
      expect(
        (await trainingPreference().load()).period,
        TrainingHistoryOverviewPeriod.oneWeek,
      );
    },
  );

  test('keeps Body and Training History period preferences isolated', () async {
    await bodyPreference().save(BodyHistoryPeriod.oneMonth);
    await trainingPreference().save(TrainingHistoryOverviewPeriod.oneYear);

    expect((await bodyPreference().load()).period, BodyHistoryPeriod.oneMonth);
    expect(
      (await trainingPreference().load()).period,
      TrainingHistoryOverviewPeriod.oneYear,
    );
  });
}
