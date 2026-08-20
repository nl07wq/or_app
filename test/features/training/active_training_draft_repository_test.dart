import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/training/models/active_training_draft.dart';
import 'package:or_app/features/training/models/training_v2_form_controller.dart';
import 'package:or_app/features/training/repository/indexed_db_active_training_draft_repository.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'persists one complete Active Training Draft per operation date',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbActiveTrainingDraftRepository(database);
      final started = ActiveTrainingDraft(
        operationDate: '2026-08-11',
        startTime: '2026-08-11T21:19:00+09:00',
        entryState: _emptyEntryState(),
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
          'version': 2,
          'operationDate': '2026-08-11',
          'startTime': '2026-08-11T21:19:00+09:00',
          'endTime': null,
          'entryState': _emptyEntryState(),
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
          entryState: _emptyEntryState(),
        ),
      );
      expect((await repository.findByOperationDate(date))?.endTime, isNotNull);

      await repository.save(
        ActiveTrainingDraft(
          operationDate: date,
          startTime: start,
          entryState: _emptyEntryState(),
        ),
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
        entryState: _emptyEntryState(),
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

  test('reads the legacy time-only draft without inventing entry state', () {
    final restored = ActiveTrainingDraft.fromRecord(const {
      'id': 'active-training-draft:2026-08-11',
      'version': 1,
      'operationDate': '2026-08-11',
      'startTime': '2026-08-11T21:19:00+09:00',
      'endTime': null,
    });

    expect(restored.version, 1);
    expect(restored.entryState, isNull);
  });

  test('entry state round-trips exercise, set, cardio, and session order', () {
    final source = TrainingV2FormController.newSession(localDate: '2026-08-11');
    addTearDown(source.dispose);
    source.sessionName.text = 'Night Session';
    source.sessionMemo.text = 'Draft memo';
    source.exercises.first.exerciseName.text = 'Squat';
    source.exercises.first.sets.first
      ..weight.text = '80'
      ..reps.text = '5';
    source.exercises.first.addSet();
    source.exercises.first.sets.last
      ..weight.text = '75'
      ..reps.text = '8';
    source.addExercise();
    source.exercises.last.exerciseName.text = 'BenchPress';
    source.addCardio();
    source.cardioEntries.single
      ..duration.text = '20:00'
      ..distance.text = '3.5'
      ..notes.text = 'Easy finish';

    final restored = TrainingV2FormController.newSession(
      localDate: '2026-08-11',
    );
    addTearDown(restored.dispose);
    restored.restoreDraftState(source.toDraftState());

    expect(restored.sessionName.text, 'Night Session');
    expect(restored.sessionMemo.text, 'Draft memo');
    expect(restored.exercises.map((value) => value.exerciseName.text), [
      'Squat',
      'BenchPress',
    ]);
    expect(restored.exercises.first.sets.map((value) => value.weight.text), [
      '80',
      '75',
    ]);
    expect(restored.cardioEntries.single.duration.text, '20:00');
    expect(restored.cardioEntries.single.distance.text, '3.5');
    expect(restored.cardioEntries.single.notes.text, 'Easy finish');
  });
}

Map<String, Object?> _emptyEntryState() {
  final form = TrainingV2FormController.newSession(localDate: '2026-08-11');
  try {
    return form.toDraftState();
  } finally {
    form.dispose();
  }
}
