import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_issue.dart';
import 'package:or_app/features/report_sync/models/report_sync_history.dart';
import 'package:or_app/features/report_sync/services/report_sync_canonical_service.dart';
import 'package:or_app/features/report_sync/services/report_sync_codec.dart';
import 'package:or_app/features/report_sync/services/report_sync_instruction_provider.dart';

void main() {
  const codec = ReportSyncCodec();
  const trainingRequest = <String, Object?>{
    'operationDate': '2026-08-02',
    'requestPurpose': 'Create a training record.',
    'currentSession': null,
    'recentTrainingSummary': null,
    'registeredExercises': <Object?>[],
    'registeredEquipment': <Object?>[],
    'statusWeight': null,
    'instructionContext': <String, Object?>{},
  };
  final digest = ReportSyncCanonicalService.digest(trainingRequest);

  test('Report Sync History version 2 round-trips formal FOOD counts', () {
    expect(ReportSyncHistory.currentRecordVersion, 2);
    final history = _history(
      received: 4,
      selected: 2,
      imported: 2,
      conflict: 1,
      excluded: 2,
    );
    final restored = ReportSyncHistory.fromRecord(history.toRecord());
    expect(restored.receivedMealCount, 4);
    expect(restored.selectedMealCount, 2);
    expect(restored.importedMealCount, 2);
    expect(restored.conflictMealCount, 1);
    expect(restored.excludedMealCount, 2);
  });

  test('Report Sync History version 1 remains readable without counts', () {
    final legacy = _history(recordVersion: 1);
    expect(legacy.toRecord().keys, ReportSyncHistory.version1Fields);
    final restored = ReportSyncHistory.fromRecord(legacy.toRecord());
    expect(restored.recordVersion, 1);
    expect(restored.receivedMealCount, isNull);
    expect(restored.selectedMealCount, isNull);
    expect(restored.importedMealCount, isNull);
    expect(restored.conflictMealCount, isNull);
    expect(restored.excludedMealCount, isNull);
  });

  test('TRAINING History version 2 keeps every meal count null', () {
    final history = ReportSyncHistory(
      exchangeId: 'training-history',
      exchangeType: ReportSyncExchangeType.training,
      direction: ReportSyncDirection.response,
      operationDate: '2026-08-02',
      requestId: 'training-history',
      requestDigest: _digest,
      startedAt: DateTime.utc(2026, 8, 2),
      completedAt: DateTime.utc(2026, 8, 2),
      result: ReportSyncHistoryResult.success,
      packageDigest: _digest,
    );
    final restored = ReportSyncHistory.fromRecord(history.toRecord());
    expect(restored.receivedMealCount, isNull);
    expect(restored.selectedMealCount, isNull);
    expect(restored.importedMealCount, isNull);
    expect(restored.conflictMealCount, isNull);
    expect(restored.excludedMealCount, isNull);
  });

  test('Report Sync History rejects invalid meal count contracts', () {
    for (final counts in const [
      (-1, 0, 0, 0, 0),
      (1, 2, 0, 0, 1),
      (2, 1, 2, 0, 0),
      (1, 1, 1, 2, 0),
      (4, 2, 2, 1, 1),
    ]) {
      expect(
        () => _history(
          received: counts.$1,
          selected: counts.$2,
          imported: counts.$3,
          conflict: counts.$4,
          excluded: counts.$5,
        ),
        throwsFormatException,
      );
    }
    final valid = _history(
      received: 1,
      selected: 1,
      imported: 1,
      conflict: 0,
      excluded: 0,
    ).toRecord();
    for (final invalid in <Object>[1.5, '1']) {
      expect(
        () => ReportSyncHistory.fromRecord({
          ...valid,
          'receivedMealCount': invalid,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => ReportSyncHistory(
        exchangeId: 'training-history',
        exchangeType: ReportSyncExchangeType.training,
        direction: ReportSyncDirection.response,
        operationDate: '2026-08-02',
        requestId: 'training-history',
        requestDigest: _digest,
        startedAt: DateTime.utc(2026, 8, 2),
        completedAt: DateTime.utc(2026, 8, 2),
        result: ReportSyncHistoryResult.success,
        packageDigest: _digest,
        receivedMealCount: 1,
        selectedMealCount: 1,
        importedMealCount: 1,
        conflictMealCount: 0,
        excludedMealCount: 0,
      ),
      throwsFormatException,
    );
  });

  test('round-trips the strict common envelope and package digest', () {
    final envelope = codec.create(
      direction: ReportSyncDirection.request,
      exchangeType: ReportSyncExchangeType.training,
      exchangeId: 'exchange-1',
      requestId: 'request-1',
      operationDate: '2026-08-02',
      createdAt: DateTime.utc(2026, 8, 2, 1),
      requestDigest: digest,
      payload: trainingRequest,
    );
    final decoded = codec.decode(codec.encode(envelope));
    expect(decoded.toJson(), envelope.toJson());
    expect(decoded.packageDigest, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('Schema 2 accepts only null and generates the formal digest in-app', () {
    final response = codec.create(
      direction: ReportSyncDirection.response,
      exchangeType: ReportSyncExchangeType.food,
      exchangeId: 'schema-2-food',
      operationDate: '2026-08-02',
      createdAt: DateTime.utc(2026, 8, 2),
      schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
      payload: const {
        'operationDate': '2026-08-02',
        'meals': [
          {
            'sourceMealId': null,
            'mealType': 'Breakfast',
            'items': [
              {
                'name': 'Oats',
                'calories': 100,
                'protein': 4,
                'fat': 2,
                'carbohydrate': 18,
                'quantity': 1,
                'amount': null,
                'baseAmount': null,
                'baseUnit': null,
                'amountMode': null,
              },
            ],
            'memo': null,
            'waterMl': null,
          },
        ],
      },
    );
    final encoded = codec.encode(response);
    expect((jsonDecode(encoded) as Map)['packageDigest'], isNull);

    final decoded = codec.decode(encoded);
    final expected = ReportSyncCanonicalService.digest(decoded.digestPayload());
    expect(decoded.packageDigest, expected);
    expect(decoded.hasValidPackageDigest, isTrue);
    expect(codec.decode(encoded).packageDigest, expected);

    final changed = jsonDecode(encoded) as Map<String, Object?>;
    changed['exchangeId'] = 'schema-2-food-changed';
    final changedDecoded = codec.decode(jsonEncode(changed));
    expect(changedDecoded.packageDigest, isNot(expected));

    for (final invalid in [List.filled(64, '0').join(), expected, '']) {
      expect(
        () => codec.decode(jsonEncode({...changed, 'packageDigest': invalid})),
        throwsA(
          isA<ReportSyncException>().having(
            (error) => error.validationError?.jsonPath,
            'jsonPath',
            r'$.packageDigest',
          ),
        ),
      );
    }
  });

  test('rejects unknown fields, numeric strings, and digest tampering', () {
    final envelope = codec.create(
      direction: ReportSyncDirection.request,
      exchangeType: ReportSyncExchangeType.food,
      exchangeId: 'exchange-2',
      requestId: 'request-2',
      operationDate: '2026-08-02',
      createdAt: DateTime.utc(2026, 8, 2),
      requestDigest: ReportSyncCanonicalService.digest(const {
        'operationDate': '2026-08-02',
        'requestPurpose': 'Create food records.',
        'meals': <Object?>[],
        'dailySummary': null,
        'knownFoodReferences': <Object?>[],
        'instructionContext': <String, Object?>{},
      }),
      payload: const {
        'operationDate': '2026-08-02',
        'requestPurpose': 'Create food records.',
        'meals': <Object?>[],
        'dailySummary': null,
        'knownFoodReferences': <Object?>[],
        'instructionContext': <String, Object?>{},
      },
    );
    final unknown = {...envelope.toJson(), 'extra': true};
    expect(
      () => codec.decode(ReportSyncCanonicalService.encode(unknown)),
      throwsA(isA<ReportSyncException>()),
    );
    final numericString = {...envelope.toJson(), 'envelopeVersion': '1'};
    expect(
      () => codec.decode(ReportSyncCanonicalService.encode(numericString)),
      throwsA(isA<ReportSyncException>()),
    );
    final tampered = {...envelope.toJson(), 'operationDate': '2026-08-03'};
    expect(
      () => codec.decode(ReportSyncCanonicalService.encode(tampered)),
      throwsA(isA<ReportSyncException>()),
    );
  });

  test('registry provides all active exchange instructions', () {
    final registry = ReportSyncInstructionProviderRegistry.standard();
    for (final type in ReportSyncExchangeType.values) {
      final text = registry
          .forType(type)
          .buildInstruction(
            operationDate: '2026-08-02',
            sourceRecordId: type == ReportSyncExchangeType.morningBrief
                ? 'status:2026-08-02'
                : null,
            sourceDigest: type == ReportSyncExchangeType.morningBrief
                ? 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
                : null,
          );
      expect(text, contains('2026-08-02'));
      expect(text, isNot(contains('requestId')));
      expect(text, isNot(contains('requestDigest')));
      if (type == ReportSyncExchangeType.morningBrief) {
        expect(text, contains('正式なMORNING BRIEF'));
        expect(text, contains('```text'));
        expect(text, contains('"schemaVersion": "2.0"'));
        expect(text, contains('"packageDigest": null'));
        expect(text, contains('status:2026-08-02'));
        expect(text, contains('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'));
        expect(text, isNot(contains('"argoComment"')));
        expect(text, isNot(contains('"actionId"')));
        continue;
      }
      expect(text, contains(type.stableId));
      expect(text, contains('exactly one JSON object'));
      expect(text, contains('Do not invent facts'));
      if (type == ReportSyncExchangeType.training ||
          type == ReportSyncExchangeType.food) {
        expect(text, contains('```text'));
        expect(text, contains("ChatGPT's copy button"));
        expect(text, contains('Do not return any text outside'));
        expect(text, contains('"packageDigest": null'));
        expect(text, contains('Do not calculate a digest'));
        expect(text, isNot(contains('canonical JSON')));
        expect(text, isNot(contains('SHA-256')));
        expect(text, isNot(contains('0000000000000000')));
      }
    }
  });

  test('instructions specialize the formal plain-text source contract', () {
    final registry = ReportSyncInstructionProviderRegistry.standard();
    final training = registry
        .forType(ReportSyncExchangeType.training)
        .buildInstruction(operationDate: '2026-08-02');
    expect(training, contains('Training Record that you already retain'));
    expect(training, contains('will not send another source record'));
    expect(training, contains('ASCII half-width double quotation marks'));
    expect(training, contains('Training Import Schema Version 2'));
    expect(
      training,
      contains('Do not create recordId, idempotencyKey, or exerciseId'),
    );
    expect(training, contains('legacyUnknown is forbidden'));

    final food = registry
        .forType(ReportSyncExchangeType.food)
        .buildInstruction(operationDate: '2026-08-02');
    expect(food, contains('all Meal Data records'));
    expect(food, contains('Return every meal'));
    expect(food, contains('Do not merge meals'));
    expect(food, contains('Do not infer nutrition'));
    expect(food, contains('Daily Meal v2'));
    expect(food, contains('Food Import Schema Version 2'));
    expect(food, contains('Do not create mealId'));
    expect(food, contains('one measurement tuple'));
    expect(food, contains('Allowed baseUnit values are g and mL'));
    expect(food, contains('physicalAmount'));
    expect(food, contains('baseMultiplier'));

    final morning = registry
        .forType(ReportSyncExchangeType.morningBrief)
        .buildInstruction(
          operationDate: '2026-08-02',
          sourceRecordId: 'status:2026-08-02',
          sourceDigest:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        );
    expect(morning, contains('正式なSTATUS SOURCEだけを使用'));
    expect(morning, contains('packageDigestはnull'));
    expect(morning, contains('operationStatusはgreen/yellow/red'));
    expect(morning, contains('actionIdはアプリが生成'));
    expect(morning, contains('単一のPlain Textコードブロック'));
  });

  test(
    'training instruction documents the formal cardio snapshot contract',
    () {
      final training = ReportSyncInstructionProviderRegistry.standard()
          .forType(ReportSyncExchangeType.training)
          .buildInstruction(operationDate: '2026-08-02');

      for (final field in const [
        'estimatedCaloriesKcal',
        'weightSnapshotKg',
        'calculationMethod',
        'calculationVersion',
      ]) {
        expect(training, contains(field));
      }
      expect(training, contains('all four fields together'));
      expect(training, contains('set all four fields to null'));
      expect(training, contains('calculationMethod must be metsAcsmV1'));
      expect(training, contains('calculationVersion must be 1'));
      expect(training, contains('leaving the other snapshot fields null'));
      expect(training, contains('calculation weight cannot be confirmed'));
      expect(training, contains('Never copy calories alone'));
      expect(training, contains('infer weight'));
      expect(training, contains('without independent rounding'));
      expect(training, contains('exactly one fenced Plain Text code block'));
      expect(training, contains('schemaVersion "2.0"'));
      expect(training, contains('Set packageDigest to null'));
      expect(training, contains('operationDate "2026-08-02" exactly'));
      expect(training, contains('Do not invent facts'));
    },
  );

  test('accepts a standalone response without legacy request identity', () {
    final response = codec.create(
      direction: ReportSyncDirection.response,
      exchangeType: ReportSyncExchangeType.food,
      exchangeId: 'response-food',
      operationDate: '2026-08-02',
      createdAt: DateTime.utc(2026, 8, 2),
      payload: const {
        'operationDate': '2026-08-02',
        'meals': [
          {
            'mealId': 'water-1',
            'mealType': 'Water',
            'items': <Object?>[],
            'memo': null,
            'waterMl': 250,
          },
        ],
      },
    );
    expect(codec.decode(codec.encode(response)).requestId, isNull);
  });

  test(
    'strict response parsing rejects non-JSON and invalid payload types',
    () {
      for (final input in const [
        '```json\n{}\n```',
        'Explanation {"value":1}',
        '[]',
        '{} {}',
        ' {}',
        '{}\n',
        '“value”',
      ]) {
        expect(() => codec.decode(input), throwsA(isA<ReportSyncException>()));
      }
      final response = codec.create(
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.food,
        exchangeId: 'response-food-invalid',
        operationDate: '2026-08-02',
        createdAt: DateTime.utc(2026, 8, 2),
        payload: const {'operationDate': '2026-08-02', 'meals': '0'},
      );
      expect(
        () => codec.decode(codec.encode(response)),
        throwsA(isA<ReportSyncException>()),
      );
    },
  );

  test(
    'defines active exchange types, two directions, and preserves null vs zero',
    () {
      expect(ReportSyncExchangeType.values.map((value) => value.stableId), [
        'training',
        'food',
        'morningBrief',
      ]);
      expect(ReportSyncDirection.values.map((value) => value.stableId), [
        'request',
        'response',
      ]);
      expect(
        ReportSyncCanonicalService.digest({'value': null}),
        isNot(ReportSyncCanonicalService.digest({'value': 0})),
      );
    },
  );
}

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

ReportSyncHistory _history({
  int recordVersion = ReportSyncHistory.currentRecordVersion,
  int? received,
  int? selected,
  int? imported,
  int? conflict,
  int? excluded,
}) => ReportSyncHistory(
  exchangeId: 'food-history-$recordVersion',
  recordVersion: recordVersion,
  exchangeType: ReportSyncExchangeType.food,
  direction: ReportSyncDirection.response,
  operationDate: '2026-08-02',
  requestId: 'food-history-$recordVersion',
  requestDigest: _digest,
  startedAt: DateTime.utc(2026, 8, 2),
  completedAt: DateTime.utc(2026, 8, 2),
  result: ReportSyncHistoryResult.success,
  packageDigest: _digest,
  receivedMealCount: received,
  selectedMealCount: selected,
  importedMealCount: imported,
  conflictMealCount: conflict,
  excludedMealCount: excluded,
);
