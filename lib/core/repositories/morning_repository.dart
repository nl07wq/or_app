import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/morning_data.dart';

class MorningRepository {
  static const _storageKey = 'morning_records';

  static List<MorningData> _records = [];

  static Future<void> add(MorningData data) async {
    _records.add(data);
    await save();
  }

  static List<MorningData> getAll() {
    return List.unmodifiable(_records);
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null) {
      _records = [];
      return;
    }

    final List decoded = jsonDecode(jsonString);

    _records = decoded.map((e) => MorningData.fromJson(e)).toList();
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonString = jsonEncode(_records.map((e) => e.toJson()).toList());

    await prefs.setString(_storageKey, jsonString);
  }

  static Future<void> clear() async {
    _records.clear();
    await save();
  }
}
