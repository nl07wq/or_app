import 'package:shared_preferences/shared_preferences.dart';

class ValidLegacyCustomTrainingExercise {
  final int sourceIndex;
  final Object rawPayload;
  final String name;

  const ValidLegacyCustomTrainingExercise({
    required this.sourceIndex,
    required this.rawPayload,
    required this.name,
  });
}

class InvalidLegacyCustomTrainingExercise {
  final int sourceIndex;
  final Object? rawPayload;
  final String errorCode;
  final String errorMessage;

  const InvalidLegacyCustomTrainingExercise({
    required this.sourceIndex,
    required this.rawPayload,
    required this.errorCode,
    required this.errorMessage,
  });
}

class CustomTrainingExerciseLegacyReadResult {
  final Object? rawValue;
  final List<Object?> rawRecords;
  final List<ValidLegacyCustomTrainingExercise> validRecords;
  final List<InvalidLegacyCustomTrainingExercise> invalidRecords;

  CustomTrainingExerciseLegacyReadResult({
    required this.rawValue,
    required Iterable<Object?> rawRecords,
    required Iterable<ValidLegacyCustomTrainingExercise> validRecords,
    required Iterable<InvalidLegacyCustomTrainingExercise> invalidRecords,
  }) : rawRecords = List.unmodifiable(rawRecords),
       validRecords = List.unmodifiable(validRecords),
       invalidRecords = List.unmodifiable(invalidRecords);

  int get sourceCount => rawRecords.length;
}

class CustomTrainingExerciseLegacyReader {
  static const sourceSystem = 'shared_preferences';
  static const sourceKey = 'training_custom_exercises';

  final Future<SharedPreferences> Function() _preferences;

  CustomTrainingExerciseLegacyReader({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  Future<CustomTrainingExerciseLegacyReadResult> read() async {
    final preferences = await _preferences();
    final rawValue = preferences.get(sourceKey);
    if (rawValue == null) {
      return CustomTrainingExerciseLegacyReadResult(
        rawValue: null,
        rawRecords: const [],
        validRecords: const [],
        invalidRecords: const [],
      );
    }

    if (rawValue is! List) {
      return CustomTrainingExerciseLegacyReadResult(
        rawValue: rawValue,
        rawRecords: [rawValue],
        validRecords: const [],
        invalidRecords: [
          InvalidLegacyCustomTrainingExercise(
            sourceIndex: 0,
            rawPayload: rawValue,
            errorCode: 'invalidSchema',
            errorMessage:
                'Custom Training Exercise Legacy value must be a StringList.',
          ),
        ],
      );
    }
    final rawRecords = List<Object?>.from(rawValue);
    final valid = <ValidLegacyCustomTrainingExercise>[];
    final invalid = <InvalidLegacyCustomTrainingExercise>[];
    for (var index = 0; index < rawRecords.length; index++) {
      final raw = rawRecords[index];
      if (raw is! String) {
        invalid.add(
          InvalidLegacyCustomTrainingExercise(
            sourceIndex: index,
            rawPayload: raw,
            errorCode: 'invalidSchema',
            errorMessage: 'Custom Training Exercise name must be a string.',
          ),
        );
        continue;
      }
      if (raw.trim().isEmpty) {
        invalid.add(
          InvalidLegacyCustomTrainingExercise(
            sourceIndex: index,
            rawPayload: raw,
            errorCode: 'invalidName',
            errorMessage: 'Custom Training Exercise name cannot be empty.',
          ),
        );
        continue;
      }
      valid.add(
        ValidLegacyCustomTrainingExercise(
          sourceIndex: index,
          rawPayload: raw,
          name: raw,
        ),
      );
    }
    return CustomTrainingExerciseLegacyReadResult(
      rawValue: rawValue,
      rawRecords: rawRecords,
      validRecords: valid,
      invalidRecords: invalid,
    );
  }
}
