import '../../../core/models/activity_data.dart';
import '../../../core/models/bowel_movement_record.dart';
import '../../../core/models/digestive_event.dart';
import '../../../core/services/daily_log_mutation_guard.dart';
import '../../../core/services/persistence_access.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/activity_draft.dart';
import '../models/persisted_activity_record.dart';

class ActivityDraftFinalizeService {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  ActivityDraftFinalizeService(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<ActivityData> finalize({required ActivityDraft draft}) async {
    PersistenceAccess.requireWrite('activityDraft.finalize');
    final localDate = draft.localDate;
    final date = DateTime.parse(localDate);
    await DailyLogMutationGuard.assertDateMutable(date);

    try {
      return await _database.runTransaction<ActivityData>(
        storeNames: const [
          IndexedDbStoreNames.activityRecords,
          IndexedDbStoreNames.activityDrafts,
        ],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final storedDraft = await transaction.findById(
            IndexedDbStoreNames.activityDrafts,
            draft.id,
          );
          if (storedDraft == null) {
            throw StateError('ACTIVITY Draft no longer exists.');
          }
          final source = ActivityDraft.fromRecord(storedDraft);
          final timestamp = _now();
          final data = _activityFromDraft(source, timestamp: timestamp);

          final canonicalId = PersistedActivityRecord.canonicalId(localDate);
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.activityRecords,
            canonicalId,
          );
          final existing = existingValue == null
              ? null
              : PersistedActivityRecord.fromRecord(existingValue);
          if (existing != null) {
            throw StateError(
              'A formal ACTIVITY record already exists for $localDate.',
            );
          }

          final previousDate = DateTime(
            data.date.year,
            data.date.month,
            data.date.day - 1,
          );
          final previousLocalDate = PersistedActivityRecord.localDateFromDate(
            previousDate,
          );
          final previousValue = await transaction.findById(
            IndexedDbStoreNames.activityRecords,
            PersistedActivityRecord.canonicalId(previousLocalDate),
          );
          final previous = previousValue == null
              ? null
              : PersistedActivityRecord.fromRecord(previousValue);

          final normalized = data.copyWith(
            id: localDate,
            officialSteps: data.officialStepsFor(previous?.data.carryOver ?? 0),
            updatedAt: timestamp,
          );
          final record = PersistedActivityRecord(
            id: canonicalId,
            localDate: localDate,
            createdAt: timestamp.toUtc(),
            updatedAt: timestamp.toUtc(),
            canonicalDate: localDate,
            recordKind: ActivityRecordKind.canonical,
            data: normalized,
          );

          await transaction.put(
            IndexedDbStoreNames.activityRecords,
            record.toRecord(),
          );
          await transaction.deleteById(
            IndexedDbStoreNames.activityDrafts,
            draft.id,
          );
          return normalized;
        },
      );
    } on ConfirmedDailyLogException {
      rethrow;
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'activityDraft.finalize',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'activityDraft.finalize',
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
  }

  static ActivityData _activityFromDraft(
    ActivityDraft draft, {
    required DateTime timestamp,
  }) {
    final measuredSteps = int.tryParse(draft.measuredStepsInput.trim());
    final carryOverText = draft.carryOverInput.trim();
    final carryOver = carryOverText.isEmpty ? 0 : int.tryParse(carryOverText);
    if (measuredSteps == null ||
        measuredSteps < 0 ||
        carryOver == null ||
        carryOver < 0) {
      throw const FormatException('Invalid ACTIVITY Draft step values.');
    }

    final events = <DigestiveEvent>[];
    for (final event in draft.digestiveEvents) {
      if (event.amount == null) {
        throw FormatException('排便イベント${event.sequence}の量を入力してください');
      }
      if (event.amount! > 0 && event.shape == null) {
        throw FormatException('排便イベント${event.sequence}の形状を入力してください');
      }
      if (event.amount! > 0 && event.relief == null) {
        throw FormatException('排便イベント${event.sequence}のスッキリ感を入力してください');
      }
      events.add(
        DigestiveEvent(
          id: event.id,
          sequence: event.sequence,
          amount: event.amount!,
          shape: event.shape,
          relief: event.relief,
          recordedAt: event.recordedAt,
        ),
      );
    }

    return ActivityData(
      date: DateTime.parse(draft.localDate),
      measuredSteps: measuredSteps,
      carryOver: carryOver,
      bowelMovement: const BowelMovementRecord.unconfirmed(),
      digestiveEvents: events,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}
