import 'dart:convert';
import 'dart:math';

import '../services/exercise_name_localization.dart';

typedef CustomTrainingExerciseRandomInt = int Function(int max);

class CustomTrainingExerciseIdGenerator {
  final CustomTrainingExerciseRandomInt _nextInt;

  CustomTrainingExerciseIdGenerator({CustomTrainingExerciseRandomInt? nextInt})
    : _nextInt = nextInt ?? Random.secure().nextInt;

  String generate() {
    final bytes = List<int>.generate(16, (_) {
      final value = _nextInt(256);
      if (value < 0 || value > 255) {
        throw StateError(
          'Custom Training Exercise UUID byte is outside the valid range.',
        );
      }
      return value;
    });
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'custom-exercise:${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

class CustomTrainingExerciseLegacyIdGenerator {
  const CustomTrainingExerciseLegacyIdGenerator();

  String generate(String name) {
    final normalizedName = exerciseIdentityKey(name);
    if (normalizedName.isEmpty) {
      throw const FormatException(
        'Custom Training Exercise name cannot be empty.',
      );
    }
    return 'legacy-custom-exercise:${fnv1aDigest(normalizedName)}';
  }

  static String fnv1aDigest(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
