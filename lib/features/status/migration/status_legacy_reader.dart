import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/morning_data.dart';
import '../../../core/models/work_type.dart';
import '../models/persisted_status_record.dart';

class ValidLegacyStatusRecord {
  final int sourceIndex;
  final String rawPayload;
  final MorningData data;

  const ValidLegacyStatusRecord({
    required this.sourceIndex,
    required this.rawPayload,
    required this.data,
  });
}

class InvalidLegacyStatusRecord {
  final int sourceIndex;
  final String rawPayload;
  final String errorCode;
  final String errorMessage;

  const InvalidLegacyStatusRecord({
    required this.sourceIndex,
    required this.rawPayload,
    required this.errorCode,
    required this.errorMessage,
  });
}

class StatusLegacyReadResult {
  final List<String> rawRecords;
  final List<ValidLegacyStatusRecord> validRecords;
  final List<InvalidLegacyStatusRecord> invalidRecords;

  StatusLegacyReadResult({
    required Iterable<String> rawRecords,
    required Iterable<ValidLegacyStatusRecord> validRecords,
    required Iterable<InvalidLegacyStatusRecord> invalidRecords,
  }) : rawRecords = List.unmodifiable(rawRecords),
       validRecords = List.unmodifiable(validRecords),
       invalidRecords = List.unmodifiable(invalidRecords);

  int get sourceCount => rawRecords.length;
}

class StatusLegacyReader {
  static const sourceSystem = 'shared_preferences';
  static const sourceKey = 'morning_records';

  final Future<SharedPreferences> Function() _preferences;

  StatusLegacyReader({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  Future<StatusLegacyReadResult> read() async {
    final preferences = await _preferences();
    final rawRecords = List<String>.from(
      preferences.getStringList(sourceKey) ?? const [],
    );
    final valid = <ValidLegacyStatusRecord>[];
    final invalid = <InvalidLegacyStatusRecord>[];

    for (var index = 0; index < rawRecords.length; index++) {
      final rawPayload = rawRecords[index];
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('STATUS record must be a JSON object.');
        }
        _validateSchema(decoded);
        final data = MorningData.fromJson(decoded);
        PersistedStatusRecord.localDateFromSource(data.date);
        _validateDomain(data);
        valid.add(
          ValidLegacyStatusRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            data: data,
          ),
        );
      } on FormatException catch (error) {
        invalid.add(
          InvalidLegacyStatusRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: _isJsonError(error) ? 'invalidJson' : 'invalidSchema',
            errorMessage: error.message,
          ),
        );
      } catch (error) {
        invalid.add(
          InvalidLegacyStatusRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: 'invalidSchema',
            errorMessage: error.toString(),
          ),
        );
      }
    }

    return StatusLegacyReadResult(
      rawRecords: rawRecords,
      validRecords: valid,
      invalidRecords: invalid,
    );
  }

  static void _validateSchema(Map<String, dynamic> json) {
    if (json['date'] is! String ||
        json['memo'] is! String ||
        json['workType'] is! String) {
      throw const FormatException('Missing required STATUS field.');
    }
    final workType = json['workType'] as String;
    if (!WorkType.values.any((value) => value.name == workType)) {
      throw const FormatException('Invalid STATUS workType.');
    }
    for (final key in [
      'weight',
      'bodyFat',
      'sleepHours',
      'sleepScore',
      'footPain',
      'condition',
      'bowelAmount',
      'bowelShape',
      'workHours',
    ]) {
      final value = json[key];
      if (value != null && value is! num) {
        throw FormatException('Invalid STATUS $key.');
      }
    }
    for (final key in ['workStart', 'workEnd', 'workBreak']) {
      final value = json[key];
      if (value != null && value is! String) {
        throw FormatException('Invalid STATUS $key.');
      }
    }
    final carryover = json['previousCarryoverConfirmed'];
    if (carryover != null && carryover is! bool) {
      throw const FormatException('Invalid STATUS previousCarryoverConfirmed.');
    }
  }

  static void _validateDomain(MorningData data) {
    for (final value in [
      data.weight,
      data.bodyFat,
      data.sleepHours,
      data.workHours,
    ]) {
      if (value != null && !value.isFinite) {
        throw const FormatException('STATUS numeric value must be finite.');
      }
    }
  }

  static bool _isJsonError(FormatException error) {
    return error.source != null;
  }
}
