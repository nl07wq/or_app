import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/daily_log_confirmation.dart';
import '../models/persisted_daily_log_confirmation_record.dart';

class ValidLegacyDailyLogConfirmationRecord {
  final int sourceIndex;
  final String rawPayload;
  final int snapshotVersion;
  final String localDate;
  final DailyLogConfirmation data;

  const ValidLegacyDailyLogConfirmationRecord({
    required this.sourceIndex,
    required this.rawPayload,
    required this.snapshotVersion,
    required this.localDate,
    required this.data,
  });
}

class InvalidLegacyDailyLogConfirmationRecord {
  final int sourceIndex;
  final String rawPayload;
  final String errorCode;
  final String errorMessage;

  const InvalidLegacyDailyLogConfirmationRecord({
    required this.sourceIndex,
    required this.rawPayload,
    required this.errorCode,
    required this.errorMessage,
  });
}

class DailyLogConfirmationLegacyReadResult {
  final bool sourceKeyPresent;
  final List<String> rawRecords;
  final List<ValidLegacyDailyLogConfirmationRecord> validRecords;
  final List<InvalidLegacyDailyLogConfirmationRecord> invalidRecords;

  DailyLogConfirmationLegacyReadResult({
    required this.sourceKeyPresent,
    required Iterable<String> rawRecords,
    required Iterable<ValidLegacyDailyLogConfirmationRecord> validRecords,
    required Iterable<InvalidLegacyDailyLogConfirmationRecord> invalidRecords,
  }) : rawRecords = List.unmodifiable(rawRecords),
       validRecords = List.unmodifiable(validRecords),
       invalidRecords = List.unmodifiable(invalidRecords);

  int get sourceCount => rawRecords.length;
}

class DailyLogConfirmationLegacyReader {
  static const sourceSystem = 'shared_preferences';
  static const sourceKey = 'daily_log_confirmations';

  final Future<SharedPreferences> Function() _preferences;

  DailyLogConfirmationLegacyReader({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  Future<DailyLogConfirmationLegacyReadResult> read() async {
    final preferences = await _preferences();
    final sourceKeyPresent = preferences.containsKey(sourceKey);
    final rawRecords = List<String>.from(
      preferences.getStringList(sourceKey) ?? const [],
    );
    final valid = <ValidLegacyDailyLogConfirmationRecord>[];
    final invalid = <InvalidLegacyDailyLogConfirmationRecord>[];

    for (var index = 0; index < rawRecords.length; index++) {
      final rawPayload = rawRecords[index];
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException(
            'Daily Log Confirmation must be a JSON object.',
          );
        }
        final snapshotVersion =
            decoded['snapshotVersion'] ??
            PersistedDailyLogConfirmationRecord.currentSnapshotVersion;
        if (snapshotVersion is! int ||
            snapshotVersion !=
                PersistedDailyLogConfirmationRecord.currentSnapshotVersion) {
          throw UnsupportedDailyLogSnapshotVersionException(snapshotVersion);
        }
        _validateSchema(decoded);
        final localDate = _sourceLocalDate(decoded['date'] as String);
        final parsedData = DailyLogConfirmation.fromJson(decoded);
        final data = parsedData.copyWith(
          date: DateTime.parse('${localDate}T00:00:00'),
        );
        _validateDomain(data);
        valid.add(
          ValidLegacyDailyLogConfirmationRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            snapshotVersion: snapshotVersion,
            localDate: localDate,
            data: data,
          ),
        );
      } on UnsupportedDailyLogSnapshotVersionException catch (error) {
        invalid.add(
          InvalidLegacyDailyLogConfirmationRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: 'unsupportedSnapshotVersion',
            errorMessage: error.toString(),
          ),
        );
      } on _InvalidLegacyConfirmationDate catch (error) {
        invalid.add(
          InvalidLegacyDailyLogConfirmationRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: 'invalidDate',
            errorMessage: error.message,
          ),
        );
      } on FormatException catch (error) {
        invalid.add(
          InvalidLegacyDailyLogConfirmationRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: _isJsonError(error) ? 'invalidJson' : 'invalidSchema',
            errorMessage: error.message,
          ),
        );
      } catch (error) {
        invalid.add(
          InvalidLegacyDailyLogConfirmationRecord(
            sourceIndex: index,
            rawPayload: rawPayload,
            errorCode: 'invalidSchema',
            errorMessage: error.toString(),
          ),
        );
      }
    }
    return DailyLogConfirmationLegacyReadResult(
      sourceKeyPresent: sourceKeyPresent,
      rawRecords: rawRecords,
      validRecords: valid,
      invalidRecords: invalid,
    );
  }

  static void _validateSchema(Map<String, dynamic> json) {
    if (json['date'] is! String || json['confirmedAt'] is! String) {
      throw const FormatException(
        'Missing required Daily Log Confirmation field.',
      );
    }
    _sourceLocalDate(json['date'] as String);
    _validateDate(json['confirmedAt'] as String, localDate: false);
    for (final key in const ['morning', 'food', 'activity', 'training']) {
      final value = json[key];
      if (value != null && value is! Map) {
        throw FormatException('Invalid Daily Log Confirmation $key snapshot.');
      }
    }
  }

  static String _sourceLocalDate(String value) {
    _validateDate(value, localDate: true);
    return value.substring(0, 10);
  }

  static void _validateDate(String value, {required bool localDate}) {
    if (DateTime.tryParse(value) == null) {
      throw _InvalidLegacyConfirmationDate('Invalid date: $value');
    }
    if (!localDate) return;
    if (value.length < 10) {
      throw _InvalidLegacyConfirmationDate('Invalid local date: $value');
    }
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})',
    ).firstMatch(value.substring(0, 10));
    if (match == null) {
      throw _InvalidLegacyConfirmationDate('Invalid local date: $value');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw _InvalidLegacyConfirmationDate('Invalid local date: $value');
    }
  }

  static void _validateDomain(DailyLogConfirmation data) {
    final json = data.toJson();
    _validateFinite(json);
  }

  static void _validateFinite(Object? value) {
    if (value is double && !value.isFinite) {
      throw const FormatException(
        'Daily Log Confirmation numeric value must be finite.',
      );
    }
    if (value is Map) {
      for (final nested in value.values) {
        _validateFinite(nested);
      }
    } else if (value is Iterable) {
      for (final nested in value) {
        _validateFinite(nested);
      }
    }
  }

  static bool _isJsonError(FormatException error) => error.source != null;
}

class _InvalidLegacyConfirmationDate implements Exception {
  final String message;

  const _InvalidLegacyConfirmationDate(this.message);
}
