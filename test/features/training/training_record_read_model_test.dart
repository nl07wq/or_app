import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';
import 'package:or_app/features/training/training_detail_page.dart';
import 'package:or_app/features/training/training_history_page.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  tearDown(AppRepositoryRegistry.resetForTesting);

  test('v2 read model preserves common fields and source Domain', () {
    final session = _v2Session();
    final model = _readModel(session);

    expect(model.recordVersion, 2);
    expect(model.localDate, '2026-07-30');
    expect(model.displaySessionName, 'Upper');
    expect(model.memo, 'v2 memo');
    expect(model.exerciseCount, 1);
    expect(model.setCount, 1);
    expect(model.cardioEntryCount, 1);
    expect(model.isEditable, isTrue);
    expect(model.v1Data, isNull);
    expect(model.v2Data, same(session));
  });

  test('v2 compatibility projection does not infer missing cardio fields', () {
    final model = _readModel(_v2Session());

    final projection = model.toCompatibilityProjection();

    expect(projection.date, '2026-07-30T18:30:00+09:00');
    expect(projection.exercises.single.exerciseName, 'Bench Press');
    expect(projection.exercises.single.sets.single.weight, 82.5);
    expect(projection.cardioEntries, isEmpty);
    expect(model.cardioEntryCount, 1);
    expect(model.v2Data?.cardioEntries.single.durationSeconds, 90);
  });

  testWidgets(
    'migration v2 detail is visibly read-only and renders common data',
    (tester) async {
      final database = FakeIndexedDbDatabase();
      final persisted = PersistedTrainingRecord.v2ForMigration(
        id: 'training:00112233-4455-4677-8899-aabbccddeeff',
        localDate: '2026-07-30',
        createdAt: DateTime.utc(2026, 7, 30, 9),
        updatedAt: DateTime.utc(2026, 7, 30, 10),
        migrationSource: _migrationSource,
        data: _v2Session(),
      );
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        persisted.id,
        persisted.toRecord(),
      );
      final before = database.rawRecord(
        IndexedDbStoreNames.trainingRecords,
        persisted.id,
      );
      final controller = AppInitializationController()..markReady();
      AppRepositoryRegistry.beginStartup(controller: controller);
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
      final record = TrainingRecord.fromReadModel(
        _readModel(_v2Session(), migrated: true),
      );

      await tester.pumpWidget(
        MaterialApp(home: TrainingDetailPage(record: record)),
      );
      await tester.pumpAndSettle();

      expect(find.text('READ ONLY — Training Record v2'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.textContaining('v2 memo'), findsWidgets);
      expect(find.text('Equipment Power Rack'), findsOneWidget);
      expect(find.text('Grade A'), findsOneWidget);
      expect(find.textContaining('Main Sets 1'), findsOneWidget);
      expect(
        find.textContaining('Personal Record 82.5 kg x 8'),
        findsOneWidget,
      );
      expect(find.textContaining('Next Target 85 kg'), findsOneWidget);
      expect(
        database.rawRecord(IndexedDbStoreNames.trainingRecords, persisted.id),
        before,
      );
    },
  );

  test('v2 contributes common counts but not cardio calories', () async {
    final now = DateTime.now();
    final localDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final database = FakeIndexedDbDatabase();
    final session = TrainingSessionV2(
      date: '${localDate}T12:00:00',
      exercises: _v2Session().exercises,
      cardioEntries: _v2Session().cardioEntries,
    );
    final persisted = PersistedTrainingRecord.v2(
      id: 'training:00112233-4455-4677-8899-aabbccddeeff',
      localDate: localDate,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
      data: session,
    );
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      persisted.id,
      persisted.toRecord(),
    );
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));

    await refreshTrainingSummary();

    expect(trainingSummaryNotifier.value?.completed, isTrue);
    expect(trainingSummaryNotifier.value?.exerciseCount, 1);
    expect(trainingSummaryNotifier.value?.setCount, 1);
    expect(trainingCardioCaloriesNotifier.value, 0);
  });

  testWidgets('history enables edit and delete for normal v2', (tester) async {
    final database = FakeIndexedDbDatabase();
    final persisted = PersistedTrainingRecord.v2(
      id: 'training:00112233-4455-4677-8899-aabbccddeeff',
      localDate: '2026-07-30',
      createdAt: DateTime.utc(2026, 7, 30, 9),
      updatedAt: DateTime.utc(2026, 7, 30, 10),
      data: _v2Session(),
    );
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      persisted.id,
      persisted.toRecord(),
    );
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));

    await tester.pumpWidget(const MaterialApp(home: TrainingHistoryPage()));
    await tester.pumpAndSettle();

    expect(find.text('READ ONLY'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.edit_outlined),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.delete_outline),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('history keeps v1 read-only', (tester) async {
    final database = FakeIndexedDbDatabase();
    final persisted = PersistedTrainingRecord(
      id: 'training:00112233-4455-4677-8899-aabbccddeeff',
      localDate: '2026-07-30',
      createdAt: DateTime.utc(2026, 7, 30, 9),
      updatedAt: DateTime.utc(2026, 7, 30, 10),
      data: TrainingSession(
        date: '2026-07-30T18:30:00+09:00',
        memo: 'v1',
        exercises: const [],
      ),
    );
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      persisted.id,
      persisted.toRecord(),
    );
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));

    await tester.pumpWidget(const MaterialApp(home: TrainingHistoryPage()));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.edit_outlined),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('READ ONLY'), findsOneWidget);
  });
}

const _migrationSource = TrainingMigrationSource(
  migrationId: 'test_migration',
  sourceSystem: 'test',
  sourceKey: 'training',
  sourceIndex: 0,
  duplicateOrdinal: 0,
);

TrainingRecordReadModel _readModel(
  TrainingSessionV2 session, {
  bool migrated = false,
}) {
  return TrainingRecordReadModel.v2(
    id: 'training:00112233-4455-4677-8899-aabbccddeeff',
    localDate: '2026-07-30',
    createdAt: DateTime.utc(2026, 7, 30, 9),
    updatedAt: DateTime.utc(2026, 7, 30, 10),
    migrationSource: migrated ? _migrationSource.toJson() : null,
    data: session,
  );
}

TrainingSessionV2 _v2Session() {
  return TrainingSessionV2(
    date: '2026-07-30T18:30:00+09:00',
    sessionName: 'Upper',
    sessionGrade: TrainingSessionGrade.a,
    memo: 'v2 memo',
    exercises: [
      TrainingExerciseV2(
        exerciseName: 'Bench Press',
        order: 1,
        equipment: TrainingEquipmentSnapshot(
          catalogId: 'power_rack',
          name: 'Power Rack',
        ),
        nextTarget: TrainingNextTarget(
          targetWeightKg: 85,
          targetReps: const [8],
          notes: 'Stay controlled',
        ),
        sets: [
          TrainingSetV2(
            setNo: 1,
            setType: TrainingSetType.main,
            weightKg: 82.5,
            reps: 8,
          ),
        ],
      ),
    ],
    cardioEntries: [
      CardioEntryV2(
        purpose: CardioPurpose.main,
        type: CardioType.running,
        durationSeconds: 90,
        estimatedCaloriesKcal: 25,
      ),
    ],
  );
}
