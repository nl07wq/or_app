import '../../../core/models/meal_data.dart';

class FoodMigrationSource {
  final String migrationId;
  final String sourceSystem;
  final String sourceKey;
  final int sourceIndex;

  const FoodMigrationSource({
    required this.migrationId,
    required this.sourceSystem,
    required this.sourceKey,
    required this.sourceIndex,
  });

  Map<String, Object?> toJson() => {
    'migrationId': migrationId,
    'sourceSystem': sourceSystem,
    'sourceKey': sourceKey,
    'sourceIndex': sourceIndex,
  };

  factory FoodMigrationSource.fromJson(Map<String, Object?> json) {
    final migrationId = json['migrationId'];
    final sourceSystem = json['sourceSystem'];
    final sourceKey = json['sourceKey'];
    final sourceIndex = json['sourceIndex'];
    if (migrationId is! String ||
        sourceSystem is! String ||
        sourceKey is! String ||
        sourceIndex is! int ||
        sourceIndex < 0) {
      throw const FormatException('Invalid FOOD migration source.');
    }
    return FoodMigrationSource(
      migrationId: migrationId,
      sourceSystem: sourceSystem,
      sourceKey: sourceKey,
      sourceIndex: sourceIndex,
    );
  }
}

class PersistedFoodRecord {
  static const currentRecordVersion = 1;

  final String id;
  final int recordVersion;
  final String localDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final FoodMigrationSource? migrationSource;
  final MealData data;

  const PersistedFoodRecord({
    required this.id,
    this.recordVersion = currentRecordVersion,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    this.migrationSource,
    required this.data,
  });

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': recordVersion,
    'localDate': localDate,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (migrationSource != null) 'migrationSource': migrationSource!.toJson(),
    'data': data.toJson(),
  };

  factory PersistedFoodRecord.fromRecord(Map<String, Object?> record) {
    final id = _requiredString(record, 'id');
    final recordVersion = record['recordVersion'];
    if (recordVersion is! int || recordVersion != currentRecordVersion) {
      throw FormatException('Unsupported FOOD recordVersion: $recordVersion.');
    }
    final localDate = _requiredLocalDate(record, 'localDate');
    final dataValue = record['data'];
    if (dataValue is! Map) {
      throw const FormatException('Invalid FOOD data.');
    }
    final mealJson = Map<String, dynamic>.from(dataValue);
    final itemsValue = mealJson['items'];
    if (itemsValue is! List || itemsValue.any((item) => item is! Map)) {
      throw const FormatException('Invalid FOOD items.');
    }
    mealJson['items'] = [
      for (final item in itemsValue)
        Map<String, dynamic>.from(item as Map),
    ];
    final data = MealData.fromJson(mealJson);
    if (id != envelopeId(data.id) ||
        localDateFromMealDate(data.date) != localDate) {
      throw const FormatException(
        'FOOD Envelope does not match its Domain data.',
      );
    }
    final sourceValue = record['migrationSource'];
    if (sourceValue != null && sourceValue is! Map) {
      throw const FormatException('Invalid FOOD migrationSource.');
    }
    return PersistedFoodRecord(
      id: id,
      recordVersion: recordVersion,
      localDate: localDate,
      createdAt: _requiredDate(record, 'createdAt'),
      updatedAt: _requiredDate(record, 'updatedAt'),
      migrationSource: sourceValue == null
          ? null
          : FoodMigrationSource.fromJson(
              Map<String, Object?>.from(sourceValue as Map),
            ),
      data: data,
    );
  }

  static String envelopeId(String mealId) {
    if (mealId.trim().isEmpty) {
      throw const FormatException('FOOD Meal ID must not be empty.');
    }
    return mealId.startsWith('food:') ? mealId : 'food:$mealId';
  }

  static String mealIdFromEnvelopeId(String id) {
    if (!id.startsWith('food:') || id.length == 'food:'.length) {
      throw const FormatException('Invalid FOOD Envelope ID.');
    }
    return id.substring('food:'.length);
  }

  static String localDateFromMealDate(String sourceDate) {
    if (sourceDate.length < 10 || DateTime.tryParse(sourceDate) == null) {
      throw const FormatException('Invalid FOOD source date.');
    }
    final localDate = sourceDate.substring(0, 10);
    validateLocalDate(localDate);
    return localDate;
  }

  static void validateLocalDate(String localDate) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(localDate);
    if (match == null) {
      throw const FormatException('Invalid FOOD localDate.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid FOOD localDate.');
    }
  }

  static String _requiredString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid FOOD $key.');
    }
    return value;
  }

  static String _requiredLocalDate(Map<String, Object?> record, String key) {
    final value = _requiredString(record, key);
    validateLocalDate(value);
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('Invalid FOOD $key.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Invalid FOOD $key.');
    }
    return date;
  }
}
