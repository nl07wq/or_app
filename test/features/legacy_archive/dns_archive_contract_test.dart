import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/legacy_archive/models/dns_archive_models.dart';
import 'package:or_app/features/legacy_archive/repository/indexed_db_legacy_daily_summary_repository.dart';
import 'package:or_app/features/legacy_archive/repository/legacy_daily_summary_repository.dart';
import 'package:or_app/features/legacy_archive/services/dns_archive_codecs.dart';
import 'package:or_app/features/legacy_archive/services/dns_archive_converter.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 2);

  test('splits concatenated DNS text only at unambiguous boundaries', () {
    final package = const DnsSourceCodec().splitConcatenated(
      sourcePackageId: 'dns-package',
      text: 'DNS-2026-07-31\nA\nDNS-2026-08-01\nB',
      createdAt: createdAt,
    );
    expect(package.records, hasLength(2));
    expect(package.records.first.rawText, contains('2026-07-31'));
    expect(
      () => const DnsSourceCodec().splitConcatenated(
        sourcePackageId: 'dns-package',
        text: 'ambiguous\nDNS-2026-08-01\nB',
        createdAt: createdAt,
      ),
      throwsFormatException,
    );
  });

  test('normalized codec preserves estimated and range values', () {
    final package = DnsNormalizedPackage(
      sourcePackageId: 'dns-package',
      generatedAt: createdAt,
      records: [
        DnsNormalizedRecord(
          sourceRecordId: 'source-1',
          operationDate: '2026-08-01',
          parseStatus: DnsParseStatus.parsedWithWarnings,
          data: {
            'body': {
              'weightKg': const DnsRangeValue(70, 71, true).toJson(),
              'bodyFatPercent': null,
            },
            'nutrition': null,
            'hydration': null,
            'activity': null,
            'work': null,
            'operation': null,
          },
          warnings: const [
            DnsWarning(
              code: DnsWarningCode.rangeValue,
              message: 'Range retained.',
            ),
          ],
          unmappedFragments: const ['unknown fragment'],
        ),
      ],
    );
    final codec = const DnsNormalizedCodec();
    final decoded = codec.decode(codec.encode(package));
    expect(
      decoded.records.single.warnings.single.code,
      DnsWarningCode.rangeValue,
    );
    expect(decoded.records.single.unmappedFragments, ['unknown fragment']);
  });

  test('normalized codec rejects numeric strings and unknown fields', () {
    final valid =
        jsonDecode(
              File(
                'test/fixtures/legacy_archive/dns_normalized.json',
              ).readAsStringSync(),
            )
            as Map;
    final record = Map<String, Object?>.from(
      (valid['records'] as List).single as Map,
    );
    final data = Map<String, Object?>.from(record['data'] as Map);
    data['body'] = {'weightKg': '70', 'bodyFatPercent': null};
    record['data'] = data;
    expect(
      () => const DnsNormalizedCodec().decode(
        jsonEncode({
          ...valid,
          'records': [record],
        }),
      ),
      throwsFormatException,
    );
    expect(
      () => const DnsNormalizedCodec().decode(
        jsonEncode({...valid, 'extra': true}),
      ),
      throwsFormatException,
    );
  });

  test(
    'converter previews create, no-op and conflict and applies atomically',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbLegacyDailySummaryRepository(database);
      final converter = DnsArchiveConverter(
        database: database,
        repository: repository,
        clock: () => createdAt.add(const Duration(hours: 1)),
      );
      final source = DnsSourcePackage(
        sourcePackageId: 'dns-package',
        createdAt: createdAt,
        records: const [
          DnsSourceRecord(
            sourceRecordId: 'source-1',
            sourceOrder: 0,
            rawText: 'DNS-2026-08-01\nWeight 70',
          ),
        ],
      );
      final normalized = DnsNormalizedPackage(
        sourcePackageId: 'dns-package',
        generatedAt: createdAt,
        records: const [
          DnsNormalizedRecord(
            sourceRecordId: 'source-1',
            operationDate: '2026-08-01',
            parseStatus: DnsParseStatus.parsed,
            data: {
              'body': {
                'weightKg': {'value': 70.0, 'isEstimated': false},
                'bodyFatPercent': null,
              },
              'nutrition': null,
              'hydration': null,
              'activity': null,
              'work': null,
              'operation': null,
            },
            warnings: [],
            unmappedFragments: [],
          ),
        ],
      );
      final first = await converter.preview(
        source: source,
        normalized: normalized,
      );
      expect(first.createCount, 1);
      await converter.apply(first);
      expect(
        (await repository.readByLocalDate('2026-08-01'))?.sourceTextDigest,
        hasLength(64),
      );
      final second = await converter.preview(
        source: source,
        normalized: normalized,
      );
      expect(second.noChangeCount, 1);
      final changed = DnsNormalizedPackage(
        sourcePackageId: 'dns-package',
        generatedAt: createdAt,
        records: [
          DnsNormalizedRecord(
            sourceRecordId: 'source-1',
            operationDate: '2026-08-01',
            parseStatus: DnsParseStatus.parsed,
            data: const {
              'body': {
                'weightKg': {'value': 71.0, 'isEstimated': false},
                'bodyFatPercent': null,
              },
              'nutrition': null,
              'hydration': null,
              'activity': null,
              'work': null,
              'operation': null,
            },
            warnings: const [],
            unmappedFragments: const [],
          ),
        ],
      );
      expect(
        (await converter.preview(
          source: source,
          normalized: changed,
        )).conflictCount,
        1,
      );
    },
  );

  test('repository is immutable and supports date ranges', () async {
    final repository = IndexedDbLegacyDailySummaryRepository(
      FakeIndexedDbDatabase(),
    );
    LegacyDailySummaryRecord record(
      String date,
      String source,
    ) => LegacyDailySummaryRecord(
      localDate: date,
      sourceRecordId: source,
      sourcePackageId: 'package',
      body: null,
      nutrition: null,
      hydration: null,
      activity: null,
      work: null,
      operation: null,
      warnings: const [],
      unmappedFragments: const [],
      sourceTextDigest:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      createdAt: createdAt,
      importedAt: createdAt,
    );
    await repository.create(record('2026-08-01', 'one'));
    await repository.create(record('2026-08-02', 'two'));
    expect(
      await repository.readDateRange('2026-08-02', '2026-08-03'),
      hasLength(1),
    );
    expect(
      () => repository.create(record('2026-08-01', 'changed')),
      throwsA(isA<LegacyDailySummaryConflict>()),
    );
  });

  test(
    'formal DNS fixtures round-trip and map to the legacy record contract',
    () {
      final source = const DnsSourceCodec().decode(
        File('test/fixtures/legacy_archive/dns_source.json').readAsStringSync(),
      );
      final normalized = const DnsNormalizedCodec().decode(
        File(
          'test/fixtures/legacy_archive/dns_normalized.json',
        ).readAsStringSync(),
      );
      expect(source.sourcePackageId, normalized.sourcePackageId);
      expect(
        LegacyDailySummaryRecord.fromRecord(
          Map<String, Object?>.from(
            (jsonDecode(
                  File(
                    'test/fixtures/legacy_archive/legacy_daily_summary.json',
                  ).readAsStringSync(),
                )
                as Map),
          ),
        ).localDate,
        '2026-08-01',
      );
    },
  );
}
