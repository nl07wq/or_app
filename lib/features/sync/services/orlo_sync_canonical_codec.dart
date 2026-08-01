import 'dart:convert';

abstract final class OrloSyncCanonicalCodec {
  static String encode(Object? value) => jsonEncode(canonicalize(value));

  static String digest(Object? value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(encode(value))) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Object? canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return <String, Object?>{
        for (final entry in entries)
          entry.key.toString(): canonicalize(entry.value),
      };
    }
    if (value is Iterable) {
      return [for (final item in value) canonicalize(item)];
    }
    return value;
  }
}
