import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/training/models/active_training_draft.dart';
import 'package:or_app/features/training/repository/indexed_db_active_training_draft_repository.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'persists one minimal Active Training Draft per operation date',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbActiveTrainingDraftRepository(database);
      final started = ActiveTrainingDraft(
        operationDate: '2026-08-11',
        startTime: '2026-08-11T21:19:00+09:00',
      );

      await repository.save(started);
      final restored = await repository.findByOperationDate('2026-08-11');

      expect(restored?.startTime, started.startTime);
      expect(restored?.endTime, isNull);
      expect(
        database.rawRecord(
          IndexedDbStoreNames.activeTrainingDrafts,
          started.id,
        ),
        {
          'id': 'active-training-draft:2026-08-11',
          'version': 1,
          'operationDate': '2026-08-11',
          'startTime': '2026-08-11T21:19:00+09:00',
          'endTime': null,
        },
      );
    },
  );

  test(
    'updates end, supports undo, and deletes only the target draft',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbActiveTrainingDraftRepository(database);
      const date = '2026-08-11';
      const start = '2026-08-11T21:19:00+09:00';

      await repository.save(
        ActiveTrainingDraft(
          operationDate: date,
          startTime: start,
          endTime: '2026-08-11T22:03:00+09:00',
        ),
      );
      expect((await repository.findByOperationDate(date))?.endTime, isNotNull);

      await repository.save(
        ActiveTrainingDraft(operationDate: date, startTime: start),
      );
      expect((await repository.findByOperationDate(date))?.endTime, isNull);

      await repository.deleteByOperationDate(date);
      expect(await repository.findByOperationDate(date), isNull);
    },
  );

  test('rejects invalid time order without writing a draft', () async {
    final database = FakeIndexedDbDatabase();

    expect(
      () => ActiveTrainingDraft(
        operationDate: '2026-08-11',
        startTime: '2026-08-11T22:00:00+09:00',
        endTime: '2026-08-11T21:00:00+09:00',
      ),
      throwsFormatException,
    );
    expect(
      await database.findAll(IndexedDbStoreNames.activeTrainingDrafts),
      isEmpty,
    );
  });

  test('is excluded from every formal Backup section', () {
    expect(
      BackupStoreRegistry.stores.values,
      isNot(contains(IndexedDbStoreNames.activeTrainingDrafts)),
    );
  });
}
