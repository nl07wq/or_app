import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/food_data.dart';

class FoodRepository {
  static const _key = 'food_records';

  static Future<void> save(FoodData data) async {
    final prefs = await SharedPreferences.getInstance();

    final list = await getAll();

    list.add(data);

    final jsonList = list.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<FoodData>> getAll() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = prefs.getStringList(_key) ?? [];

    return jsonList.map((e) => FoodData.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }

  static Future<void> remove(FoodData data) async {
    final prefs = await SharedPreferences.getInstance();

    final list = await getAll();

    list.removeWhere((e) => e.date == data.date && e.meal == data.meal);
    
    final jsonList = list.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList(_key, jsonList);
  }
}
