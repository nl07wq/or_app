import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/training_session.dart';
import '../models/persisted_training_record.dart';

class ValidLegacyTrainingRecord {
  final int sourceIndex;
  final String rawPayload;
  final Map<String, dynamic> decodedPayload;
  final TrainingSession data;

  const ValidLegacyTrainingRecord({
    required this.sourceIndex,
    required this.rawPayload,
    required this.decodedPayload,
    required this.data,
  });
}

class InvalidLegacyTrainingRecord {
  final int sourceIndex;
  final String rawPayload;
  final String errorCode;
  final String errorMessage;

  const InvalidLegacyTrainingRecord({
    required this.sourceIndex,
    required this.rawPayload,
    required this.errorCode,
    required this.errorMessage,
  });
}

class TrainingLegacyReadResult {
  final List<String> rawRecords;
  final List<ValidLegacyTrainingRecord> validRecords;
  final List<InvalidLegacyTrainingRecord> invalidRecords;

  TrainingLegacyReadResult({
    required Iterable<String> rawRecords,
    required Iterable<ValidLegacyTrainingRecord> validRecords,
    required Iterable<InvalidLegacyTrainingRecord> invalidRecords,
  }) : rawRecords = List.unmodifiable(rawRecords),
       validRecords = List.unmodifiable(validRecords),
       invalidRecords = List.unmodifiable(invalidRecords);

  int get sourceCount => rawRecords.length;
}

class TrainingLegacyReader {
  static const sourceSystem = 'shared_preferences';
  static const sourceKey = 'training_sessions';

  final Future<SharedPreferences> Function() _preferences;

  TrainingLegacyReader({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  Future<TrainingLegacyReadResult> read() async {
    final preferences = await _preferences();
    final rawRecords = List<String>.from(
      preferences.getStringList(sourceKey) ?? const [],
    );
    final valid = <ValidLegacyTrainingRecord>[];
    final invalid = <InvalidLegacyTrainingRecord>[];

    for (var index = 0; index < rawRecords.length; index++) {
      final rawPayload = rawRecords[index];
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('TRAINING record must be a JSON object.');
        }
        _validateSchema(decoded);
        final data = TrainingSession.fromJson(decoded);
        PersistedTrainingRecord.localDateFromSession(data);
        _validateDomain(data);
        valid.add(
          ValidLegacyTrainingRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            decodedPayload: Map<String, dynamic>.unmodifiable(
              _copyMap(decoded),
            ),
            data: data,
          ),
        );
      } on FormatException catch (error) {
        invalid.add(
          InvalidLegacyTrainingRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: _isJsonError(error) ? 'invalidJson' : 'invalidSchema',
            errorMessage: error.message,
          ),
        );
      } catch (error) {
        invalid.add(
          InvalidLegacyTrainingRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: 'invalidSchema',
            errorMessage: error.toString(),
          ),
        );
      }
    }
    return TrainingLegacyReadResult(
      rawRecords: rawRecords,
      validRecords: valid,
      invalidRecords: invalid,
    );
  }

  static void _validateSchema(Map<String, dynamic> json) {
    if (json['date'] is! String ||
        json['memo'] is! String ||
        json['exercises'] is! List) {
      throw const FormatException('Missing required TRAINING field.');
    }
    final cardioEntries = json['cardioEntries'];
    if (cardioEntries != null && cardioEntries is! List) {
      throw const FormatException('Invalid TRAINING cardioEntries.');
    }
    for (final exerciseValue in json['exercises'] as List) {
      if (exerciseValue is! Map) {
        throw const FormatException('TRAINING exercise must be a JSON object.');
      }
      final exercise = Map<String, dynamic>.from(exerciseValue);
      if (exercise['exerciseName'] is! String ||
          exercise['order'] is! int ||
          exercise['sets'] is! List ||
          (exercise['equipmentId'] != null &&
              exercise['equipmentId'] is! String)) {
        throw const FormatException('Invalid TRAINING exercise field.');
      }
      for (final setValue in exercise['sets'] as List) {
        if (setValue is! Map) {
          throw const FormatException('TRAINING set must be a JSON object.');
        }
        final set = Map<String, dynamic>.from(setValue);
        if (set['setNo'] is! int ||
            set['weight'] is! num ||
            set['reps'] is! int) {
          throw const FormatException('Invalid TRAINING set field.');
        }
      }
    }
    for (final cardioValue in (cardioEntries as List? ?? const [])) {
      if (cardioValue is! Map) {
        throw const FormatException('TRAINING cardio must be a JSON object.');
      }
      final cardio = Map<String, dynamic>.from(cardioValue);
      if (cardio['type'] is! String ||
          cardio['intensity'] is! String ||
          cardio['durationMinutes'] is! int ||
          (cardio['distanceKm'] != null && cardio['distanceKm'] is! num) ||
          (cardio['notes'] != null && cardio['notes'] is! String) ||
          (cardio['estimatedCalories'] != null &&
              cardio['estimatedCalories'] is! num)) {
        throw const FormatException('Invalid TRAINING cardio field.');
      }
    }
  }

  static void _validateDomain(TrainingSession session) {
    for (final exercise in session.exercises) {
      for (final set in exercise.sets) {
        if (!set.weight.isFinite) {
          throw const FormatException('TRAINING numeric value must be finite.');
        }
      }
    }
    for (final cardio in session.cardioEntries) {
      if (cardio.distanceKm?.isFinite == false ||
          cardio.estimatedCalories?.isFinite == false) {
        throw const FormatException('TRAINING numeric value must be finite.');
      }
    }
  }

  static bool _isJsonError(FormatException error) => error.source != null;

  static Map<String, dynamic> _copyMap(Map source) {
    return {
      for (final entry in source.entries)
        entry.key.toString(): _copyValue(entry.value),
    };
  }

  static Object? _copyValue(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is Iterable) return [for (final item in value) _copyValue(item)];
    return value;
  }
}
