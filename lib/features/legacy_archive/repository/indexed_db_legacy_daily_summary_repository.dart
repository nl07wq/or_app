import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../report_sync/services/report_sync_canonical_service.dart';
import '../models/dns_archive_models.dart';
import 'legacy_daily_summary_repository.dart';

class IndexedDbLegacyDailySummaryRepository
    implements LegacyDailySummaryRepository {
  final IndexedDbDatabase database;
  const IndexedDbLegacyDailySummaryRepository(this.database);

  @override
  Future<LegacyDailySummaryRecord> create(LegacyDailySummaryRecord record) =>
      database.runTransaction(
        storeNames: const [IndexedDbStoreNames.legacyDailySummaryRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final encoded = record.toRecord();
          final existing = await transaction.findById(
            IndexedDbStoreNames.legacyDailySummaryRecords,
            record.localDate,
          );
          if (existing != null) {
            if (_domainEqual(existing, encoded)) {
              return LegacyDailySummaryRecord.fromRecord(existing);
            }
            throw LegacyDailySummaryConflict(record.localDate);
          }
          await transaction.put(
            IndexedDbStoreNames.legacyDailySummaryRecords,
            encoded,
          );
          final readBack = await transaction.findById(
            IndexedDbStoreNames.legacyDailySummaryRecords,
            record.localDate,
          );
          if (readBack == null || !_domainEqual(readBack, encoded)) {
            throw StateError(
              'Legacy Daily Summary read-back verification failed.',
            );
          }
          return LegacyDailySummaryRecord.fromRecord(readBack);
        },
      );

  @override
  Future<LegacyDailySummaryRecord?> readByLocalDate(String localDate) async {
    final value = await database.findById(
      IndexedDbStoreNames.legacyDailySummaryRecords,
      localDate,
    );
    return value == null ? null : LegacyDailySummaryRecord.fromRecord(value);
  }

  @override
  Future<List<LegacyDailySummaryRecord>> list() async {
    final values = [
      for (final record in await database.findAll(
        IndexedDbStoreNames.legacyDailySummaryRecords,
      ))
        LegacyDailySummaryRecord.fromRecord(record),
    ];
    values.sort((a, b) => b.localDate.compareTo(a.localDate));
    return List.unmodifiable(values);
  }

  @override
  Future<List<LegacyDailySummaryRecord>> readDateRange(
    String start,
    String end,
  ) async => List.unmodifiable(
    (await list()).where(
      (record) =>
          record.localDate.compareTo(start) >= 0 &&
          record.localDate.compareTo(end) <= 0,
    ),
  );

  static bool domainEqual(
    Map<String, Object?> first,
    Map<String, Object?> second,
  ) => _domainEqual(first, second);
  static bool _domainEqual(
    Map<String, Object?> first,
    Map<String, Object?> second,
  ) {
    Map<String, Object?> canonical(Map<String, Object?> value) =>
        Map.of(value)..remove('importedAt');
    return ReportSyncCanonicalService.encode(canonical(first)) ==
        ReportSyncCanonicalService.encode(canonical(second));
  }
}
