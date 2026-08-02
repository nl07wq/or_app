import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../report_sync/services/report_sync_canonical_service.dart';
import '../models/dns_archive_models.dart';
import '../repository/indexed_db_legacy_daily_summary_repository.dart';
import '../repository/legacy_daily_summary_repository.dart';

class DnsArchiveConverter {
  final IndexedDbDatabase database;
  final LegacyDailySummaryRepository repository;
  final DateTime Function() clock;
  const DnsArchiveConverter({
    required this.database,
    required this.repository,
    required this.clock,
  });

  Future<DnsConversionPreview> previewNormalized(
    DnsNormalizedPackage normalized,
  ) {
    final source = DnsSourcePackage(
      sourcePackageId: normalized.sourcePackageId,
      createdAt: normalized.generatedAt,
      records: [
        for (var index = 0; index < normalized.records.length; index++)
          DnsSourceRecord(
            sourceRecordId: normalized.records[index].sourceRecordId,
            sourceOrder: index,
            rawText: ReportSyncCanonicalService.encode(
              normalized.records[index].toJson(),
            ),
          ),
      ],
    );
    return preview(source: source, normalized: normalized);
  }

  Future<DnsConversionPreview> preview({
    required DnsSourcePackage source,
    required DnsNormalizedPackage normalized,
  }) async {
    final blocking = <String>[];
    final warnings = <DnsWarning>[];
    final records = <LegacyDailySummaryRecord>[];
    if (source.sourcePackageId != normalized.sourcePackageId) {
      blocking.add('sourcePackageId mismatch.');
    }
    final sourceById = {
      for (final record in source.records) record.sourceRecordId: record,
    };
    final normalizedIds = <String>{};
    final dates = <String>{};
    var conflicts = 0;
    var noChanges = 0;
    var creates = 0;
    for (final value in normalized.records) {
      if (!normalizedIds.add(value.sourceRecordId)) {
        blocking.add('Duplicate sourceRecordId: ${value.sourceRecordId}.');
        continue;
      }
      final sourceRecord = sourceById[value.sourceRecordId];
      if (sourceRecord == null) {
        blocking.add('Unknown sourceRecordId: ${value.sourceRecordId}.');
        continue;
      }
      warnings.addAll(value.warnings);
      if (value.parseStatus == DnsParseStatus.blocked ||
          value.operationDate == null) {
        blocking.add('Blocked normalized record: ${value.sourceRecordId}.');
        continue;
      }
      if (!dates.add(value.operationDate!)) {
        blocking.add('Duplicate operationDate: ${value.operationDate}.');
        continue;
      }
      final record = _convert(source, sourceRecord, value);
      records.add(record);
      final existing = await repository.readByLocalDate(record.localDate);
      if (existing == null) {
        creates++;
      } else if (IndexedDbLegacyDailySummaryRepository.domainEqual(
        existing.toRecord(),
        record.toRecord(),
      )) {
        noChanges++;
      } else {
        conflicts++;
      }
    }
    for (final id in sourceById.keys.toSet().difference(normalizedIds)) {
      blocking.add('Missing normalized record: $id.');
    }
    final sortedDates = records.map((record) => record.localDate).toList()
      ..sort();
    final missing = <String, int>{};
    for (final record in records) {
      for (final entry in {
        'body': record.body,
        'nutrition': record.nutrition,
        'hydration': record.hydration,
        'activity': record.activity,
        'work': record.work,
        'operation': record.operation,
      }.entries) {
        if (entry.value == null) {
          missing[entry.key] = (missing[entry.key] ?? 0) + 1;
        }
      }
    }
    return DnsConversionPreview(
      sourcePackageId: source.sourcePackageId,
      sourceRecordCount: source.records.length,
      parsedCount: records.length,
      warningCount: warnings.length,
      blockingCount: blocking.length,
      createCount: creates,
      noChangeCount: noChanges,
      conflictCount: conflicts,
      operationDateRange: sortedDates.isEmpty
          ? null
          : '${sortedDates.first}/${sortedDates.last}',
      missingFieldSummary: Map.unmodifiable(missing),
      warnings: List.unmodifiable(warnings),
      blockingIssues: List.unmodifiable(blocking),
      records: List.unmodifiable(records),
    );
  }

  Future<List<LegacyDailySummaryRecord>> apply(
    DnsConversionPreview preview,
  ) async {
    if (!preview.canApply) {
      throw StateError('DNS conversion contains blocking issues or conflicts.');
    }
    return database.runTransaction(
      storeNames: const [IndexedDbStoreNames.legacyDailySummaryRecords],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        for (final record in preview.records) {
          final encoded = record.toRecord();
          final existing = await transaction.findById(
            IndexedDbStoreNames.legacyDailySummaryRecords,
            record.localDate,
          );
          if (existing != null &&
              !IndexedDbLegacyDailySummaryRepository.domainEqual(
                existing,
                encoded,
              )) {
            throw LegacyDailySummaryConflict(record.localDate);
          }
          if (existing == null) {
            await transaction.put(
              IndexedDbStoreNames.legacyDailySummaryRecords,
              encoded,
            );
          }
        }
        for (final record in preview.records) {
          final readBack = await transaction.findById(
            IndexedDbStoreNames.legacyDailySummaryRecords,
            record.localDate,
          );
          if (readBack == null ||
              !IndexedDbLegacyDailySummaryRepository.domainEqual(
                readBack,
                record.toRecord(),
              )) {
            throw StateError('DNS conversion read-back verification failed.');
          }
        }
        return List.unmodifiable(preview.records);
      },
    );
  }

  LegacyDailySummaryRecord _convert(
    DnsSourcePackage package,
    DnsSourceRecord source,
    DnsNormalizedRecord normalized,
  ) {
    Map<String, Object?>? section(String name) {
      final value = normalized.data[name];
      return value == null ? null : Map<String, Object?>.from(value as Map);
    }

    return LegacyDailySummaryRecord(
      localDate: normalized.operationDate!,
      sourceRecordId: source.sourceRecordId,
      sourcePackageId: package.sourcePackageId,
      body: section('body'),
      nutrition: section('nutrition'),
      hydration: section('hydration'),
      activity: section('activity'),
      work: section('work'),
      operation: section('operation'),
      warnings: normalized.warnings,
      unmappedFragments: normalized.unmappedFragments,
      sourceTextDigest: ReportSyncCanonicalService.digestUtf8(source.rawText),
      createdAt: package.createdAt.toUtc(),
      importedAt: clock().toUtc(),
    );
  }
}

class DnsPreviewService {
  final DnsArchiveConverter converter;
  const DnsPreviewService(this.converter);
  Future<DnsConversionPreview> build(
    DnsSourcePackage source,
    DnsNormalizedPackage normalized,
  ) => converter.preview(source: source, normalized: normalized);
}
