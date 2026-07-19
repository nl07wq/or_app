import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_data.dart';

class FoodRepository {
  static const _key = 'meal_records';

  static Future<void> save(MealData data) async {
    final prefs = await SharedPreferences.getInstance();

    final list = await getAll();

    list.add(data);

    final jsonList = list.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList(_key, jsonList);
  }

  static Future<void> update(MealData data) async {
    final prefs = await SharedPreferences.getInstance();

    final list = await getAll();

    final index = list.indexWhere((e) => e.id == data.id);

    if (index == -1) {
      list.add(data);
    } else {
      list[index] = data;
    }

    final jsonList = list.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<MealData>> getAll() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = prefs.getStringList(_key) ?? [];

    return jsonList.map((e) => MealData.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }

  static Future<void> remove(MealData data) async {
    final prefs = await SharedPreferences.getInstance();

    final list = await getAll();

    list.removeWhere((e) => e.id == data.id);

    final jsonList = list.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList(_key, jsonList);
  }
}
