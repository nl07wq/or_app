import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/training_session.dart';

class TrainingRepository {
  static const _key = 'training_sessions';

  static Future<void> save(TrainingSession session) async {
    final prefs = await SharedPreferences.getInstance();

    final list = await getAll();

    list.add(session);

    final jsonList = list.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<TrainingSession>> getAll() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final jsonList = prefs.getStringList(_key) ?? [];

      return jsonList
          .map((e) => TrainingSession.fromJson(jsonDecode(e)))
          .toList();
    } catch (_) {
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }

  static Future<void> remove(TrainingSession session) async {
    final prefs = await SharedPreferences.getInstance();

    final list = await getAll();

    list.removeWhere((e) => e.date == session.date && e.memo == session.memo);

    final jsonList = list.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList(_key, jsonList);
  }
}
