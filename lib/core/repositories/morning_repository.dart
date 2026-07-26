import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/repositories/app_repository_container.dart';
import '../../features/status/migration/status_legacy_reader.dart';
import '../models/morning_data.dart';
import '../services/persistence_access.dart';

class MorningRepository {
  static const _key = 'morning_records';

  static Future<void> save(MorningData data) async {
    PersistenceAccess.requireWrite('status.save');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.status.save(data);
    }
    final records = await _legacyGetAll();
    records.add(data);
    await _legacyWrite(records);
  }

  static Future<void> update(MorningData data) async {
    PersistenceAccess.requireWrite('status.update');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      final existing = await AppRepositoryRegistry.container.status
          .findByLocalDate(data.date.substring(0, 10));
      if (existing == null) {
        throw StateError('Morning record to update was not found.');
      }
      return AppRepositoryRegistry.container.status.save(data);
    }
    final records = await _legacyGetAll();
    final index = records.indexWhere(
      (record) => record.date.substring(0, 10) == data.date.substring(0, 10),
    );
    if (index == -1) {
      throw StateError('Morning record to update was not found.');
    }
    records[index] = data;
    await _legacyWrite(records);
  }

  static Future<List<MorningData>> getAll() async {
    PersistenceAccess.requireReadable('status.getAll');
    if (PersistenceAccess.canReadIndexedDb) {
      final result = await AppRepositoryRegistry.container.status
          .findAllCanonical();
      if (result.hasIssues) {
        throw StateError('STATUS contains unreadable records.');
      }
      return List.unmodifiable(result.values);
    }
    if (!PersistenceAccess.usesCompatibilityStorage) {
      final result = await StatusLegacyReader().read();
      return List.unmodifiable(
        result.validRecords.map((record) => record.data).toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
      );
    }
    return _legacyGetAll();
  }

  static Future<MorningData?> loadLatest() async {
    if (PersistenceAccess.canReadIndexedDb) {
      return AppRepositoryRegistry.container.status.findLatest();
    }
    final records = await getAll();
    if (records.isEmpty) return null;
    return records.reduce((latest, record) {
      final latestDate = DateTime.parse(latest.date);
      final recordDate = DateTime.parse(record.date);
      return recordDate.isAfter(latestDate) ? record : latest;
    });
  }

  static Future<void> clear() async {
    PersistenceAccess.requireWrite('status.clear');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.status.clear();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> remove(MorningData data) async {
    PersistenceAccess.requireWrite('status.remove');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.status.deleteByLocalDate(
        data.date.substring(0, 10),
      );
    }
    final records = await _legacyGetAll()
      ..removeWhere((record) => record.date == data.date);
    await _legacyWrite(records);
  }

  static Future<List<MorningData>> _legacyGetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key) ?? const [];
    final records = values
        .map((value) => MorningData.fromJson(jsonDecode(value)))
        .toList();
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  static Future<void> _legacyWrite(List<MorningData> records) async {
    records.sort((a, b) => b.date.compareTo(a.date));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      records.map((record) => jsonEncode(record.toJson())).toList(),
    );
  }
}
