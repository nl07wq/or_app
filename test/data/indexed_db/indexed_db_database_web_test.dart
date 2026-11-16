@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_web.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';

void main() {
  test('action failure does not leak the transaction abort event', () async {
    final database = await createIndexedDbDatabase();
    final expected = StateError('controlled action failure');

    await expectLater(
      database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.operationState],
        mode: IndexedDbTransactionMode.readOnly,
        action: (_) async => throw expected,
      ),
      throwsA(same(expected)),
    );

    // Let the browser deliver the transaction's asynchronous abort event.
    // Before the fix this escapes as an uncaught raw Event(type: abort).
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
}
