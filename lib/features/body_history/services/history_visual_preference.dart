import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A display-only preference for the DATA CENTER history index.
///
/// This stays deliberately independent of history records so visual
/// comparison can never affect the source data or its availability.
enum HistoryTitleVariant { archiveDisplay, archivePlate, memoryModule }

enum HistoryAmbientVariant { chronoArchive, dataVault, memoryStream }

class HistoryVisualSelection {
  const HistoryVisualSelection({required this.title, required this.ambient});

  const HistoryVisualSelection.defaults()
    : title = HistoryTitleVariant.archiveDisplay,
      ambient = HistoryAmbientVariant.chronoArchive;

  final HistoryTitleVariant title;
  final HistoryAmbientVariant ambient;

  HistoryVisualSelection copyWith({
    HistoryTitleVariant? title,
    HistoryAmbientVariant? ambient,
  }) => HistoryVisualSelection(
    title: title ?? this.title,
    ambient: ambient ?? this.ambient,
  );

  @override
  bool operator ==(Object other) =>
      other is HistoryVisualSelection &&
      other.title == title &&
      other.ambient == ambient;

  @override
  int get hashCode => Object.hash(title, ambient);
}

class HistoryVisualPreference {
  HistoryVisualPreference({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const storageKey = 'or_app.data_center.history_visual.v1';
  static const _version = 1;

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<HistoryVisualSelection> load() async {
    try {
      final preferences = await _preferencesLoader();
      final raw = preferences.getString(storageKey);
      if (raw == null) return const HistoryVisualSelection.defaults();
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['version'] != _version) {
        return const HistoryVisualSelection.defaults();
      }
      final title = _titleFromName(decoded['title']);
      final ambient = _ambientFromName(decoded['ambient']);
      return title == null || ambient == null
          ? const HistoryVisualSelection.defaults()
          : HistoryVisualSelection(title: title, ambient: ambient);
    } catch (_) {
      return const HistoryVisualSelection.defaults();
    }
  }

  Future<void> save(HistoryVisualSelection selection) async {
    try {
      final preferences = await _preferencesLoader();
      await preferences.setString(
        storageKey,
        jsonEncode({
          'version': _version,
          'title': selection.title.name,
          'ambient': selection.ambient.name,
        }),
      );
    } catch (_) {
      // History remains available when local display settings cannot persist.
    }
  }

  static HistoryTitleVariant? _titleFromName(Object? value) {
    if (value is! String) return null;
    for (final variant in HistoryTitleVariant.values) {
      if (variant.name == value) return variant;
    }
    return null;
  }

  static HistoryAmbientVariant? _ambientFromName(Object? value) {
    if (value is! String) return null;
    for (final variant in HistoryAmbientVariant.values) {
      if (variant.name == value) return variant;
    }
    return null;
  }
}
