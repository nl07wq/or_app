import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/activity_data.dart';
import '../../../core/models/bowel_movement_record.dart';
import '../models/persisted_activity_record.dart';

class ValidLegacyActivityRecord {
  final int sourceIndex;
  final String rawPayload;
  final ActivityData data;

  const ValidLegacyActivityRecord({
    required this.sourceIndex,
    required this.rawPayload,
    required this.data,
  });
}

class InvalidLegacyActivityRecord {
  final int sourceIndex;
  final String rawPayload;
  final String errorCode;
  final String errorMessage;

  const InvalidLegacyActivityRecord({
    required this.sourceIndex,
    required this.rawPayload,
    required this.errorCode,
    required this.errorMessage,
  });
}

class ActivityLegacyReadResult {
  final List<String> rawRecords;
  final List<ValidLegacyActivityRecord> validRecords;
  final List<InvalidLegacyActivityRecord> invalidRecords;

  ActivityLegacyReadResult({
    required Iterable<String> rawRecords,
    required Iterable<ValidLegacyActivityRecord> validRecords,
    required Iterable<InvalidLegacyActivityRecord> invalidRecords,
  }) : rawRecords = List.unmodifiable(rawRecords),
       validRecords = List.unmodifiable(validRecords),
       invalidRecords = List.unmodifiable(invalidRecords);

  int get sourceCount => rawRecords.length;
}

class ActivityLegacyReader {
  static const sourceSystem = 'shared_preferences';
  static const sourceKey = 'activity_records';

  final Future<SharedPreferences> Function() _preferences;

  ActivityLegacyReader({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  Future<ActivityLegacyReadResult> read() async {
    final preferences = await _preferences();
    final rawRecords = List<String>.from(
      preferences.getStringList(sourceKey) ?? const [],
    );
    final valid = <ValidLegacyActivityRecord>[];
    final invalid = <InvalidLegacyActivityRecord>[];

    for (var index = 0; index < rawRecords.length; index++) {
      final rawPayload = rawRecords[index];
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('ACTIVITY record must be a JSON object.');
        }
        _validateSchema(decoded);
        final data = ActivityData.fromJson(decoded);
        final localDate = PersistedActivityRecord.localDateFromDate(data.date);
        _validateDomain(data, localDate);
        valid.add(
          ValidLegacyActivityRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            data: data,
          ),
        );
      } on FormatException catch (error) {
        invalid.add(
          InvalidLegacyActivityRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: _isJsonError(error) ? 'invalidJson' : 'invalidSchema',
            errorMessage: error.message,
          ),
        );
      } catch (error) {
        invalid.add(
          InvalidLegacyActivityRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: 'invalidSchema',
            errorMessage: error.toString(),
          ),
        );
      }
    }

    return ActivityLegacyReadResult(
      rawRecords: rawRecords,
      validRecords: valid,
      invalidRecords: invalid,
    );
  }

  static void _validateSchema(Map<String, dynamic> json) {
    if (json['date'] is! String) {
      throw const FormatException('ACTIVITY date is required.');
    }
    if (json['id'] != null && json['id'] is! String) {
      throw const FormatException('Invalid ACTIVITY id.');
    }
    final measuredSteps =
        json['rawSteps'] ?? json['measuredSteps'] ?? json['steps'];
    if (measuredSteps is! num) {
      throw const FormatException('ACTIVITY measured steps are required.');
    }
    for (final key in [
      'rawSteps',
      'measuredSteps',
      'steps',
      'carryOver',
      'carryoverSteps',
      'officialSteps',
    ]) {
      final value = json[key];
      if (value != null && value is! num) {
        throw FormatException('Invalid ACTIVITY $key.');
      }
    }
    for (final key in ['stepsEntered', 'carryOverEntered']) {
      final value = json[key];
      if (value != null && value is! bool) {
        throw FormatException('Invalid ACTIVITY $key.');
      }
    }
    for (final key in [
      'plannedWork',
      'actualWork',
      'trainingStatus',
      'note',
      'createdAt',
      'updatedAt',
    ]) {
      final value = json[key];
      if (value != null && value is! String) {
        throw FormatException('Invalid ACTIVITY $key.');
      }
    }
    final bowel = json['bowelMovement'];
    if (bowel != null) {
      if (bowel is! Map) {
        throw const FormatException('Invalid ACTIVITY bowelMovement.');
      }
      final bowelJson = Map<String, dynamic>.from(bowel);
      final status = bowelJson['status'];
      if (status is! String ||
          !BowelMovementStatus.values.any((value) => value.name == status)) {
        throw const FormatException('Invalid ACTIVITY bowelMovement status.');
      }
      for (final key in ['amount', 'shape']) {
        final value = bowelJson[key];
        if (value != null && value is! num) {
          throw FormatException('Invalid ACTIVITY bowelMovement $key.');
        }
      }
    }
  }

  static void _validateDomain(ActivityData data, String localDate) {
    if (data.id != localDate) {
      throw const FormatException(
        'ACTIVITY Domain ID must match its local date.',
      );
    }
  }

  static bool _isJsonError(FormatException error) => error.source != null;
}
