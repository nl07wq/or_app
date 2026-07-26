import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/food/migration/food_legacy_reader.dart';
import '../../features/repositories/app_repository_container.dart';
import '../models/meal_data.dart';
import '../services/persistence_access.dart';

class FoodRepository {
  static const _key = 'meal_records';

  static Future<void> save(MealData data) async {
    PersistenceAccess.requireWrite('food.save');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.food.save(data);
    }
    final records = await _legacyGetAll()
      ..add(data);
    await _legacyWrite(records);
  }

  static Future<void> update(MealData data) async {
    PersistenceAccess.requireWrite('food.update');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.food.update(data);
    }
    final records = await _legacyGetAll();
    final index = records.indexWhere((record) => record.id == data.id);
    index == -1 ? records.add(data) : records[index] = data;
    await _legacyWrite(records);
  }

  static Future<List<MealData>> getAll() async {
    PersistenceAccess.requireReadable('food.getAll');
    if (PersistenceAccess.canReadIndexedDb) {
      return AppRepositoryRegistry.container.food.findAll();
    }
    if (!PersistenceAccess.usesCompatibilityStorage) {
      final result = await FoodLegacyReader().read();
      return List.unmodifiable(
        result.validRecords.map((record) => record.data),
      );
    }
    return _legacyGetAll();
  }

  static Future<void> clear() async {
    PersistenceAccess.requireWrite('food.clear');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.food.clear();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> remove(MealData data) async {
    PersistenceAccess.requireWrite('food.remove');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.food.deleteById(data.id);
    }
    final records = await _legacyGetAll()
      ..removeWhere((record) => record.id == data.id);
    await _legacyWrite(records);
  }

  static Future<List<MealData>> _legacyGetAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const [])
        .map((value) => MealData.fromJson(jsonDecode(value)))
        .toList();
  }

  static Future<void> _legacyWrite(List<MealData> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      records.map((record) => jsonEncode(record.toJson())).toList(),
    );
  }
}
