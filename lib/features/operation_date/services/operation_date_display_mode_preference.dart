import 'package:shared_preferences/shared_preferences.dart';

/// Dashboard-only presentation choice. It is deliberately local UI state, not
/// part of the canonical Operation Date or any Formal record.
enum OperationDateDisplayMode { flip, nixie }

class OperationDateDisplayModePreference {
  OperationDateDisplayModePreference({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const storageKey = 'or_app.dashboard.operation_date_display_mode.v1';

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<OperationDateDisplayMode> load() async {
    try {
      final value = (await _preferencesLoader()).getString(storageKey);
      return OperationDateDisplayMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => OperationDateDisplayMode.flip,
      );
    } catch (_) {
      return OperationDateDisplayMode.flip;
    }
  }

  Future<void> save(OperationDateDisplayMode mode) async {
    try {
      await (await _preferencesLoader()).setString(storageKey, mode.name);
    } catch (_) {
      // A display preference must never affect Dashboard availability.
    }
  }
}
