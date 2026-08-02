import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../models/daily_debrief_record.dart';
import '../models/morning_brief_record.dart';
import '../models/report_sync_history.dart';
import '../models/report_sync_issue.dart';
import '../services/report_sync_canonical_service.dart';
import 'daily_debrief_repository.dart';
import 'morning_brief_repository.dart';
import 'report_sync_history_repository.dart';

abstract class _ImmutableRepository<T> {
  final IndexedDbDatabase database;
  final String storeName;
  const _ImmutableRepository(this.database, this.storeName);
  String id(T value);
  T decode(Map<String, Object?> value);
  Map<String, Object?> encode(T value);

  Future<T> createValue(T value) => database.runTransaction(
    storeNames: [storeName],
    mode: IndexedDbTransactionMode.readWrite,
    action: (transaction) async {
      final validated = decode(encode(value));
      final existing = await transaction.findById(storeName, id(value));
      if (existing != null) {
        if (_equal(existing, encode(validated))) return decode(existing);
        throw const ReportSyncException(
          ReportSyncIssueCode.recordConflict,
          'Immutable REPORT SYNC record conflict.',
        );
      }
      await transaction.put(storeName, encode(validated));
      final stored = await transaction.findById(storeName, id(value));
      if (stored == null || !_equal(stored, encode(validated))) {
        throw const ReportSyncException(
          ReportSyncIssueCode.integrityFailure,
          'Read-back verification failed.',
        );
      }
      return decode(stored);
    },
  );

  Future<T?> read(String value) async {
    final record = await database.findById(storeName, value);
    return record == null ? null : decode(record);
  }

  Future<List<T>> all() async => [
    for (final value in await database.findAll(storeName)) decode(value),
  ];
  static bool _equal(Object? first, Object? second) =>
      ReportSyncCanonicalService.encode(first) ==
      ReportSyncCanonicalService.encode(second);
}

class IndexedDbMorningBriefRepository
    extends _ImmutableRepository<MorningBriefRecord>
    implements MorningBriefRepository {
  const IndexedDbMorningBriefRepository(IndexedDbDatabase database)
    : super(database, IndexedDbStoreNames.morningBriefRecords);
  @override
  String id(MorningBriefRecord value) => value.localDate;
  @override
  MorningBriefRecord decode(Map<String, Object?> value) =>
      MorningBriefRecord.fromRecord(value);
  @override
  Map<String, Object?> encode(MorningBriefRecord value) => value.toRecord();
  @override
  Future<MorningBriefRecord> create(MorningBriefRecord record) =>
      createValue(record);
  @override
  Future<MorningBriefRecord?> readByLocalDate(String localDate) =>
      read(localDate);
  @override
  Future<List<MorningBriefRecord>> list() async {
    final values = await all();
    values.sort((a, b) => b.localDate.compareTo(a.localDate));
    return List.unmodifiable(values);
  }
}

class IndexedDbDailyDebriefRepository
    extends _ImmutableRepository<DailyDebriefRecord>
    implements DailyDebriefRepository {
  const IndexedDbDailyDebriefRepository(IndexedDbDatabase database)
    : super(database, IndexedDbStoreNames.dailyDebriefRecords);
  @override
  String id(DailyDebriefRecord value) => value.localDate;
  @override
  DailyDebriefRecord decode(Map<String, Object?> value) =>
      DailyDebriefRecord.fromRecord(value);
  @override
  Map<String, Object?> encode(DailyDebriefRecord value) => value.toRecord();
  @override
  Future<DailyDebriefRecord> create(DailyDebriefRecord record) =>
      createValue(record);
  @override
  Future<DailyDebriefRecord?> readByLocalDate(String localDate) =>
      read(localDate);
  @override
  Future<List<DailyDebriefRecord>> list() async {
    final values = await all();
    values.sort((a, b) => b.localDate.compareTo(a.localDate));
    return List.unmodifiable(values);
  }
}

class IndexedDbReportSyncHistoryRepository
    extends _ImmutableRepository<ReportSyncHistory>
    implements ReportSyncHistoryRepository {
  const IndexedDbReportSyncHistoryRepository(IndexedDbDatabase database)
    : super(database, IndexedDbStoreNames.reportSyncHistory);
  @override
  String id(ReportSyncHistory value) => value.exchangeId;
  @override
  ReportSyncHistory decode(Map<String, Object?> value) =>
      ReportSyncHistory.fromRecord(value);
  @override
  Map<String, Object?> encode(ReportSyncHistory value) => value.toRecord();
  @override
  Future<ReportSyncHistory> create(ReportSyncHistory history) =>
      createValue(history);
  @override
  Future<ReportSyncHistory?> readById(String exchangeId) => read(exchangeId);
  @override
  Future<List<ReportSyncHistory>> list() async {
    final values = await all();
    values.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return List.unmodifiable(values);
  }
}
