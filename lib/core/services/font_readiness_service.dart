import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum FontReadinessState { loading, ready, failed }

/// Loads locally bundled Japanese faces once.  It deliberately has no timer:
/// readiness is the completion of the real asset load, and failure remains
/// retryable instead of holding the application in an endless splash state.
class FontReadinessService extends ChangeNotifier {
  FontReadinessService._([Future<void> Function()? loadFaces])
    : _loadFaces = loadFaces ?? _loadConfiguredFaces;
  static final FontReadinessService instance = FontReadinessService._();

  /// Kept public so tests and asset audits use exactly the face that the
  /// application theme selects. This is a bundled font, never a CDN request.
  static const fontFamily = 'MPlus1Code';
  static const fontAsset = 'assets/fonts/MPLUS1Code[wght].ttf';

  /// A narrowly-scoped seam for deterministic readiness/retry tests. The app
  /// always uses [_loadConfiguredFaces].
  @visibleForTesting
  FontReadinessService.withLoaderForTesting(this._loadFaces);

  final Future<void> Function() _loadFaces;
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
      await _loadFaces();
      // The asset is bundled and registered in pubspec. This verifies the
      // actual load boundary; it deliberately never substitutes a timer for
      // font readiness. Platform fallback still handles symbols outside this
      // font's cmap without reviving KleeOne as a user-visible fallback.
      _state = FontReadinessState.ready;
    } catch (error) {
      _error = error;
      _state = FontReadinessState.failed;
    }
    notifyListeners();
  }

  static Future<void> _loadConfiguredFaces() async {
    final font = FontLoader(fontFamily)..addFont(rootBundle.load(fontAsset));
    await font.load();
  }
}
