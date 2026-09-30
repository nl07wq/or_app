import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/schedule_record.dart';
import 'schedule_repository.dart';

class IndexedDbScheduleRepository implements ScheduleRepository {
  IndexedDbScheduleRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  @override
  Future<List<ScheduleRecord>> findForDate(String localDate) async =>
      (await _all()).where((record) => record.localDate == localDate).toList();

  @override
  Future<List<ScheduleRecord>> findForMonth(DateTime month) async {
    final prefix =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return (await _all())
        .where((record) => record.localDate.startsWith(prefix))
        .toList();
  }

  @override
  Future<ScheduleRecord?> findWorkForDate(String localDate) async {
    final work = (await findForDate(localDate))
        .where(
          (record) =>
              record.kind == ScheduleEntryKind.schedule &&
              record.type == ScheduleType.work,
        )
        .toList();
    if (work.length > 1) {
      throw StateError('Multiple WORK schedules exist for $localDate.');
    }
    return work.isEmpty ? null : work.single;
  }

  @override
  Future<void> save(ScheduleRecord record) async {
    if (record.title.trim().isEmpty) {
      throw ArgumentError.value(record.title, 'title');
    }
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.scheduleRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          if (record.kind == ScheduleEntryKind.schedule &&
              record.type == ScheduleType.work) {
            final existingWork =
                (await transaction.findAll(IndexedDbStoreNames.scheduleRecords))
                    .map(ScheduleRecord.fromRecord)
                    .any(
                      (value) =>
                          value.id != record.id &&
                          value.localDate == record.localDate &&
                          value.kind == ScheduleEntryKind.schedule &&
                          value.type == ScheduleType.work,
                    );
            if (existingWork) {
              throw StateError('A WORK schedule already exists for this date.');
            }
          }
          final existing = await transaction.findById(
            IndexedDbStoreNames.scheduleRecords,
            record.id,
          );
          final timestamp = _now().toUtc();
          await transaction.put(
            IndexedDbStoreNames.scheduleRecords,
            ScheduleRecord(
              id: record.id,
              localDate: record.localDate,
              type: record.type,
              title: record.title.trim(),
              kind: record.kind,
              allDay: record.allDay,
              startTime: record.startTime,
              endTime: record.endTime,
              breakDuration: record.breakDuration,
              memo: record.memo,
              completed: record.completed,
              createdAt: existing == null
                  ? timestamp
                  : ScheduleRecord.fromRecord(existing).createdAt,
              updatedAt: timestamp,
            ).toRecord(),
          );
        },
      );
    } catch (error) {
      throw RepositoryException(operation: 'schedule.save', cause: error);
    }
  }

  @override
  Future<void> delete(String id) =>
      _database.deleteById(IndexedDbStoreNames.scheduleRecords, id);

  Future<List<ScheduleRecord>> _all() async {
    try {
      final records = (await _database.findAll(
        IndexedDbStoreNames.scheduleRecords,
      )).map(ScheduleRecord.fromRecord).toList();
      records.sort(
        (a, b) => a.localDate == b.localDate
            ? a.id.compareTo(b.id)
            : a.localDate.compareTo(b.localDate),
      );
      return List.unmodifiable(records);
    } catch (error) {
      throw RepositoryException(operation: 'schedule.read', cause: error);
    }
  }
}
