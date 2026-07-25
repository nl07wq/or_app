import 'indexed_db_database_contract.dart';
import 'indexed_db_database_stub.dart'
    if (dart.library.html) 'indexed_db_database_web.dart';

export 'indexed_db_database_contract.dart';

Future<IndexedDbDatabase>? _sharedDatabase;

Future<IndexedDbDatabase> openIndexedDbDatabase() async {
  final existing = _sharedDatabase;
  if (existing != null) return existing;

  final opening = createIndexedDbDatabase();
  _sharedDatabase = opening;
  try {
    return await opening;
  } catch (_) {
    if (identical(_sharedDatabase, opening)) {
      _sharedDatabase = null;
    }
    rethrow;
  }
}
