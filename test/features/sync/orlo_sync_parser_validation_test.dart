import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/sync/models/orlo_sync_models.dart';
import 'package:or_app/features/sync/services/orlo_sync_parser.dart';
import 'package:or_app/features/sync/services/orlo_sync_registry.dart';
import 'package:or_app/features/sync/services/orlo_sync_validator.dart';

void main() {
  final valid = <String, Object?>{
    'format': 'orlo-sync',
    'envelopeVersion': 1,
    'schemaVersion': '1.0',
    'dataType': 'training',
    'packageId': 'pkg-1',
    'idempotencyKey': 'key-1',
    'source': {
      'type': 'chatgpt',
      'generatedAt': '2026-08-01T00:00:00.000Z',
      'producer': 'ChatGPT',
      'producerVersion': null,
    },
    'operationDate': '2026-08-01',
    'payload': <String, Object?>{'records': <Object?>[]},
  };

  group('ORLO Sync parse', () {
    const parser = OrloSyncParser(maximumUtf8Bytes: 2048);

    test('accepts an object and a JSON-only markdown fence', () {
      expect(parser.parse(jsonEncode(valid)), valid);
      expect(parser.parse('```json\n${jsonEncode(valid)}\n```'), valid);
    });

    test(
      'rejects empty, malformed, arrays, trailing garbage, and large input',
      () {
        for (final value in ['', '{', '[]', '${jsonEncode(valid)} trailing']) {
          expect(
            () => parser.parse(value),
            throwsA(isA<OrloSyncParseException>()),
          );
        }
        expect(
          () => const OrloSyncParser(maximumUtf8Bytes: 4).parse('{"a":1}'),
          throwsA(isA<OrloSyncParseException>()),
        );
      },
    );
  });

  group('ORLO Sync validation', () {
    test(
      'round-trips the formal envelope while unavailable adapter blocks import',
      () {
        final output = OrloSyncValidator(
          OrloSyncTypeRegistry(),
        ).validate(valid);
        expect(output.envelope?.toJson(), valid);
        expect(output.issues.single.code, 'adapterUnavailable');
        expect(output.issues.single.severity, SyncIssueSeverity.blockingError);
      },
    );

    test(
      'rejects missing fields, types, unknown values, versions, dates, and fields',
      () {
        final cases = <Map<String, Object?>>[
          {...valid}..remove('packageId'),
          {...valid, 'envelopeVersion': '1'},
          {...valid, 'envelopeVersion': 2},
          {...valid, 'schemaVersion': '2.0'},
          {...valid, 'dataType': 'unknown'},
          {...valid, 'operationDate': '2026-02-30'},
          {...valid, 'packageId': ''},
          {...valid, 'extra': true},
        ];
        for (final value in cases) {
          final output = OrloSyncValidator(
            OrloSyncTypeRegistry(),
          ).validate(value);
          expect(output.envelope, isNull);
          expect(output.issues, isNotEmpty);
        }
      },
    );
  });
}
