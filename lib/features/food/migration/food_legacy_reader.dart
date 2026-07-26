import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/meal_data.dart';
import '../models/persisted_food_record.dart';

class ValidLegacyFoodRecord {
  final int sourceIndex;
  final String rawPayload;
  final MealData data;

  const ValidLegacyFoodRecord({
    required this.sourceIndex,
    required this.rawPayload,
    required this.data,
  });
}

class InvalidLegacyFoodRecord {
  final int sourceIndex;
  final String rawPayload;
  final String errorCode;
  final String errorMessage;

  const InvalidLegacyFoodRecord({
    required this.sourceIndex,
    required this.rawPayload,
    required this.errorCode,
    required this.errorMessage,
  });
}

class FoodLegacyReadResult {
  final List<String> rawRecords;
  final List<ValidLegacyFoodRecord> validRecords;
  final List<InvalidLegacyFoodRecord> invalidRecords;

  FoodLegacyReadResult({
    required Iterable<String> rawRecords,
    required Iterable<ValidLegacyFoodRecord> validRecords,
    required Iterable<InvalidLegacyFoodRecord> invalidRecords,
  }) : rawRecords = List.unmodifiable(rawRecords),
       validRecords = List.unmodifiable(validRecords),
       invalidRecords = List.unmodifiable(invalidRecords);

  int get sourceCount => rawRecords.length;
}

class FoodLegacyReader {
  static const sourceSystem = 'shared_preferences';
  static const sourceKey = 'meal_records';

  final Future<SharedPreferences> Function() _preferences;

  FoodLegacyReader({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  Future<FoodLegacyReadResult> read() async {
    final preferences = await _preferences();
    final rawRecords = List<String>.from(
      preferences.getStringList(sourceKey) ?? const [],
    );
    final valid = <ValidLegacyFoodRecord>[];
    final invalid = <InvalidLegacyFoodRecord>[];

    for (var index = 0; index < rawRecords.length; index++) {
      final rawPayload = rawRecords[index];
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('FOOD record must be a JSON object.');
        }
        _validateSchema(decoded);
        final data = MealData.fromJson(decoded);
        PersistedFoodRecord.envelopeId(data.id);
        PersistedFoodRecord.localDateFromMealDate(data.date);
        _validateDomain(data);
        valid.add(
          ValidLegacyFoodRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            data: data,
          ),
        );
      } on FormatException catch (error) {
        invalid.add(
          InvalidLegacyFoodRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: _isJsonError(error) ? 'invalidJson' : 'invalidSchema',
            errorMessage: error.message,
          ),
        );
      } catch (error) {
        invalid.add(
          InvalidLegacyFoodRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: 'invalidSchema',
            errorMessage: error.toString(),
          ),
        );
      }
    }

    return FoodLegacyReadResult(
      rawRecords: rawRecords,
      validRecords: valid,
      invalidRecords: invalid,
    );
  }

  static void _validateSchema(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['date'] is! String ||
        json['mealType'] is! String ||
        json['memo'] is! String ||
        json['items'] is! List) {
      throw const FormatException('Missing required FOOD field.');
    }
    final water = json['waterMl'];
    if (water != null && water is! num) {
      throw const FormatException('Invalid FOOD waterMl.');
    }
    for (final itemValue in json['items'] as List) {
      if (itemValue is! Map) {
        throw const FormatException('FOOD item must be a JSON object.');
      }
      final item = Map<String, dynamic>.from(itemValue);
      if (item['name'] is! String ||
          item['calories'] is! int ||
          item['protein'] is! num ||
          item['fat'] is! num ||
          item['carbohydrate'] is! num) {
        throw const FormatException('Invalid FOOD item field.');
      }
      final quantity = item['quantity'];
      if (quantity != null && (quantity is! int || quantity < 1)) {
        throw const FormatException('Invalid FOOD item quantity.');
      }
    }
  }

  static void _validateDomain(MealData data) {
    final values = <double>[
      if (data.waterMl != null) data.waterMl!,
      for (final item in data.items) ...[
        item.protein,
        item.fat,
        item.carbohydrate,
      ],
    ];
    if (values.any((value) => !value.isFinite)) {
      throw const FormatException('FOOD numeric value must be finite.');
    }
  }

  static bool _isJsonError(FormatException error) => error.source != null;
}
