import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/report_sync/models/status_report_sync_source.dart';
import 'package:or_app/features/report_sync/services/report_sync_canonical_service.dart';
import 'package:or_app/features/report_sync/services/status_report_sync_source_service.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const date = '2026-08-03';
  const previousDate = '2026-08-02';
  final firstExport = DateTime.utc(2026, 8, 3, 1);
  final secondExport = DateTime.utc(2026, 8, 3, 2);

  late FakeIndexedDbDatabase database;
  late StatusReportSyncSourceService service;

  setUp(() {
    database = FakeIndexedDbDatabase();
    service = StatusReportSyncSourceService(database);
  });

  test(
    'canonical current and exact previous day produce a ready source',
    () async {
      _seed(database, _record(date, weight: 80.2, bodyFat: 20.1));
      _seed(database, _record(previousDate, weight: 80.3, bodyFat: 20.2));

      final result = await service.generate(
        operationDate: date,
        exportedAt: firstExport,
      );

      expect(result.source.sourceRecordId, 'status:$date');
      expect(result.source.sourceRecordVersion, 1);
      expect(
        result.source.previousDayComparison.previousOperationDate,
        previousDate,
      );
      expect(
        result.source.previousDayComparison.previousStatusAvailable,
        isTrue,
      );
      expect(result.source.previousDayComparison.weightDifferenceKg, '-0.1');
      expect(
        result.source.previousDayComparison.bodyFatDifferencePoint,
        '-0.1',
      );
      expect(ReportSyncCanonicalService.isDigest(result.sourceDigest), isTrue);
    },
  );

  test(
    'missing current STATUS blocks export with statusSourceMissing',
    () async {
      await expectLater(
        service.generate(operationDate: date, exportedAt: firstExport),
        throwsA(_sourceError('statusSourceMissing')),
      );
    },
  );

  test('non-canonical current STATUS is rejected', () async {
    final raw = _record(date).toRecord();
    raw['recordKind'] = StatusRecordKind.legacyRevision.name;
    database.seed(IndexedDbStoreNames.statusRecords, 'status:$date', raw);

    await expectLater(
      service.generate(operationDate: date, exportedAt: firstExport),
      throwsA(_sourceError('statusSourceNotCanonical')),
    );
  });

  test('record and source date mismatch is rejected', () async {
    final raw = _record(date).toRecord();
    raw['localDate'] = previousDate;
    database.seed(IndexedDbStoreNames.statusRecords, 'status:$date', raw);

    await expectLater(
      service.generate(operationDate: date, exportedAt: firstExport),
      throwsA(_sourceError('statusSourceDateMismatch')),
    );
  });

  test('MorningData date mismatch is rejected', () async {
    final raw = _record(date).toRecord();
    (raw['data'] as Map)['date'] = '${previousDate}T08:00:00';
    database.seed(IndexedDbStoreNames.statusRecords, 'status:$date', raw);

    await expectLater(
      service.generate(operationDate: date, exportedAt: firstExport),
      throwsA(_sourceError('statusSourceDateMismatch')),
    );
  });

  test('missing required source field is not defaulted', () async {
    final raw = _record(date).toRecord();
    (raw['data'] as Map).remove('bodyFat');
    database.seed(IndexedDbStoreNames.statusRecords, 'status:$date', raw);

    await expectLater(
      service.generate(operationDate: date, exportedAt: firstExport),
      throwsA(
        isA<StatusReportSyncSourceException>()
            .having((error) => error.code, 'code', 'statusSourceIncomplete')
            .having((error) => error.field, 'field', 'bodyFat'),
      ),
    );
  });

  test('invalid required current value blocks export', () async {
    _seed(database, _record(date, sleepScore: 101));

    await expectLater(
      service.generate(operationDate: date, exportedAt: firstExport),
      throwsA(
        isA<StatusReportSyncSourceException>()
            .having((error) => error.code, 'code', 'statusSourceInvalid')
            .having((error) => error.field, 'field', 'sleepScore'),
      ),
    );
  });

  test('unknown work stable ID is rejected without fallback', () async {
    final raw = _record(date).toRecord();
    (raw['data'] as Map)['workType'] = 'unknown';
    database.seed(IndexedDbStoreNames.statusRecords, 'status:$date', raw);

    await expectLater(
      service.generate(operationDate: date, exportedAt: firstExport),
      throwsA(
        isA<StatusReportSyncSourceException>()
            .having((error) => error.code, 'code', 'statusSourceInvalid')
            .having((error) => error.field, 'field', 'workType'),
      ),
    );
  });

  test('only the exact calendar previous day is used', () async {
    _seed(database, _record(date));
    _seed(database, _record('2026-08-01', weight: 70));

    final result = await service.generate(
      operationDate: date,
      exportedAt: firstExport,
    );

    expect(
      result.source.previousDayComparison.previousStatusAvailable,
      isFalse,
    );
    expect(result.source.previousDayComparison.weightDifferenceKg, isNull);
    expect(
      result.plainText,
      contains('PREVIOUS DAY WEIGHT DIFFERENCE KG: (not available)'),
    );
  });

  test('invalid previous-day value does not block current export', () async {
    _seed(database, _record(date));
    _seed(database, _record(previousDate, weight: double.nan));

    final result = await service.generate(
      operationDate: date,
      exportedAt: firstExport,
    );

    expect(
      result.source.previousDayComparison.previousStatusAvailable,
      isFalse,
    );
    expect(result.source.previousDayComparison.weightDifferenceKg, isNull);
  });

  test(
    'same source fact has the same digest across export timestamps',
    () async {
      _seed(database, _record(date));
      _seed(database, _record(previousDate));

      final first = await service.generate(
        operationDate: date,
        exportedAt: firstExport,
      );
      final second = await service.generate(
        operationDate: date,
        exportedAt: secondExport,
      );

      expect(first.sourceDigest, second.sourceDigest);
      expect(first.canonicalText, second.canonicalText);
      expect(first.plainText, isNot(second.plainText));
      expect(first.canonicalText, isNot(contains('EXPORTED AT:')));
      expect(first.canonicalText, isNot(contains('SOURCE DIGEST:')));
    },
  );

  test('current STATUS change changes the digest', () async {
    _seed(database, _record(date, weight: 80));
    final first = await service.generate(
      operationDate: date,
      exportedAt: firstExport,
    );
    _seed(database, _record(date, weight: 81));
    final second = await service.generate(
      operationDate: date,
      exportedAt: secondExport,
    );

    expect(first.sourceDigest, isNot(second.sourceDigest));
  });

  test('previous STATUS change changes derived fact and digest', () async {
    _seed(database, _record(date, weight: 80));
    _seed(database, _record(previousDate, weight: 79));
    final first = await service.generate(
      operationDate: date,
      exportedAt: firstExport,
    );
    _seed(database, _record(previousDate, weight: 78));
    final second = await service.generate(
      operationDate: date,
      exportedAt: secondExport,
    );

    expect(first.source.previousDayComparison.weightDifferenceKg, '+1');
    expect(second.source.previousDayComparison.weightDifferenceKg, '+2');
    expect(first.sourceDigest, isNot(second.sourceDigest));
  });

  test('plain text has fixed sections, LF, and one final LF', () async {
    _seed(database, _record(date));

    final result = await service.generate(
      operationDate: date,
      exportedAt: firstExport,
    );

    expect(result.plainText, startsWith('OPERATION REBOOT\nFORMAT:'));
    expect(result.plainText, contains('\n[BODY]\n'));
    expect(result.plainText, contains('\n[RECOVERY]\n'));
    expect(result.plainText, contains('\n[CONDITION]\n'));
    expect(result.plainText, contains('\n[WORK]\n'));
    expect(result.plainText, contains('\n[CARRYOVER]\n'));
    expect(result.plainText, isNot(contains('\r')));
    expect(result.plainText, endsWith('\n'));
    expect(result.plainText, isNot(endsWith('\n\n')));
  });

  test('display source carries its own canonical digest', () async {
    _seed(database, _record(date));

    final result = await service.generate(
      operationDate: date,
      exportedAt: firstExport,
    );

    expect(result.plainText, contains('SOURCE DIGEST: ${result.sourceDigest}'));
    expect(
      ReportSyncCanonicalService.digestUtf8(result.canonicalText),
      result.sourceDigest,
    );
  });

  test('memo line endings normalize to the same canonical digest', () async {
    _seed(database, _record(date, memo: 'line one\r\nline two'));
    final crlf = await service.generate(
      operationDate: date,
      exportedAt: firstExport,
    );
    _seed(database, _record(date, memo: 'line one\nline two'));
    final lf = await service.generate(
      operationDate: date,
      exportedAt: secondExport,
    );

    expect(crlf.sourceDigest, lf.sourceDigest);
    expect(crlf.canonicalText, lf.canonicalText);
    expect(crlf.plainText, contains(r'NOTES: line one\nline two'));
  });

  test(
    'non-working status exports null shift fields without fabrication',
    () async {
      _seed(database, _record(date, workType: WorkType.holiday));

      final result = await service.generate(
        operationDate: date,
        exportedAt: firstExport,
      );

      expect(result.plainText, contains('WORK TYPE: holiday'));
      expect(result.plainText, contains('START TIME: (null)'));
      expect(result.plainText, contains('END TIME: (null)'));
      expect(result.plainText, contains('BREAK DURATION MINUTES: (null)'));
      expect(result.plainText, contains('WORK HOURS: 0.0'));
    },
  );

  test(
    'working status preserves stable ID and calculated shift facts',
    () async {
      _seed(database, _record(date, workType: WorkType.halfDay));

      final result = await service.generate(
        operationDate: date,
        exportedAt: firstExport,
      );

      expect(result.plainText, contains('WORK TYPE: halfDay'));
      expect(result.plainText, contains('START TIME: 11:00'));
      expect(result.plainText, contains('END TIME: 18:00'));
      expect(result.plainText, contains('BREAK DURATION MINUTES: 60'));
      expect(result.plainText, contains('WORK HOURS: 6.0'));
    },
  );
}

