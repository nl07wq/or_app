import 'food_v2_json.dart';

enum FoodProvenanceSourceType {
  manufacturerLabel,
  manufacturerWebsite,
  publicDatabase,
  recipeCalculation,
  userInput,
  chatGptEstimate,
  migration,
  unknown;

  String get stableId => name;

  static FoodProvenanceSourceType fromStableId(String value) {
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown FOOD provenance source: $value.');
    }
  }
}

class FoodDataProvenance {
  static const _fields = {
    'sourceType',
    'sourceName',
    'sourceReference',
    'capturedAt',
    'sourceUpdatedAt',
    'notes',
  };

  final FoodProvenanceSourceType sourceType;
  final String? sourceName;
  final String? sourceReference;
  final DateTime capturedAt;
  final DateTime? sourceUpdatedAt;
  final String? notes;

  FoodDataProvenance({
    required this.sourceType,
    this.sourceName,
    this.sourceReference,
    required this.capturedAt,
    this.sourceUpdatedAt,
    this.notes,
  }) {
    if (!capturedAt.isUtc || sourceUpdatedAt?.isUtc == false) {
      throw ArgumentError('FOOD provenance timestamps must be UTC.');
    }
  }

  Map<String, Object?> toJson() => {
    'sourceType': sourceType.stableId,
    'sourceName': sourceName,
    'sourceReference': sourceReference,
    'capturedAt': capturedAt.toIso8601String(),
    'sourceUpdatedAt': sourceUpdatedAt?.toIso8601String(),
    'notes': notes,
  };

  factory FoodDataProvenance.fromJson(Map<String, Object?> json) {
    rejectUnknownFields(json, _fields, 'FOOD provenance');
    final sourceType = requireString(json, 'sourceType', 'FOOD provenance');
    final sourceUpdatedAt = requireNullableString(
      json,
      'sourceUpdatedAt',
      'FOOD provenance',
    );
    return FoodDataProvenance(
      sourceType: FoodProvenanceSourceType.fromStableId(sourceType),
      sourceName: requireNullableString(json, 'sourceName', 'FOOD provenance'),
      sourceReference: requireNullableString(
        json,
        'sourceReference',
        'FOOD provenance',
      ),
      capturedAt: requireUtcDateTime(json, 'capturedAt', 'FOOD provenance'),
      sourceUpdatedAt: sourceUpdatedAt == null
          ? null
          : _parseUtc(sourceUpdatedAt, 'sourceUpdatedAt'),
      notes: requireNullableString(json, 'notes', 'FOOD provenance'),
    );
  }

  static DateTime _parseUtc(String source, String field) {
    final value = DateTime.tryParse(source);
    if (value == null || !value.isUtc || value.toIso8601String() != source) {
      throw FormatException('Invalid FOOD provenance $field.');
    }
    return value;
  }
}
