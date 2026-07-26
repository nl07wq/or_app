import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/activity_data.dart';
import '../../../core/services/persistence_access.dart';
import '../../repositories/app_repository_container.dart';
import '../migration/activity_legacy_reader.dart';

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
    PersistenceAccess.requireWrite('activity.save');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.activity.save(data);
    }
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
    PersistenceAccess.requireReadable('activity.findById');
    if (PersistenceAccess.canReadIndexedDb) {
      return AppRepositoryRegistry.container.activity.findById(id);
    }
    final records = await getAll();
    for (final record in records) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  Future<ActivityData?> findByDate(DateTime date) async {
    PersistenceAccess.requireReadable('activity.findByDate');
    if (PersistenceAccess.canReadIndexedDb) {
      return AppRepositoryRegistry.container.activity.findByDate(date);
    }
    final records = await getAll();
    for (final record in records) {
      if (_isSameDate(record.date, date)) return record;
    }
    return null;
  }

  @override
  Future<List<ActivityData>> getAll() async {
    PersistenceAccess.requireReadable('activity.getAll');
    if (PersistenceAccess.canReadIndexedDb) {
      return AppRepositoryRegistry.container.activity.findAll();
    }
    if (!PersistenceAccess.usesCompatibilityStorage) {
      final result = await ActivityLegacyReader().read();
      final records = result.validRecords.map((record) => record.data).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return List.unmodifiable(records);
    }
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
    PersistenceAccess.requireWrite('activity.delete');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.activity.delete(id);
    }
    final records = (await getAll()).toList();
    records.removeWhere((record) => record.id == id);
    await _write(records);
  }

  @override
  Future<void> deleteByDate(DateTime date) async {
    PersistenceAccess.requireWrite('activity.deleteByDate');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.activity.deleteByDate(date);
    }
    final records = (await getAll()).toList();
    records.removeWhere((record) => _isSameDate(record.date, date));
    await _write(records);
  }

  @override
  Future<void> clear() async {
    PersistenceAccess.requireWrite('activity.clear');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.activity.clear();
    }
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
