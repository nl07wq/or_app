import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/activity_data.dart';

abstract class ActivityRepository {
  Future<void> save(ActivityData data);
  Future<ActivityData?> findById(String id);
  Future<ActivityData?> findByDate(DateTime date);
  Future<List<ActivityData>> findAll();
  Future<void> delete(String id);
  Future<void> clear();

  /// Backward-compatible aliases used by the current Activity UI.
  Future<List<ActivityData>> getAll();
  Future<void> deleteByDate(DateTime date);
}

class LocalActivityRepository implements ActivityRepository {
  static const _key = 'activity_records';

  const LocalActivityRepository();

  @override
  Future<void> save(ActivityData data) async {
    final records = (await getAll()).toList();
    final previousDate = DateTime(
      data.date.year,
      data.date.month,
      data.date.day - 1,
    );
    final previousRecord = records.where(
      (record) => _isSameDate(record.date, previousDate),
    );
    final previousCarryOver = previousRecord.isEmpty
        ? 0
        : previousRecord.first.carryOver;
    final officialSteps = data.stepsEntered
        ? data.officialStepsFor(previousCarryOver)
        : null;
    records.removeWhere(
      (record) => record.id == data.id || _isSameDate(record.date, data.date),
    );
    records.add(
      data.copyWith(officialSteps: officialSteps, updatedAt: DateTime.now()),
    );
    await _write(records);
  }

  @override
  Future<ActivityData?> findById(String id) async {
    final records = await getAll();
    for (final record in records) {
      if (record.id == id) return record;
    }
    return null;
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
    return List.unmodifiable(records);
  }

  @override
  Future<List<ActivityData>> findAll() => getAll();

  @override
  Future<void> delete(String id) async {
    final records = (await getAll()).toList();
    records.removeWhere((record) => record.id == id);
    await _write(records);
  }

  @override
  Future<void> deleteByDate(DateTime date) async {
    final records = (await getAll()).toList();
    records.removeWhere((record) => _isSameDate(record.date, date));
    await _write(records);
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
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
