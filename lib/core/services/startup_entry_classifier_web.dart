// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

enum StartupEntryClassification { freshLaunch, shortReentry }

class StartupEntryResult {
  const StartupEntryResult({
    required this.classification,
    required this.markerPresent,
    this.previousPageHideAgeMs,
  });

  final StartupEntryClassification classification;
  final bool markerPresent;
  final int? previousPageHideAgeMs;
}

/// Classifies a user-facing launch independently from an HTML document lifetime.
class StartupEntryClassifier {
  StartupEntryClassifier({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static final StartupEntryClassifier instance = StartupEntryClassifier();

  static const markerStorageKey = 'or_app.startup_reentry_marker.v1';
  static const documentRunStorageKey =
      'or_app.startup_diagnostic.document_run_id';
  static const reentryWindow = Duration(seconds: 20);

  final DateTime Function() _now;
  StartupEntryResult _result = const StartupEntryResult(
    classification: StartupEntryClassification.freshLaunch,
    markerPresent: false,
  );

  StartupEntryResult get result => _result;

  StartupEntryResult classifyAtDocumentStart() {
    try {
      final marker = _readMarker();
      if (marker == null) {
        return _result = const StartupEntryResult(
          classification: StartupEntryClassification.freshLaunch,
          markerPresent: false,
        );
      }
      final age = _now().millisecondsSinceEpoch - marker.pageHideAtMs;
      final isRecent =
          age >= 0 &&
          age <= reentryWindow.inMilliseconds &&
          marker.documentRunId != _currentDocumentRunId();
      return _result = StartupEntryResult(
        classification: isRecent
            ? StartupEntryClassification.shortReentry
            : StartupEntryClassification.freshLaunch,
        markerPresent: true,
        previousPageHideAgeMs: age,
      );
    } catch (_) {
      return _result = const StartupEntryResult(
        classification: StartupEntryClassification.freshLaunch,
        markerPresent: false,
      );
    }
  }

  _StartupReentryMarker? _readMarker() {
    final raw = html.window.localStorage[markerStorageKey];
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final pageHideAtMs = decoded['pageHideAtMs'];
    final documentRunId = decoded['documentRunId'];
    if (pageHideAtMs is! int ||
        documentRunId is! String ||
        documentRunId.isEmpty) {
      return null;
    }
    return _StartupReentryMarker(
      pageHideAtMs: pageHideAtMs,
      documentRunId: documentRunId,
    );
  }

  String _currentDocumentRunId() {
    try {
      return html.window.sessionStorage[documentRunStorageKey] ?? '';
    } catch (_) {
      return '';
    }
  }
}

class _StartupReentryMarker {
  const _StartupReentryMarker({
    required this.pageHideAtMs,
    required this.documentRunId,
  });

  final int pageHideAtMs;
  final String documentRunId;
}
