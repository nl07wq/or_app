import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/repository/indexed_db_operation_state_repository.dart';
import 'package:or_app/features/operation_date/services/operation_date_service.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  tearDown(AppRepositoryRegistry.resetForTesting);

  test('returns the persisted date as a local-date value object', () async {
    final repository = IndexedDbOperationStateRepository(
      FakeIndexedDbDatabase(),
    );
    await repository.createInitial(OperationLocalDate.parse('2026-07-31'));

    final value = await OperationDateService(repository).current();

    expect(value.value, '2026-07-31');
    expect(value.asUtcDate, DateTime.utc(2026, 7, 31));
  });

  test(
    'registry-backed service fails before repository installation',
    () async {
      AppRepositoryRegistry.resetForTesting();

      await expectLater(
        const OperationDateService().current(),
        throwsStateError,
      );
    },
  );
}
