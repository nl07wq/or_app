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

/// Non-Web fallback and deterministic test implementation.
class StartupEntryClassifier {
  StartupEntryClassifier({
    DateTime Function()? now,
    this.documentRunId = 'non-web-document',
  }) : _now = now ?? DateTime.now;

  static final StartupEntryClassifier instance = StartupEntryClassifier();

  static const reentryWindow = Duration(seconds: 20);

  final DateTime Function() _now;
  final String documentRunId;
  DateTime? _pageHideAt;
  String? _pageHideDocumentRunId;
  StartupEntryResult _result = const StartupEntryResult(
    classification: StartupEntryClassification.freshLaunch,
    markerPresent: false,
  );

  StartupEntryResult get result => _result;

  StartupEntryResult classifyAtDocumentStart() {
    final pageHideAt = _pageHideAt;
    final markerPresent = pageHideAt != null;
    final age = pageHideAt == null
        ? null
        : _now().difference(pageHideAt).inMilliseconds;
    final isRecent =
        age != null &&
        age >= 0 &&
        age <= reentryWindow.inMilliseconds &&
        _pageHideDocumentRunId != documentRunId;
    return _result = StartupEntryResult(
      classification: isRecent
          ? StartupEntryClassification.shortReentry
          : StartupEntryClassification.freshLaunch,
      markerPresent: markerPresent,
      previousPageHideAgeMs: age,
    );
  }

  void recordPageHideForTesting({
    required DateTime occurredAt,
    required String previousDocumentRunId,
  }) {
    _pageHideAt = occurredAt;
    _pageHideDocumentRunId = previousDocumentRunId;
  }
}
