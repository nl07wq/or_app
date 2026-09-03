import 'active_session_heartbeat.dart';

class BootPresentationSession {
  BootPresentationSession({ActiveSessionHeartbeat? activeSessionHeartbeat})
    : _activeSessionHeartbeat =
          activeSessionHeartbeat ?? ActiveSessionHeartbeat.instance;

  bool _initialBootClaimed = false;
  final ActiveSessionHeartbeat _activeSessionHeartbeat;
  String _lastClaimReason = 'not_claimed';

  String get lastClaimReason => _lastClaimReason;

  bool claimInitialBootPresentation() {
    if (_activeSessionHeartbeat.result.classification ==
        ActiveSessionClassification.activeSessionReentry) {
      _lastClaimReason = 'activeSessionReentry';
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
