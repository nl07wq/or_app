import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/body_history_models.dart';

class DataCenterHistoryRangeSelection {
  const DataCenterHistoryRangeSelection({
    required this.period,
    this.customRange,
  });

  final BodyHistoryPeriod period;
  final DateTimeRange? customRange;
}

/// Local display preference shared by every DATA CENTER History page.
class DataCenterHistoryRangePreference {
  DataCenterHistoryRangePreference({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const storageKey = 'or_app.data_center.history_range.v1';
  static const _version = 1;

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<DataCenterHistoryRangeSelection> load() async {
    try {
      final preferences = await _preferencesLoader();
      final raw = preferences.getString(storageKey);
      if (raw == null) return _defaultSelection;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _defaultSelection;
      if (decoded['version'] != _version) return _defaultSelection;
      final periodName = decoded['period'];
      if (periodName is! String) return _defaultSelection;
      final period = BodyHistoryPeriod.values.where(
        (value) => value.name == periodName,
      );
      if (period.length != 1) return _defaultSelection;
      final resolvedPeriod = period.single;
      if (resolvedPeriod != BodyHistoryPeriod.custom) {
        return DataCenterHistoryRangeSelection(period: resolvedPeriod);
      }
      final range = _readCustomRange(decoded);
      return range == null
          ? _defaultSelection
          : DataCenterHistoryRangeSelection(
              period: BodyHistoryPeriod.custom,
              customRange: range,
            );
    } catch (_) {
      return _defaultSelection;
    }
  }

  Future<void> save(
    BodyHistoryPeriod period, {
    DateTimeRange? customRange,
  }) async {
    final payload = <String, Object?>{
      'version': _version,
      'period': period.name,
    };
    if (period == BodyHistoryPeriod.custom) {
      if (!_isValidCustomRange(customRange)) return;
      payload['customStart'] = _formatDate(customRange!.start);
      payload['customEnd'] = _formatDate(customRange.end);
    }
    try {
      final preferences = await _preferencesLoader();
      await preferences.setString(storageKey, jsonEncode(payload));
    } catch (_) {
      // A display preference must never affect History availability.
    }
  }

  static const _defaultSelection = DataCenterHistoryRangeSelection(
    period: BodyHistoryPeriod.oneWeek,
  );

  static DateTimeRange? _readCustomRange(Map<dynamic, dynamic> value) {
    final start = _parseDate(value['customStart']);
    final end = _parseDate(value['customEnd']);
    if (start == null || end == null || start.isAfter(end)) return null;
    return DateTimeRange(start: start, end: end);
  }

  static bool _isValidCustomRange(DateTimeRange? range) =>
      range != null && !range.start.isAfter(range.end);

  static DateTime? _parseDate(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || _formatDate(parsed) != value) return null;
    return parsed;
  }

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
