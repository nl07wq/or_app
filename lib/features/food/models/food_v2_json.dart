void rejectUnknownFields(
  Map<String, Object?> json,
  Set<String> allowed,
  String context,
) {
  final unknown = json.keys.where((key) => !allowed.contains(key)).toList();
  if (unknown.isNotEmpty) {
    throw FormatException('Unknown $context field: ${unknown.first}.');
  }
}

Object? requireField(Map<String, Object?> json, String key, String context) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing $context field: $key.');
  }
  return json[key];
}

String requireString(Map<String, Object?> json, String key, String context) {
  final value = requireField(json, key, context);
  if (value is! String) throw FormatException('Invalid $context $key.');
  return value;
}

String? requireNullableString(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final value = requireField(json, key, context);
  if (value != null && value is! String) {
    throw FormatException('Invalid $context $key.');
  }
  return value as String?;
}

double requireNumber(Map<String, Object?> json, String key, String context) {
  final value = requireField(json, key, context);
  if (value is! num) throw FormatException('Invalid $context $key.');
  return value.toDouble();
}

double? requireNullableNumber(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final value = requireField(json, key, context);
  if (value != null && value is! num) {
    throw FormatException('Invalid $context $key.');
  }
  return (value as num?)?.toDouble();
}

int requireInt(Map<String, Object?> json, String key, String context) {
  final value = requireField(json, key, context);
  if (value is! int) throw FormatException('Invalid $context $key.');
  return value;
}

bool requireBool(Map<String, Object?> json, String key, String context) {
  final value = requireField(json, key, context);
  if (value is! bool) throw FormatException('Invalid $context $key.');
  return value;
}

Map<String, Object?> requireMap(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final value = requireField(json, key, context);
  if (value is! Map) throw FormatException('Invalid $context $key.');
  return Map<String, Object?>.from(value);
}

List<Object?> requireList(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final value = requireField(json, key, context);
  if (value is! List) throw FormatException('Invalid $context $key.');
  return List<Object?>.from(value);
}

DateTime requireUtcDateTime(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final source = requireString(json, key, context);
  final value = DateTime.tryParse(source);
  if (value == null || !value.isUtc || value.toIso8601String() != source) {
    throw FormatException('Invalid $context $key.');
  }
  return value;
}

void validateStableId(String value, String name) {
  final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  if (value.trim() != value || !uuid.hasMatch(value)) {
    throw ArgumentError.value(value, name, '$name must be a stable ID.');
  }
}

void validateRequiredText(String value, String name) {
  if (value.isEmpty || value.trim() != value) {
    throw ArgumentError.value(
      value,
      name,
      '$name must be trimmed and non-empty.',
    );
  }
}

void validateTimestamps(DateTime createdAt, DateTime updatedAt) {
  if (!createdAt.isUtc || !updatedAt.isUtc || updatedAt.isBefore(createdAt)) {
    throw ArgumentError('FOOD timestamps must be UTC and ordered.');
  }
}

void validateLocalDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) throw ArgumentError.value(value, 'localDate');
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw ArgumentError.value(value, 'localDate');
  }
}
