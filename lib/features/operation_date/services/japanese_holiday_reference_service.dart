import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef HolidayAssetLoader = Future<String> Function();
typedef HolidayPreferencesLoader = Future<SharedPreferences> Function();

enum JapaneseHolidayMatch { holiday, notHoliday, unavailable }

class JapaneseHolidaySnapshot {
  JapaneseHolidaySnapshot({
    required this.dataUpdatedAt,
    required this.coverageFrom,
    required this.coverageTo,
    required Set<String> holidays,
  }) : holidays = Set.unmodifiable(holidays);

  factory JapaneseHolidaySnapshot.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1 ||
        json['source'] != 'cabinet_office_japan' ||
        json['dataUpdatedAt'] is! String ||
        json['coverageFrom'] is! String ||
        json['coverageTo'] is! String ||
        json['holidays'] is! List<Object?>) {
      throw const FormatException('Invalid Japanese holiday snapshot');
    }
    final updatedAt = DateTime.tryParse(json['dataUpdatedAt']! as String);
    final coverageFrom = json['coverageFrom']! as String;
    final coverageTo = json['coverageTo']! as String;
    final holidays = <String>{};
    for (final value in json['holidays']! as List<Object?>) {
      if (value is! String || !_isDate(value) || !holidays.add(value)) {
        throw const FormatException('Invalid Japanese holiday date');
      }
    }
    if (updatedAt == null ||
        !_isDate(coverageFrom) ||
        !_isDate(coverageTo) ||
        holidays.isEmpty ||
        coverageFrom.compareTo(coverageTo) > 0 ||
        holidays.any(
          (date) =>
              date.compareTo(coverageFrom) < 0 ||
              date.compareTo(coverageTo) > 0,
        )) {
      throw const FormatException('Invalid Japanese holiday coverage');
    }
    return JapaneseHolidaySnapshot(
      dataUpdatedAt: updatedAt.toUtc(),
      coverageFrom: coverageFrom,
      coverageTo: coverageTo,
      holidays: holidays,
    );
  }

  final DateTime dataUpdatedAt;
  final String coverageFrom;
  final String coverageTo;
  final Set<String> holidays;

  JapaneseHolidayMatch classify(String operationDate) {
    if (!_isDate(operationDate) ||
        operationDate.compareTo(coverageFrom) < 0 ||
        operationDate.compareTo(coverageTo) > 0) {
      return JapaneseHolidayMatch.unavailable;
    }
    return holidays.contains(operationDate)
        ? JapaneseHolidayMatch.holiday
        : JapaneseHolidayMatch.notHoliday;
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'source': 'cabinet_office_japan',
    'dataUpdatedAt': dataUpdatedAt.toIso8601String(),
    'coverageFrom': coverageFrom,
    'coverageTo': coverageTo,
    'holidays': holidays.toList()..sort(),
  };

  static bool _isDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    return parsed != null && parsed.toIso8601String().startsWith(value);
  }
}

class JapaneseHolidayDataStatus {
  const JapaneseHolidayDataStatus({
    required this.snapshot,
    required this.localUpdatedAt,
    required this.updateSucceeded,
  });

  final JapaneseHolidaySnapshot? snapshot;
  final DateTime? localUpdatedAt;
  final bool updateSucceeded;

  bool get isAvailable => snapshot != null;
}

class JapaneseHolidayReferenceService {
  JapaneseHolidayReferenceService({
    HolidayAssetLoader? assetLoader,
    HolidayPreferencesLoader? preferencesLoader,
    DateTime Function()? clock,
  }) : _assetLoader = assetLoader ?? _loadDistributedAsset,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now;

  static const cacheKey = 'presentation_japanese_holiday_cache_v1';
  static final cacheRevision = ValueNotifier<int>(0);
  static final instance = JapaneseHolidayReferenceService();

  final HolidayAssetLoader _assetLoader;
  final HolidayPreferencesLoader _preferencesLoader;
  final DateTime Function() _clock;
  JapaneseHolidaySnapshot? _currentSnapshot;

  JapaneseHolidayMatch classifyCached(String operationDate) =>
      _currentSnapshot?.classify(operationDate) ??
      JapaneseHolidayMatch.unavailable;

  Future<JapaneseHolidayDataStatus> load() async {
    try {
      final preferences = await _preferencesLoader();
      final cached = _readCache(preferences);
      if (cached != null) {
        _currentSnapshot = cached.snapshot;
        return cached;
      }
    } catch (_) {
      // The distributed asset remains the only fallback when cache is absent.
    }
    return update();
  }

  Future<JapaneseHolidayDataStatus> update() async {
    JapaneseHolidayDataStatus? existing;
    try {
      final preferences = await _preferencesLoader();
      existing = _readCache(preferences);
      final decoded = jsonDecode(await _assetLoader());
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Holiday asset must be an object');
      }
      final snapshot = JapaneseHolidaySnapshot.fromJson(decoded);
      final localUpdatedAt = _clock().toUtc();
      final saved = await preferences.setString(
        cacheKey,
        jsonEncode({
          'snapshot': snapshot.toJson(),
          'localUpdatedAt': localUpdatedAt.toIso8601String(),
        }),
      );
      if (!saved) throw StateError('Holiday cache could not be saved');
      _currentSnapshot = snapshot;
      cacheRevision.value++;
      return JapaneseHolidayDataStatus(
        snapshot: snapshot,
        localUpdatedAt: localUpdatedAt,
        updateSucceeded: true,
      );
    } catch (_) {
      _currentSnapshot = existing?.snapshot;
      return JapaneseHolidayDataStatus(
        snapshot: existing?.snapshot,
        localUpdatedAt: existing?.localUpdatedAt,
        updateSucceeded: false,
      );
    }
  }

  JapaneseHolidayDataStatus? _readCache(SharedPreferences preferences) {
    final raw = preferences.getString(cacheKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?> ||
          decoded['snapshot'] is! Map<String, Object?> ||
          decoded['localUpdatedAt'] is! String) {
        return null;
      }
      final localUpdatedAt = DateTime.tryParse(
        decoded['localUpdatedAt']! as String,
      );
      if (localUpdatedAt == null) return null;
      return JapaneseHolidayDataStatus(
        snapshot: JapaneseHolidaySnapshot.fromJson(
          decoded['snapshot']! as Map<String, Object?>,
        ),
        localUpdatedAt: localUpdatedAt.toUtc(),
        updateSucceeded: true,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> _loadDistributedAsset() =>
      NetworkAssetBundle(Uri.base).loadString('data/japanese_holidays.json');
}
