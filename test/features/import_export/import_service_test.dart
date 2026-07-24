import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/import_export/models/import_result.dart';
import 'package:or_app/features/import_export/services/import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'training_sessions': ['existing-training'],
      'morning_records': ['existing-morning'],
    });
  });

  test('reconstructs a valid immutable schema 1.0 snapshot', () async {
    final json = jsonEncode({
      'schemaVersion': '1.0',
      'exportedAt': '2026-07-25T12:30:00.000Z',
      'training': [
        {
          'date': '2026-07-25T10:00:00.000',
          'memo': '脚の日',
          'exercises': [
            {
              'exerciseName': 'HackSquat',
              'order': 1,
              'sets': [
                {'setNo': 1, 'weight': 80, 'reps': 10},
              ],
            },
          ],
        },
      ],
      'morningFact': [
        {'date': '2026-07-25T06:00:00.000', 'sleepScore': 82},
      ],
      'metadata': {'applicationVersion': '1.0.0', 'devicePlatform': 'web'},
    });

    final result = ImportService.importJson(json);

    expect(result.success, isTrue);
    expect(result.errorCode, isNull);
    expect(result.message, isNull);
    expect(result.data?.schemaVersion, '1.0');
    expect(result.data?.exportedAt, DateTime.utc(2026, 7, 25, 12, 30));
    expect(result.data?.training?.single['memo'], '脚の日');
    expect(result.data?.morningFact?.single['sleepScore'], 82);
    expect(result.data?.metadata.applicationVersion, '1.0.0');
    expect(result.data?.metadata.devicePlatform, 'web');
    expect(
      () => result.data!.training!.add(const {'date': 'later'}),
      throwsUnsupportedError,
    );
    expect(
      () => (result.data!.training!.single['exercises'] as List).add('later'),
      throwsUnsupportedError,
    );

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('training_sessions'), [
      'existing-training',
    ]);
    expect(preferences.getStringList('morning_records'), ['existing-morning']);
  });

  test('returns a structured error for unsupported schema versions', () {
    final result = ImportService.importJson(
      jsonEncode({
        'schemaVersion': '2.0',
        'exportedAt': '2026-07-25T12:30:00.000Z',
      }),
    );

    expect(result.success, isFalse);
    expect(result.data, isNull);
    expect(result.errorCode, ImportErrorCode.unsupportedSchemaVersion);
    expect(result.message, 'Unsupported schemaVersion: 2.0.');
  });

  test('returns structured errors for malformed JSON and root values', () {
    final malformed = ImportService.importJson('{');
    final wrongRoot = ImportService.importJson('[]');

    expect(malformed.success, isFalse);
    expect(malformed.errorCode, ImportErrorCode.invalidJson);
    expect(wrongRoot.success, isFalse);
    expect(wrongRoot.errorCode, ImportErrorCode.invalidStructure);
  });

  test('validates required fields and optional section structure', () {
    final missingVersion = ImportService.importJson(
      jsonEncode({'exportedAt': '2026-07-25T12:30:00.000Z'}),
    );
    final invalidDate = ImportService.importJson(
      jsonEncode({'schemaVersion': '1.0', 'exportedAt': 'not-a-date'}),
    );
    final invalidTraining = ImportService.importJson(
      jsonEncode({
        'schemaVersion': '1.0',
        'exportedAt': '2026-07-25T12:30:00.000Z',
        'training': {},
      }),
    );
    final invalidMetadata = ImportService.importJson(
      jsonEncode({
        'schemaVersion': '1.0',
        'exportedAt': '2026-07-25T12:30:00.000Z',
        'metadata': {'applicationVersion': 1},
      }),
    );

    expect(missingVersion.errorCode, ImportErrorCode.invalidStructure);
    expect(invalidDate.errorCode, ImportErrorCode.invalidStructure);
    expect(invalidTraining.errorCode, ImportErrorCode.invalidStructure);
    expect(invalidMetadata.errorCode, ImportErrorCode.invalidStructure);
  });
}
