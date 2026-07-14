class HUDSnap {
  const HUDSnap._();

  static double _remainder = 0;

  static double apply({
    required double delta,
    double sensitivity = 0.02,
    double step = 0.1,
  }) {
    _remainder += delta * sensitivity;

    if (_remainder.abs() < step) {
      return 0;
    }

    final direction = _remainder > 0 ? 1 : -1;

    _remainder -= direction * step;

    return direction * step;
  }

  static void reset() {
    _remainder = 0;
  }
}
