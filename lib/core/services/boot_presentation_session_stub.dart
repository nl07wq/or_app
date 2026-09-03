import 'startup_entry_classifier.dart';

class BootPresentationSession {
  BootPresentationSession({StartupEntryClassifier? startupEntryClassifier})
    : _startupEntryClassifier =
          startupEntryClassifier ?? StartupEntryClassifier.instance;

  bool _initialBootClaimed = false;
  final StartupEntryClassifier _startupEntryClassifier;
  String _lastClaimReason = 'not_claimed';

  String get lastClaimReason => _lastClaimReason;

  bool claimInitialBootPresentation() {
    if (_startupEntryClassifier.result.classification ==
        StartupEntryClassification.shortReentry) {
      _lastClaimReason = 'shortReentry';
      return false;
    }
    if (_initialBootClaimed) {
      _lastClaimReason = 'memoryClaimed';
      return false;
    }
    _initialBootClaimed = true;
    _lastClaimReason = 'freshLaunch';
    return true;
  }
}
