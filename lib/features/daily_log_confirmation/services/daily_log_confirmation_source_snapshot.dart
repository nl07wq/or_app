import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../activity/models/persisted_activity_record.dart';
import '../../food/models/daily_meal_v2_models.dart';
import '../../food/models/persisted_daily_meal_v2_record.dart';
import '../../food/models/persisted_food_record.dart';
import '../../import_export/services/backup_canonical_codec.dart';
import '../../status/models/persisted_status_record.dart';
import '../../training/models/persisted_training_record.dart';
import '../models/daily_log_confirmation_lifecycle.dart';

class DailyLogConfirmationSourceIdentity {
  final String store;
  final String recordId;
  final int recordVersion;
  final String localDate;
  final String canonicalDigest;

  const DailyLogConfirmationSourceIdentity({
    required this.store,
    required this.recordId,
    required this.recordVersion,
    required this.localDate,
    required this.canonicalDigest,
  });

  Map<String, Object?> toJson() => {
    'store': store,
    'recordId': recordId,
    'recordVersion': recordVersion,
    'localDate': localDate,
    'canonicalDigest': canonicalDigest,
  };
}

class DailyLogConfirmationSourceSnapshot {
  final String localDate;
  final List<DailyLogConfirmationSourceIdentity> records;
  final DailyLogConfirmationSourceRecordVersions sourceRecordVersions;
  final String canonicalDigest;

  DailyLogConfirmationSourceSnapshot({
    required this.localDate,
    required Iterable<DailyLogConfirmationSourceIdentity> records,
  }) : records = List.unmodifiable(records),
       sourceRecordVersions = _versions(records),
       canonicalDigest = BackupCanonicalCodec.digest([
         for (final record in records) record.toJson(),
       ]);

  bool hasSameContent(DailyLogConfirmationSourceSnapshot other) =>
      localDate == other.localDate && canonicalDigest == other.canonicalDigest;

  static DailyLogConfirmationSourceRecordVersions _versions(
    Iterable<DailyLogConfirmationSourceIdentity> records,
  ) {
    int? versionFor(String store) {
      final versions = {
        for (final record in records)
          if (record.store == store) record.recordVersion,
      };
      return versions.length == 1 ? versions.single : null;
    }

    return DailyLogConfirmationSourceRecordVersions(
      status: versionFor(IndexedDbStoreNames.statusRecords),
      food: versionFor(IndexedDbStoreNames.foodRecords),
      activity: versionFor(IndexedDbStoreNames.activityRecords),
      training: versionFor(IndexedDbStoreNames.trainingRecords),
    );
  }
}

class DailyLogConfirmationSourceSnapshotReader {
  static const stores = [
    IndexedDbStoreNames.statusRecords,
    IndexedDbStoreNames.foodRecords,
    IndexedDbStoreNames.activityRecords,
    IndexedDbStoreNames.trainingRecords,
  ];

  final IndexedDbDatabase _database;

  const DailyLogConfirmationSourceSnapshotReader(this._database);

  Future<DailyLogConfirmationSourceSnapshot> read(String localDate) async {
    final records = <DailyLogConfirmationSourceIdentity>[];
    for (final store in stores) {
      records.addAll(
        _readStore(store, localDate, await _database.findAll(store)),
      );
    }
    return _snapshot(localDate, records);
  }

  Future<DailyLogConfirmationSourceSnapshot> readInTransaction(
    IndexedDbTransaction transaction,
    String localDate,
  ) async {
    final records = <DailyLogConfirmationSourceIdentity>[];
    for (final store in stores) {
      records.addAll(
        _readStore(store, localDate, await transaction.findAll(store)),
      );
    }
    return _snapshot(localDate, records);
  }

  DailyLogConfirmationSourceSnapshot _snapshot(
    String localDate,
    List<DailyLogConfirmationSourceIdentity> records,
  ) {
    records.sort((first, second) {
      final byStore = first.store.compareTo(second.store);
      return byStore != 0 ? byStore : first.recordId.compareTo(second.recordId);
    });
    return DailyLogConfirmationSourceSnapshot(
      localDate: localDate,
      records: records,
    );
  }

  Iterable<DailyLogConfirmationSourceIdentity> _readStore(
    String store,
    String localDate,
    Iterable<Map<String, Object?>> values,
  ) sync* {
    for (final value in values) {
      if (value['localDate'] != localDate) continue;
      final parsed = _parse(store, value);
      yield DailyLogConfirmationSourceIdentity(
        store: store,
        recordId: parsed.$1,
        recordVersion: parsed.$2,
        localDate: localDate,
        canonicalDigest: BackupCanonicalCodec.digest(value),
      );
    }
  }

  (String, int) _parse(String store, Map<String, Object?> record) {
    return switch (store) {
      IndexedDbStoreNames.statusRecords => () {
        final parsed = PersistedStatusRecord.fromRecord(record);
        return (parsed.id, parsed.recordVersion);
      }(),
      IndexedDbStoreNames.activityRecords => () {
        final parsed = PersistedActivityRecord.fromRecord(record);
        return (parsed.id, parsed.recordVersion);
      }(),
      IndexedDbStoreNames.foodRecords => () {
        final version = record['recordVersion'];
        if (version == PersistedFoodRecord.currentRecordVersion) {
          final parsed = PersistedFoodRecord.fromRecord(record);
          return (parsed.id, parsed.recordVersion);
        }
        if (version == DailyMealV2.recordVersion2) {
          final parsed = PersistedDailyMealV2Record.fromRecord(record);
          return (parsed.id, parsed.recordVersion);
        }
        throw FormatException('Unsupported FOOD recordVersion: $version.');
      }(),
      IndexedDbStoreNames.trainingRecords => () {
        final parsed = PersistedTrainingRecord.fromRecord(record);
        return (parsed.id, parsed.recordVersion);
      }(),
      _ => throw ArgumentError.value(store, 'store', 'Unsupported source'),
    };
  }
}
