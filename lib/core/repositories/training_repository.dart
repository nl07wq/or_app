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

  static Future<void> replaceForLocalDate(TrainingSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final existingSessions = await getAll();
    final targetDate = _localDate(session.date);
    final updatedSessions = <TrainingSession>[];
    var replaced = false;

    for (final existingSession in existingSessions) {
      if (_localDate(existingSession.date) != targetDate) {
        updatedSessions.add(existingSession);
        continue;
      }

      if (!replaced) {
        updatedSessions.add(session);
        replaced = true;
      }
    }

    if (!replaced) {
      updatedSessions.add(session);
    }

    final jsonList = updatedSessions
        .map((entry) => jsonEncode(entry.toJson()))
        .toList();

    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<TrainingSession>> getAll() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final jsonList = prefs.getStringList(_key) ?? [];

      final sessions = jsonList
          .map((e) => TrainingSession.fromJson(jsonDecode(e)))
          .toList();
      sessions.sort(
        (first, second) => DateTime.parse(
          second.date,
        ).compareTo(DateTime.parse(first.date)),
      );

      return sessions;
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

  static String _localDate(String value) {
    final date = DateTime.parse(value).toLocal();

    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
