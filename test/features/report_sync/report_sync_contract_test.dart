import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_issue.dart';
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

  test('requires confirmation digest only on Daily Debrief response', () {
    final response = codec.create(
      direction: ReportSyncDirection.response,
      exchangeType: ReportSyncExchangeType.dailyDebrief,
      exchangeId: 'exchange-3',
      requestId: 'request-3',
      operationDate: '2026-08-02',
      createdAt: DateTime.utc(2026, 8, 2),
      requestDigest: digest,
      payload: const {},
    );
    expect(
      () => codec.decode(codec.encode(response)),
      throwsA(isA<ReportSyncException>()),
    );
  });

  test('registry provides all four JSON-only instructions', () {
    final registry = ReportSyncInstructionProviderRegistry.standard();
    for (final type in ReportSyncExchangeType.values) {
      final text = registry.forType(type).buildInstruction();
      expect(text, contains(type.stableId));
      expect(text, contains('exactly one JSON object'));
      expect(text, contains('Do not invent facts'));
    }
  });

  test(
    'defines four exchange types, two directions, and preserves null vs zero',
    () {
      expect(ReportSyncExchangeType.values.map((value) => value.stableId), [
        'training',
        'food',
        'morningBrief',
        'dailyDebrief',
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
