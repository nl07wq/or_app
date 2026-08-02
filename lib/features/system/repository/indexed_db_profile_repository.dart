import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../models/profile_model.dart';
import 'profile_repository.dart';

class IndexedDbProfileRepository implements ProfileRepository {
  IndexedDbProfileRepository(this._database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final IndexedDbDatabase _database;
  final DateTime Function() _clock;

  @override
  Future<ProfileModel?> findCurrent() async {
    final record = await _database.findById(
      IndexedDbStoreNames.profileRecords,
      ProfileModel.recordId,
    );
    return record == null ? null : ProfileModel.fromRecord(record);
  }

  @override
  Future<ProfileModel> save(ProfileModel profile) => _database.runTransaction(
    storeNames: const [IndexedDbStoreNames.profileRecords],
    mode: IndexedDbTransactionMode.readWrite,
    action: (transaction) async {
      final existing = await transaction.findById(
        IndexedDbStoreNames.profileRecords,
        ProfileModel.recordId,
      );
      final created = existing == null
          ? null
          : ProfileModel.fromRecord(existing).createdAt;
      final expected = profile.toRecord(now: _clock(), created: created);
      await transaction.put(IndexedDbStoreNames.profileRecords, expected);
      final stored = await transaction.findById(
        IndexedDbStoreNames.profileRecords,
        ProfileModel.recordId,
      );
      if (stored == null || !_mapsEqual(stored, expected)) {
        throw StateError('Profile read-back verification failed.');
      }
      return ProfileModel.fromRecord(stored);
    },
  );

  @override
  Future<void> deleteCurrent() => _database.deleteById(
    IndexedDbStoreNames.profileRecords,
    ProfileModel.recordId,
  );

  static bool _mapsEqual(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    return a.entries.every((entry) => b[entry.key] == entry.value);
  }
}
