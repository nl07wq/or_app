// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'startup_entry_classifier.dart';

class BootPresentationSession {
  BootPresentationSession({StartupEntryClassifier? startupEntryClassifier})
    : _startupEntryClassifier =
          startupEntryClassifier ?? StartupEntryClassifier.instance;

  static const _storageKey = 'or_app.initial_boot_presentation_claimed.v1';
  static bool _memoryClaimed = false;
  final StartupEntryClassifier _startupEntryClassifier;
  String _lastClaimReason = 'not_claimed';

  String get lastClaimReason => _lastClaimReason;

  bool claimInitialBootPresentation() {
    if (_startupEntryClassifier.result.classification ==
        StartupEntryClassification.shortReentry) {
      _lastClaimReason = 'shortReentry';
      return false;
    }
    if (_memoryClaimed) {
      _lastClaimReason = 'memoryClaimed';
      return false;
    }
    try {
      final storage = html.window.sessionStorage;
      if (storage[_storageKey] == 'true') {
        _memoryClaimed = true;
        _lastClaimReason = 'sessionStorageClaimed';
        return false;
      }
      storage[_storageKey] = 'true';
    } catch (_) {
      // Keep the same isolate safe even if browser storage is unavailable.
    }
    _memoryClaimed = true;
    _lastClaimReason = 'freshLaunch';
    return true;
  }
}
