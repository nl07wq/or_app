import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/morning_data.dart';

class MorningRepository {
  static const _key = 'morning_records';

  static Future<void> save(MorningData data) async {
    final prefs = await SharedPreferences.getInstance();

    final list = await getAll();

    list.add(data);

    list.sort(
      (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)),
    );

    final jsonList = list.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList(_key, jsonList);
  }

  static Future<void> update(MorningData data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    final index = list.indexWhere((record) => record.date == data.date);

    if (index == -1) {
      throw StateError('Morning record to update was not found.');
    }

    list[index] = data;

    list.sort(
      (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)),
    );

    final jsonList = list.map((entry) => jsonEncode(entry.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<MorningData>> getAll() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final jsonList = prefs.getStringList(_key) ?? [];

      return jsonList.map((e) => MorningData.fromJson(jsonDecode(e))).toList();
    } catch (_) {
      // 旧フォーマットのデータは破棄
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<MorningData?> loadLatest() async {
    final records = await getAll();
    if (records.isEmpty) return null;

    return records.reduce((latest, record) {
      final latestDate = DateTime.parse(latest.date);
      final recordDate = DateTime.parse(record.date);
      return recordDate.isAfter(latestDate) ? record : latest;
    });
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }

  static Future<void> remove(MorningData data) async {
    final prefs = await SharedPreferences.getInstance();

    final list = await getAll();

    list.removeWhere((e) => e.date == data.date);

    final jsonList = list.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList(_key, jsonList);
  }
}
