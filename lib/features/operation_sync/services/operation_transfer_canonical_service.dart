import 'dart:convert';

import '../models/operation_transfer_package.dart';

abstract final class OperationTransferCanonicalService {
  static String encode(Object? value) => jsonEncode(canonicalize(value));

  static String digest(Object? value) => sha256Hex(utf8.encode(encode(value)));

  static String recordDigest(OperationTransferRecord record) {
    return digest(record.digestPayload());
  }

  static String sectionDigest(OperationTransferSection section) {
    return digest(section.digestPayload());
  }

  static String packageDigest(OperationTransferPackage package) {
    return digest(package.digestPayload());
  }

  static Object? canonicalize(Object? value) {
    if (value == null || value is bool || value is String) return value;
    if (value is num) {
      if (value is double && (!value.isFinite || value.isNaN)) {
        throw const FormatException('Canonical JSON requires finite numbers.');
      }
      return value;
    }
    if (value is List) {
      return [for (final item in value) canonicalize(item)];
    }
    if (value is Map) {
      final keys = value.keys.map((key) {
        if (key is! String) {
          throw const FormatException('Canonical JSON keys must be strings.');
        }
        return key;
      }).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: canonicalize(value[key]),
      };
    }
    throw FormatException(
      'Unsupported canonical JSON value: ${value.runtimeType}.',
    );
  }

  static String canonicalTimestamp(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  static String sha256Hex(List<int> input) {
    final bytes = List<int>.from(input);
    final bitLength = bytes.length * 8;
    bytes.add(0x80);
    while (bytes.length % 64 != 56) {
      bytes.add(0);
    }
    for (var shift = 56; shift >= 0; shift -= 8) {
      bytes.add((bitLength >> shift) & 0xff);
    }

    final hash = <int>[
      0x6a09e667,
      0xbb67ae85,
      0x3c6ef372,
      0xa54ff53a,
      0x510e527f,
      0x9b05688c,
      0x1f83d9ab,
      0x5be0cd19,
    ];
    final words = List<int>.filled(64, 0);
    for (var offset = 0; offset < bytes.length; offset += 64) {
      for (var index = 0; index < 16; index++) {
        final start = offset + index * 4;
        words[index] =
            (bytes[start] << 24) |
            (bytes[start + 1] << 16) |
            (bytes[start + 2] << 8) |
            bytes[start + 3];
      }
      for (var index = 16; index < 64; index++) {
        final s0 =
            _rotateRight(words[index - 15], 7) ^
            _rotateRight(words[index - 15], 18) ^
            (words[index - 15] >>> 3);
        final s1 =
            _rotateRight(words[index - 2], 17) ^
            _rotateRight(words[index - 2], 19) ^
            (words[index - 2] >>> 10);
        words[index] =
            (words[index - 16] + s0 + words[index - 7] + s1) & _mask32;
      }

      var a = hash[0];
      var b = hash[1];
      var c = hash[2];
      var d = hash[3];
      var e = hash[4];
      var f = hash[5];
      var g = hash[6];
      var h = hash[7];
      for (var index = 0; index < 64; index++) {
        final sum1 =
            _rotateRight(e, 6) ^ _rotateRight(e, 11) ^ _rotateRight(e, 25);
        final choose = (e & f) ^ ((~e) & g);
        final temp1 =
            (h + sum1 + choose + _roundConstants[index] + words[index]) &
            _mask32;
        final sum0 =
            _rotateRight(a, 2) ^ _rotateRight(a, 13) ^ _rotateRight(a, 22);
        final majority = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (sum0 + majority) & _mask32;
        h = g;
        g = f;
        f = e;
        e = (d + temp1) & _mask32;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & _mask32;
      }
      hash[0] = (hash[0] + a) & _mask32;
      hash[1] = (hash[1] + b) & _mask32;
      hash[2] = (hash[2] + c) & _mask32;
      hash[3] = (hash[3] + d) & _mask32;
      hash[4] = (hash[4] + e) & _mask32;
      hash[5] = (hash[5] + f) & _mask32;
      hash[6] = (hash[6] + g) & _mask32;
      hash[7] = (hash[7] + h) & _mask32;
    }
    return hash.map((value) => value.toRadixString(16).padLeft(8, '0')).join();
  }

  static int _rotateRight(int value, int count) {
    return ((value >>> count) | (value << (32 - count))) & _mask32;
  }

  static const _mask32 = 0xffffffff;
  static const _roundConstants = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
}
