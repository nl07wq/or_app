import 'dart:math';

typedef FoodRandomInt = int Function(int max);

class FoodMealIdGenerator {
  FoodMealIdGenerator({FoodRandomInt? nextInt})
    : _nextInt = nextInt ?? Random.secure().nextInt;

  final FoodRandomInt _nextInt;

  String generate() {
    final bytes = List<int>.generate(16, (_) {
      final value = _nextInt(256);
      if (value < 0 || value > 255) {
        throw StateError('FOOD UUID byte is outside the valid range.');
      }
      return value;
    });
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'food:${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
