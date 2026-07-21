import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_log_confirmation.dart';

class DailyLogConfirmationRepository {
  static const _key = 'daily_log_confirmations';

  static Future<void> save(DailyLogConfirmation confirmation) async {
    final records = await getAll();
    records.removeWhere((record) => _sameDate(record.date, confirmation.date));
    records.add(confirmation);
    await _write(records);
  }

  static Future<DailyLogConfirmation?> findByDate(DateTime date) async {
    for (final record in await getAll()) {
      if (_sameDate(record.date, date)) return record;
    }
    return null;
  }

  static Future<List<DailyLogConfirmation>> getAll() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final records = (preferences.getStringList(_key) ?? [])
          .map((value) => DailyLogConfirmation.fromJson(jsonDecode(value)))
          .toList();
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    } catch (_) {
      return [];
    }
  }

  static Future<void> deleteByDate(DateTime date) async {
    final records = await getAll();
    records.removeWhere((record) => _sameDate(record.date, date));
    await _write(records);
  }

  static Future<void> _write(List<DailyLogConfirmation> records) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      records.map((record) => jsonEncode(record.toJson())).toList(),
    );
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
