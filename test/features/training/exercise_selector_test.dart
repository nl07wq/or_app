import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/data/default_training_templates.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/models/custom_training_exercise.dart';
import 'package:or_app/features/training/models/persisted_custom_training_exercise_record.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';
import 'package:or_app/features/training/models/training_set_controller.dart';
import 'package:or_app/features/training/services/exercise_catalog_service.dart';
import 'package:or_app/features/training/services/exercise_name_localization.dart';
import 'package:or_app/features/training/widgets/exercise_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRepositoryRegistry.resetForTesting();
  });
  tearDown(AppRepositoryRegistry.resetForTesting);

  test(
    'Face Pull is a unique localized built-in in the Pull category',
    () async {
      final pull = defaultTrainingTemplates.singleWhere(
        (template) => template.name == 'Pull',
      );
      final catalog = await ExerciseCatalogService.load();
      final facePullEntries = catalog.all
          .where((name) => exerciseIdentityKey(name) == 'facepull')
          .toList();

      expect(pull.exercises, contains('Face Pull'));
      expect(facePullEntries, ['Face Pull']);
      expect(exerciseIdentityKey('Face Pull'), 'facepull');
      expect(exerciseDisplayName('Face Pull'), 'フェイスプル');
    },
  );

  test('catalog lists recently used exercises newest first', () async {
    await TrainingRepository.save(
      TrainingSession(
        date: '2026-07-21T12:00:00.000',
        memo: '',
        exercises: const [
          TrainingExercise(exerciseName: 'Lat Pulldown', order: 1, sets: []),
        ],
      ),
    );
    await TrainingRepository.save(
      TrainingSession(
        date: '2026-07-22T12:00:00.000',
        memo: '',
        exercises: const [
          TrainingExercise(exerciseName: 'Bench Press', order: 1, sets: []),
        ],
      ),
    );

    final catalog = await ExerciseCatalogService.load();

    expect(catalog.recent, ['Bench Press', 'Lat Pulldown']);
    expect(
      catalog.all.map(exerciseDisplayName),
      containsAll(['ベンチプレス', 'ラットプルダウン', 'ハックスクワット']),
    );
  });

  test('all built-in identifiers have localized display names', () {
    expect(
      {
        for (final name in const [
          'BenchPress',
          'DumbbellCurl',
          'LatPulldown',
          'LegPress',
          'ShoulderPress',
          'InclineBenchPress',
          'ChestPress',
          'SeatedRow',
          'FacePull',
          'Squat',
          'LegCurl',
          'HackSquat',
        ])
          name: exerciseDisplayName(name),
      },
      {
        'BenchPress': 'ベンチプレス',
        'DumbbellCurl': 'ダンベルカール',
        'LatPulldown': 'ラットプルダウン',
        'LegPress': 'レッグプレス',
        'ShoulderPress': 'ショルダープレス',
        'InclineBenchPress': 'インクラインベンチプレス',
        'ChestPress': 'チェストプレス',
        'SeatedRow': 'シーテッドロー',
        'FacePull': 'フェイスプル',
        'Squat': 'スクワット',
        'LegCurl': 'レッグカール',
        'HackSquat': 'ハックスクワット',
      },
    );
  });

  testWidgets('selector changes only the exercise name', (tester) async {
    await TrainingRepository.save(
      TrainingSession(
        date: '2026-07-22T12:00:00.000',
        memo: '',
        exercises: const [
          TrainingExercise(exerciseName: 'BenchPress', order: 1, sets: []),
        ],
      ),
    );
    final exerciseController = TextEditingController();
    final setController = TrainingSetController(
      weightController: TextEditingController(text: '80'),
      repsController: TextEditingController(text: '8'),
    );
    addTearDown(exerciseController.dispose);
    addTearDown(setController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExerciseSelector(controller: exerciseController)),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Select Exercise'), findsOneWidget);
    expect(
      tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration
          .labelText,
      isNull,
    );
    await tester.tap(find.byKey(const Key('exercise-selector')));
    await tester.pumpAndSettle();

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('All Exercises'), findsOneWidget);
    await tester.tap(find.text('ベンチプレス').first);
    await tester.pumpAndSettle();

    expect(exerciseController.text, 'BenchPress');
    expect(find.text('ベンチプレス'), findsOneWidget);
    expect(setController.weightController.text, '80');
    expect(setController.repsController.text, '8');
  });

  testWidgets('custom exercise is registered and immediately selected', (
    tester,
  ) async {
    final exerciseController = TextEditingController();
    addTearDown(exerciseController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExerciseSelector(controller: exerciseController)),
      ),
    );

    await tester.tap(find.byKey(const Key('exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Custom Exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cable Fly');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(exerciseController.text, 'Cable Fly');
    expect((await ExerciseCatalogService.load()).all, contains('Cable Fly'));

    exerciseController.clear();
    await tester.tap(find.byKey(const Key('exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cable Fly'));
    await tester.pumpAndSettle();
    expect(exerciseController.text, 'Cable Fly');
  });

  testWidgets('picker shows built-in Face Pull once over a custom duplicate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'training_custom_exercises': ['Face Pull', 'Cable Fly'],
    });
    final exerciseController = TextEditingController();
    addTearDown(exerciseController.dispose);
    expect(
      (await ExerciseCatalogService.load()).all,
      containsAll(['Face Pull', 'Cable Fly']),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExerciseSelector(controller: exerciseController)),
      ),
    );
    await tester.tap(find.byKey(const Key('exercise-selector')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('フェイスプル'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('フェイスプル'), findsOneWidget);
    await tester.tap(find.text('フェイスプル'));
    await tester.pumpAndSettle();
    expect(exerciseController.text, 'Face Pull');
  });

  test(
    'catalog removes only exact custom Face Pull and preserves training data',
    () async {
      final database = FakeIndexedDbDatabase();
      final initialization = AppInitializationController()..markReady();
      AppRepositoryRegistry.beginStartup(controller: initialization);
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
      final timestamp = DateTime.utc(2026, 8, 3, 16);
      final exact = PersistedCustomTrainingExerciseRecord(
        id: 'custom-exercise:00000000-0000-4000-8000-000000000001',
        normalizedName: 'facepull',
        createdAt: timestamp,
        updatedAt: timestamp,
        data: const CustomTrainingExercise(
          id: 'custom-exercise:00000000-0000-4000-8000-000000000001',
          name: 'Face Pull',
        ),
      );
      final partial = PersistedCustomTrainingExerciseRecord(
        id: 'custom-exercise:00000000-0000-4000-8000-000000000002',
        normalizedName: 'facepullplus',
        createdAt: timestamp,
        updatedAt: timestamp,
        data: const CustomTrainingExercise(
          id: 'custom-exercise:00000000-0000-4000-8000-000000000002',
          name: 'Face Pull Plus',
        ),
      );
      final other = PersistedCustomTrainingExerciseRecord(
        id: 'custom-exercise:00000000-0000-4000-8000-000000000003',
        normalizedName: 'cablefly',
        createdAt: timestamp,
        updatedAt: timestamp,
        data: const CustomTrainingExercise(
          id: 'custom-exercise:00000000-0000-4000-8000-000000000003',
          name: 'Cable Fly',
        ),
      );
      for (final record in [exact, partial, other]) {
        database.seed(
          IndexedDbStoreNames.customTrainingExercises,
          record.id,
          record.toRecord(),
        );
      }
      final training = PersistedTrainingRecord.v2(
        id: 'training:00000000-0000-4000-8000-000000000004',
        localDate: '2026-06-19',
        createdAt: timestamp,
        updatedAt: timestamp,
        data: TrainingSessionV2(
          date: '2026-06-19T12:00:00.000',
          sessionGrade: TrainingSessionGrade.a,
          exercises: [
            TrainingExerciseV2(
              exerciseName: 'Face Pull',
              order: 1,
              sets: [
                TrainingSetV2(
                  setNo: 1,
                  setType: TrainingSetType.main,
                  weightKg: 18.75,
                  reps: 15,
                ),
              ],
              evaluation: '新規採用',
            ),
          ],
        ),
      );
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        training.id,
        training.toRecord(),
      );
      final before = database.rawRecord(
        IndexedDbStoreNames.trainingRecords,
        training.id,
      );

      final catalog = await ExerciseCatalogService.load();
      await ExerciseCatalogService.registerCustom('Face Pull');
      await ExerciseCatalogService.load();

      final remaining = await database.findAll(
        IndexedDbStoreNames.customTrainingExercises,
      );
      expect(remaining.map((record) => record['id']), [partial.id, other.id]);
      expect(
        catalog.all.where((name) => exerciseIdentityKey(name) == 'facepull'),
        ['Face Pull'],
      );
      expect(
        database.rawRecord(IndexedDbStoreNames.trainingRecords, training.id),
        before,
      );
      final restored = PersistedTrainingRecord.fromRecord(before!);
      expect(restored.id, training.id);
      expect(restored.recordVersion, 2);
      expect(restored.dataV2.exercises.single.exerciseName, 'Face Pull');
      expect(restored.dataV2.exercises.single.sets.single.reps, 15);
      expect(restored.dataV2.exercises.single.evaluation, '新規採用');
      expect(restored.dataV2.exercises.single.equipment, isNull);
    },
  );
}