Matcher _sourceError(String code) => isA<StatusReportSyncSourceException>()
    .having((error) => error.code, 'code', code);

void _seed(FakeIndexedDbDatabase database, PersistedStatusRecord record) {
  database.seed(
    IndexedDbStoreNames.statusRecords,
    record.id,
    record.toRecord(),
  );
}

PersistedStatusRecord _record(
  String localDate, {
  double weight = 80,
  double bodyFat = 20,
  int sleepScore = 80,
  WorkType workType = WorkType.work,
  String memo = 'memo',
}) {
  final working = workType.isWorking;
  return PersistedStatusRecord(
    id: PersistedStatusRecord.canonicalId(localDate),
    localDate: localDate,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 1),
    canonicalDate: localDate,
    recordKind: StatusRecordKind.canonical,
    data: MorningData(
      date: '${localDate}T08:00:00',
      weight: weight,
      bodyFat: bodyFat,
      sleepHours: 7.5,
      sleepScore: sleepScore,
      footPain: 3,
      condition: 4,
      previousCarryoverConfirmed: true,
      workType: workType,
      workStart: working ? '11:00' : '',
      workEnd: working ? '18:00' : '',
      workBreak: working ? '01:00' : '',
      workHours: working ? 6 : 0,
      memo: memo,
    ),
  );
}
