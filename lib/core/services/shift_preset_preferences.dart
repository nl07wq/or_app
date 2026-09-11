import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/shift_preset.dart';

class ShiftPresetPreferences {
  ShiftPresetPreferences._();

  static const _key = 'shift_presets_v1';
  static const maxPresets = 4;

  static const defaults = [
    ShiftPreset(
      id: 'shift_early',
      name: '早番',
      startTime: '07:00',
      endTime: '18:00',
      breakTime: '01:00',
      order: 0,
    ),
    ShiftPreset(
      id: 'shift_middle',
      name: '中番',
      startTime: '11:00',
      endTime: '18:00',
      breakTime: '01:00',
      order: 1,
    ),
    ShiftPreset(
      id: 'shift_late',
      name: '遅番',
      startTime: '15:15',
      endTime: '00:15',
      breakTime: '01:00',
      order: 2,
    ),
  ];

  static Future<List<ShiftPreset>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return List.of(defaults);

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final presets =
          decoded
              .map(
                (value) => ShiftPreset.fromJson(value as Map<String, dynamic>),
              )
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      return _isValid(presets) ? presets : List.of(defaults);
    } catch (_) {
      return List.of(defaults);
    }
  }

  static Future<void> save(List<ShiftPreset> values) async {
    if (!_isValid(values)) {
      throw ArgumentError('Invalid shift preset preferences');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(values.map((value) => value.toJson()).toList()),
    );
  }

  static bool isValidTime(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  static bool isValidEditablePreset({
    required String name,
    required String startTime,
    required String endTime,
    required Iterable<ShiftPreset> existing,
    String? editingId,
  }) {
    final trimmedName = name.trim();
    return trimmedName.isNotEmpty &&
        trimmedName.length <= 24 &&
        isValidTime(startTime) &&
        isValidTime(endTime) &&
        startTime != endTime &&
        !existing.any(
          (preset) =>
              preset.id != editingId &&
              preset.name.toLowerCase() == trimmedName.toLowerCase(),
        );
  }

  static bool _isValid(List<ShiftPreset> values) {
    if (values.length > maxPresets) return false;
    final ids = <String>{};
    final names = <String>{};
    for (final preset in values) {
      if (preset.id.isEmpty ||
          !ids.add(preset.id) ||
          preset.name.trim().isEmpty ||
          preset.name.trim().length > 24 ||
          !names.add(preset.name.trim().toLowerCase()) ||
          !isValidTime(preset.startTime) ||
          !isValidTime(preset.endTime) ||
          !isValidTime(preset.breakTime) ||
          preset.startTime == preset.endTime ||
          preset.order < 0) {
        return false;
      }
    }
    return true;
  }
}
