import 'dart:convert';

class OrloSyncParseException implements Exception {
  const OrloSyncParseException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class OrloSyncParser {
  const OrloSyncParser({this.maximumUtf8Bytes = 1024 * 1024});

  final int maximumUtf8Bytes;

  Map<String, Object?> parse(String rawText) {
    if (rawText.trim().isEmpty) {
      throw const OrloSyncParseException('emptyInput', '入力が空です。');
    }
    if (utf8.encode(rawText).length > maximumUtf8Bytes) {
      throw const OrloSyncParseException('inputTooLarge', '入力サイズが上限を超えています。');
    }
    final source = _stripJsonFence(rawText.trim());
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const OrloSyncParseException(
        'invalidJson',
        '有効なJSON Objectではありません。',
      );
    }
    if (decoded is! Map) {
      throw const OrloSyncParseException(
        'invalidTopLevel',
        'Top-levelはJSON Objectである必要があります。',
      );
    }
    return Map<String, Object?>.from(decoded);
  }

  static String _stripJsonFence(String value) {
    final match = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1) ?? value;
  }
}
