// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class BootPresentationSession {
  static const _storageKey = 'or_app.initial_boot_presentation_claimed.v1';
  static bool _memoryClaimed = false;

  bool claimInitialBootPresentation() {
    if (_memoryClaimed) return false;
    try {
      final storage = html.window.sessionStorage;
      if (storage[_storageKey] == 'true') {
        _memoryClaimed = true;
        return false;
      }
      storage[_storageKey] = 'true';
    } catch (_) {
      // Keep the same isolate safe even if browser storage is unavailable.
    }
    _memoryClaimed = true;
    return true;
  }
}
