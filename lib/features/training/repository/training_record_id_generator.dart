import 'dart:convert';
import 'dart:math';

typedef TrainingRandomInt = int Function(int max);

class TrainingRecordIdGenerator {
  final TrainingRandomInt _nextInt;

  TrainingRecordIdGenerator({TrainingRandomInt? nextInt})
    : _nextInt = nextInt ?? Random.secure().nextInt;

  String generate() {
    final bytes = List<int>.generate(16, (_) {
      final value = _nextInt(256);
      if (value < 0 || value > 255) {
        throw StateError('TRAINING UUID byte is outside the valid range.');
      }
      return value;
    });
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'training:${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

class TrainingLegacyIdGenerator {
  const TrainingLegacyIdGenerator();

  String generate({
    required Map<String, dynamic> sessionJson,
    required int sourceIndex,
    required int duplicateOrdinal,
  }) {
    if (sourceIndex < 0 || duplicateOrdinal < 0 || duplicateOrdinal > 9999) {
      throw ArgumentError('Invalid TRAINING Legacy ID input.');
    }
    final canonical = canonicalJson(sessionJson);
    final digest = fnv1aDigest('$canonical\u0000$sourceIndex');
    return 'legacy-training:$digest:'
        '${duplicateOrdinal.toString().padLeft(4, '0')}';
  }

  static String canonicalJson(Object? value) => jsonEncode(_canonical(value));

  static String fnv1aDigest(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonical(value[key]),
      };
    }
    if (value is Iterable) {
      return <Object?>[for (final item in value) _canonical(item)];
    }
    return value;
  }
}
