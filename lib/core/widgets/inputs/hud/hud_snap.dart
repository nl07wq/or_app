class HUDSnap {
  double _remainder = 0;

  void reset() {
    _remainder = 0;
  }

  double apply({
    required double delta,
    double sensitivity = 0.02,
    double notch = 12,
    double valueStep = 0.1,
  }) {
    _remainder += delta.abs();

    if (_remainder < notch) {
      return 0;
    }

    final direction = delta < 0 ? 1.0 : -1.0;

    double value = 0;

    while (_remainder >= notch) {
      _remainder -= notch;
      value += valueStep;
    }

    return direction * value;
  }
}
