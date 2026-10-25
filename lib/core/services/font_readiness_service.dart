import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum FontReadinessState { loading, ready, failed }

/// Loads locally bundled Japanese faces once.  It deliberately has no timer:
/// readiness is the completion of the real asset load, and failure remains
/// retryable instead of holding the application in an endless splash state.
class FontReadinessService extends ChangeNotifier {
  FontReadinessService._();
  static final FontReadinessService instance = FontReadinessService._();
  FontReadinessState _state = FontReadinessState.loading;
  Object? _error;
  Future<void>? _future;
  FontReadinessState get state => _state;
  Object? get error => _error;
  bool get isReady => _state == FontReadinessState.ready;

  Future<void> ensureReady() => _future ??= _load();
  Future<void> retry() {
    _future = null;
    _state = FontReadinessState.loading;
    _error = null;
    notifyListeners();
    return ensureReady();
  }

  Future<void> _load() async {
    try {
      final regular = FontLoader('KleeOne')
        ..addFont(rootBundle.load('assets/fonts/KleeOne-Regular.ttf'));
      final semiBold = FontLoader('KleeOne')
        ..addFont(rootBundle.load('assets/fonts/KleeOne-SemiBold.ttf'));
      await Future.wait([regular.load(), semiBold.load()]);
      // The assets are bundled and registered in pubspec.  This verifies the
      // load boundary; actual browser glyph fallback cannot be inferred from a
      // duration, so callers only proceed after this future succeeds.
      _state = FontReadinessState.ready;
    } catch (error) {
      _error = error;
      _state = FontReadinessState.failed;
    }
    notifyListeners();
  }
}
