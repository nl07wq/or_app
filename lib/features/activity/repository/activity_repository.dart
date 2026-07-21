import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/activity_data.dart';

abstract class ActivityRepository {
  Future<void> save(ActivityData data);
  Future<ActivityData?> findByDate(DateTime date);
  Future<List<ActivityData>> getAll();
  Future<void> deleteByDate(DateTime date);
}

class LocalActivityRepository implements ActivityRepository {
  static const _key = 'activity_records';

  const LocalActivityRepository();

  @override
  Future<void> save(ActivityData data) async {
    final records = await getAll();
    final previousDate = DateTime(
      data.date.year,
      data.date.month,
      data.date.day - 1,
    );
    final previousRecord = records.where(
      (record) => _isSameDate(record.date, previousDate),
    );
    data.officialStepsFor(
      previousRecord.isEmpty ? 0 : previousRecord.first.carryOver,
    );
    records.removeWhere((record) => _isSameDate(record.date, data.date));
    records.add(data);
    await _write(records);
  }

  @override
  Future<ActivityData?> findByDate(DateTime date) async {
    final records = await getAll();
    for (final record in records) {
      if (_isSameDate(record.date, date)) return record;
    }
    return null;
  }

  @override
  Future<List<ActivityData>> getAll() async {
    final preferences = await SharedPreferences.getInstance();
    final records = (preferences.getStringList(_key) ?? [])
        .map((value) => ActivityData.fromJson(jsonDecode(value)))
        .toList();
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  @override
  Future<void> deleteByDate(DateTime date) async {
    final records = await getAll();
    records.removeWhere((record) => _isSameDate(record.date, date));
    await _write(records);
  }

  Future<void> _write(List<ActivityData> records) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      records.map((record) => jsonEncode(record.toJson())).toList(),
    );
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
