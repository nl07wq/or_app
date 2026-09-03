// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'active_session_heartbeat.dart';

class BootPresentationSession {
  BootPresentationSession({ActiveSessionHeartbeat? activeSessionHeartbeat})
    : _activeSessionHeartbeat =
          activeSessionHeartbeat ?? ActiveSessionHeartbeat.instance;

  static const _storageKey = 'or_app.initial_boot_presentation_claimed.v1';
  static bool _memoryClaimed = false;
  final ActiveSessionHeartbeat _activeSessionHeartbeat;
  String _lastClaimReason = 'not_claimed';

  String get lastClaimReason => _lastClaimReason;

  bool claimInitialBootPresentation() {
    if (_activeSessionHeartbeat.result.classification ==
        ActiveSessionClassification.activeSessionReentry) {
      _lastClaimReason = 'activeSessionReentry';
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
