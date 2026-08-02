import 'daily_meal_v2_models.dart';

class PersistedDailyMealV2Record {
  final String id;
  final int recordVersion;
  final String localDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DailyMealV2 data;

  const PersistedDailyMealV2Record({
    required this.id,
    this.recordVersion = DailyMealV2.recordVersion2,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    required this.data,
  });

  factory PersistedDailyMealV2Record.fromMeal(DailyMealV2 meal) =>
      PersistedDailyMealV2Record(
        id: envelopeId(meal.mealId),
        localDate: meal.localDate,
        createdAt: meal.createdAt,
        updatedAt: meal.updatedAt,
        data: meal,
      );

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': recordVersion,
    'localDate': localDate,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'data': data.toJson(),
  };

  factory PersistedDailyMealV2Record.fromRecord(Map<String, Object?> record) {
    const fields = {
      'id',
      'recordVersion',
      'localDate',
      'createdAt',
      'updatedAt',
      'data',
    };
    if (record.keys.any((key) => !fields.contains(key))) {
      throw const FormatException('Unknown Daily Meal v2 envelope field.');
    }
    final dataValue = record['data'];
    if (dataValue is! Map) throw const FormatException('Invalid FOOD data.');
    final data = DailyMealV2.fromJson(Map<String, Object?>.from(dataValue));
    final result = PersistedDailyMealV2Record(
      id: _string(record, 'id'),
      recordVersion: _integer(record, 'recordVersion'),
      localDate: _string(record, 'localDate'),
      createdAt: _date(record, 'createdAt'),
      updatedAt: _date(record, 'updatedAt'),
      data: data,
    );
    if (result.recordVersion != DailyMealV2.recordVersion2 ||
        result.id != envelopeId(data.mealId) ||
        result.localDate != data.localDate ||
        result.createdAt.toUtc() != data.createdAt.toUtc() ||
        result.updatedAt.toUtc() != data.updatedAt.toUtc()) {
      throw const FormatException('Daily Meal v2 envelope mismatch.');
    }
    return result;
  }

  static String envelopeId(String mealId) => 'food:$mealId';

  static String _string(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! String || result.isEmpty) {
      throw FormatException('Invalid Daily Meal v2 $key.');
    }
    return result;
  }

  static int _integer(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! int) throw FormatException('Invalid Daily Meal v2 $key.');
    return result;
  }

  static DateTime _date(Map<String, Object?> value, String key) {
    final result = DateTime.tryParse(_string(value, key));
    if (result == null || !result.isUtc) {
      throw FormatException('Invalid Daily Meal v2 $key.');
    }
    return result;
  }
}
