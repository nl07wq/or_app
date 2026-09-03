class BootPresentationSession {
  bool _initialBootClaimed = false;

  bool claimInitialBootPresentation() {
    if (_initialBootClaimed) return false;
    _initialBootClaimed = true;
    return true;
  }
}
