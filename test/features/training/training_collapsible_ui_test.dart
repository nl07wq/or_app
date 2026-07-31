import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/models/training_exercise_controller.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/models/training_set_controller.dart';
import 'package:or_app/features/training/training_entry_page.dart';
import 'package:or_app/features/training/widgets/exercise_selector.dart';
import 'package:or_app/features/training/widgets/training_exercise_card.dart';
import 'package:or_app/features/training/widgets/training_exercise_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRepositoryRegistry.resetForTesting();
    morningFactNotifier.value = null;
  });

  tearDown(() {
    morningFactNotifier.value = null;
    AppRepositoryRegistry.resetForTesting();
  });

  testWidgets('new session expands only Exercise 1', (tester) async {
    await _pumpEntry(tester);

    expect(find.byType(ExerciseSelector), findsOneWidget);
    expect(find.text('EXERCISE 1'), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
    expect(find.byTooltip('Delete cardio'), findsNothing);
    expect(find.bySemanticsLabel('EXERCISE 1, expanded'), findsOneWidget);
  });

  testWidgets('empty cardio section shows only ADD CARDIO below its header', (
    tester,
  ) async {
    await _pumpEntry(tester);

    final header = find.text('CARDIO');
    final addButton = find.widgetWithText(OutlinedButton, 'ADD CARDIO');
    expect(find.text('CARDIO 1'), findsNothing);
    expect(
      tester.getTopLeft(header).dy,
      lessThan(tester.getTopLeft(addButton).dy),
    );
  });

  testWidgets('ADD CARDIO remains after every cardio card', (tester) async {
    await _pumpEntry(tester);

    final addButton = find.widgetWithText(OutlinedButton, 'ADD CARDIO');
    await _tapVisible(tester, addButton);
    expect(
      tester.getTopLeft(find.text('CARDIO 1')).dy,
      lessThan(tester.getTopLeft(addButton).dy),
    );

    await _tapVisible(tester, addButton);
    expect(
      tester.getTopLeft(find.text('CARDIO 1')).dy,
      lessThan(tester.getTopLeft(find.text('CARDIO 2')).dy),
    );
    expect(
      tester.getTopLeft(find.text('CARDIO 2')).dy,
      lessThan(tester.getTopLeft(addButton).dy),
    );
    expect(find.bySemanticsLabel('CARDIO 1, collapsed'), findsOneWidget);
    expect(find.bySemanticsLabel('CARDIO 2, expanded'), findsOneWidget);
  });

  testWidgets('deleting the last cardio restores the empty section', (
    tester,
  ) async {
    await _pumpEntry(tester);
    await _tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'ADD CARDIO'),
    );

    await tester.tap(find.byTooltip('Delete cardio'));
    await tester.pumpAndSettle();

    expect(find.text('CARDIO 1'), findsNothing);
    expect(find.byTooltip('Delete cardio'), findsNothing);
    expect(
      tester.getTopLeft(find.text('CARDIO')).dy,
      lessThan(
        tester.getTopLeft(find.widgetWithText(OutlinedButton, 'ADD CARDIO')).dy,
      ),
    );
  });

  testWidgets('history edit starts with every exercise and cardio collapsed', (
    tester,
  ) async {
    await _pumpEntry(
      tester,
      existingRecord: TrainingRecordReadModel.v2(
        id: 'training:00112233-4455-4677-8899-aabbccddeeff',
        localDate: '2026-07-26',
        createdAt: DateTime.utc(2026, 7, 26, 8),
        updatedAt: DateTime.utc(2026, 7, 26, 9),
        data: TrainingSessionV2(
          date: '2026-07-26T08:00:00.000',
          memo: 'existing',
          exercises: [
            TrainingExerciseV2(
              exerciseName: 'BenchPress',
              order: 1,
              sets: [
                TrainingSetV2(
                  setNo: 1,
                  setType: TrainingSetType.main,
                  weightKg: 65,
                  reps: 10,
                ),
              ],
            ),
          ],
          cardioEntries: [
            CardioEntryV2(
              purpose: CardioPurpose.main,
              type: CardioType.running,
              durationSeconds: 2400,
              distanceKm: 2.82,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(ExerciseSelector), findsNothing);
    expect(find.byType(DropdownButtonFormField<CardioType?>), findsNothing);
    expect(find.text('ベンチプレス'), findsOneWidget);
    expect(find.textContaining('65 kg'), findsOneWidget);
    expect(find.text('ランニング'), findsOneWidget);
    expect(find.textContaining('40:00'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('ランニング, collapsed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '時間'), '20:00');
    await tester.tap(find.bySemanticsLabel('ランニング, expanded'));
    await tester.pumpAndSettle();

    expect(find.textContaining('20:00'), findsOneWidget);
  });

  testWidgets('adding and opening exercises keeps only one card expanded', (
    tester,
  ) async {
    await _pumpEntry(tester);

    await _tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'ADD EXERCISE'),
    );

    expect(find.byType(ExerciseSelector), findsOneWidget);
    expect(find.text('EXERCISE 1'), findsOneWidget);
    expect(find.text('EXERCISE 2'), findsOneWidget);
    expect(find.byTooltip('Delete exercise'), findsOneWidget);

    await _tapVisible(tester, find.text('EXERCISE 1'));

    expect(find.byType(ExerciseSelector), findsOneWidget);
    expect(find.byTooltip('Delete exercise'), findsOneWidget);
    expect(find.byTooltip('Delete cardio'), findsNothing);
  });

  testWidgets(
    'adding cardio closes exercise and cross-group toggle is exclusive',
    (tester) async {
      await _pumpEntry(tester);

      await _tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'ADD CARDIO'),
      );

      expect(find.byType(ExerciseSelector), findsNothing);
      expect(find.byType(DropdownButtonFormField<CardioType?>), findsOneWidget);
      expect(find.text('CARDIO 1'), findsOneWidget);
      expect(find.byTooltip('Delete cardio'), findsOneWidget);

      await _tapVisible(tester, find.text('EXERCISE 1'));

      expect(find.byType(ExerciseSelector), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<CardioType?>), findsNothing);
      expect(find.byTooltip('Delete cardio'), findsNothing);
    },
  );

  testWidgets(
    'cardio title updates immediately after explicit type selection',
    (tester) async {
      await _pumpEntry(tester);
      await _tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'ADD CARDIO'),
      );

      expect(find.text('CARDIO 1'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '時間'))
            .controller!
            .text,
        isEmpty,
      );

      final typeDropdown = find.byType(DropdownButtonFormField<CardioType?>);
      await tester.tap(typeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ウォーキング').last);
      await tester.pumpAndSettle();

      expect(find.text('ウォーキング'), findsWidgets);
      expect(find.text('CARDIO 1'), findsNothing);
      expect(find.bySemanticsLabel('ウォーキング, expanded'), findsOneWidget);

      await tester.tap(typeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ランニング').last);
      await tester.pumpAndSettle();
      expect(find.text('ランニング'), findsWidgets);
    },
  );

  testWidgets(
    'cardio summary omits missing values and inputs survive collapse',
    (tester) async {
      await _pumpEntry(tester);
      await _tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'ADD CARDIO'),
      );

      await tester.enterText(find.widgetWithText(TextField, '時間'), '40:00');
      await tester.enterText(find.widgetWithText(TextField, '距離'), '2.82');
      await tester.enterText(find.widgetWithText(TextField, 'メモ'), 'steady');
      await tester.pump();

      await tester.tap(find.text('CARDIO 1'));
      await tester.pumpAndSettle();

      expect(find.text('CARDIO 1'), findsOneWidget);
      expect(find.textContaining('40:00'), findsOneWidget);
      expect(find.textContaining('2.82 km'), findsOneWidget);
      expect(find.byTooltip('Delete cardio'), findsNothing);

      await tester.tap(find.text('CARDIO 1'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '時間'))
            .controller!
            .text,
        '40:00',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '距離'))
            .controller!
            .text,
        '2.82',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'メモ'))
            .controller!
            .text,
        'steady',
      );
    },
  );

  testWidgets('exercise summary reuses statistics and skips incomplete sets', (
    tester,
  ) async {
    final controller = TrainingExerciseController(
      exerciseController: TextEditingController(text: 'BenchPress'),
      sets: [
        TrainingSetController(
          weightController: TextEditingController(text: '65'),
          repsController: TextEditingController(text: '10'),
        ),
        TrainingSetController(
          weightController: TextEditingController(text: '60'),
          repsController: TextEditingController(text: '8'),
        ),
        TrainingSetController(
          weightController: TextEditingController(text: 'not-a-number'),
          repsController: TextEditingController(text: '12'),
        ),
      ],
    );
    addTearDown(controller.dispose);

    await _pumpExerciseCard(tester, controller: controller, isExpanded: false);

    expect(find.text('ベンチプレス'), findsOneWidget);
    expect(find.text('65 kg · 2 Sets · 18 Reps'), findsOneWidget);
    expect(find.textContaining('not-a-number'), findsNothing);
    expect(find.byTooltip('Delete exercise'), findsNothing);

    await tester.tap(
      find.byKey(ValueKey('exercise-header-${identityHashCode(controller)}')),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete exercise'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Weight'), findsNWidgets(3));

    await tester.tap(
      find.byKey(ValueKey('exercise-header-${identityHashCode(controller)}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('exercise-header-${identityHashCode(controller)}')),
    );
    await tester.pumpAndSettle();

    final weightFields = find.widgetWithText(TextField, 'Weight');
    expect(tester.widget<TextField>(weightFields.at(0)).controller!.text, '65');
    expect(tester.widget<TextField>(weightFields.at(1)).controller!.text, '60');
    expect(
      tester.widget<TextField>(weightFields.at(2)).controller!.text,
      'not-a-number',
    );
  });

  testWidgets('reorder tracks the expanded exercise by controller identity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final first = TrainingExerciseController(
      exerciseController: TextEditingController(text: 'First Exercise'),
    );
    final second = TrainingExerciseController(
      exerciseController: TextEditingController(text: 'Second Exercise'),
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 1200,
            child: _ExerciseListHarness(
              exercises: [first, second],
              initiallyExpanded: first,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ExerciseSelector>(find.byType(ExerciseSelector)).controller,
      same(first.exerciseController),
    );

    await tester.drag(
      find.byType(ReorderableDragStartListener).first,
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ExerciseSelector>(find.byType(ExerciseSelector)).controller,
      same(first.exerciseController),
    );
    expect(find.text('Second Exercise'), findsOneWidget);
  });

  testWidgets(
    'deleting expanded exercise and cardio leaves no stale expansion',
    (tester) async {
      await _pumpEntry(tester);
      await _tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'ADD EXERCISE'),
      );
      await tester.tap(find.byTooltip('Delete exercise'));
      await tester.pumpAndSettle();

      expect(find.text('EXERCISE 1'), findsOneWidget);
      expect(find.text('EXERCISE 2'), findsNothing);
      expect(find.byType(ExerciseSelector), findsNothing);

      await _tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'ADD CARDIO'),
      );
      await _tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'ADD CARDIO'),
      );
      await tester.tap(find.byTooltip('Delete cardio'));
      await tester.pumpAndSettle();

      expect(find.text('CARDIO 1'), findsOneWidget);
      expect(find.text('CARDIO 2'), findsNothing);
      expect(find.byType(DropdownButtonFormField<CardioType?>), findsNothing);
    },
  );

  testWidgets('collapsed exercise and cardio remain in saved JSON', (
    tester,
  ) async {
    final database = await _pumpEntry(tester);

    final exerciseController = tester
        .widget<ExerciseSelector>(find.byType(ExerciseSelector))
        .controller;
    exerciseController.text = 'BenchPress';
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '65');
    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '10');
    await tester.tap(find.bySemanticsLabel('ベンチプレス, expanded'));
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'ADD CARDIO'),
    );
    tester
        .widget<DropdownButtonFormField<CardioPurpose?>>(
          find.byType(DropdownButtonFormField<CardioPurpose?>),
        )
        .onChanged!(CardioPurpose.main);
    tester
        .widget<DropdownButtonFormField<CardioType?>>(
          find.byType(DropdownButtonFormField<CardioType?>),
        )
        .onChanged!(CardioType.running);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '時間'), '30:00');
    await tester.enterText(find.widgetWithText(TextField, '距離'), '3.5');
    await tester.tap(find.bySemanticsLabel('ランニング, expanded'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('SAVE TRAINING'));
    await tester.pump(const Duration(milliseconds: 500));

    final stored = await database.findAll(IndexedDbStoreNames.trainingRecords);
    expect(stored, hasLength(1));
    final json = stored.single['data']! as Map<String, Object?>;
    expect(json['exercises'], hasLength(1));
    expect(json['cardioEntries'], hasLength(1));
    expect(jsonEncode(json), isNot(contains('expanded')));
    expect(jsonEncode(json), isNot(contains('collapsed')));
    expect(jsonEncode(json), isNot(contains('selectedCard')));
  });

  testWidgets('long exercise name and narrow width do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TrainingExerciseController(
      exerciseController: TextEditingController(
        text:
            'Extremely Long Custom Exercise Name That Must Stay Tappable '
            'Without Overflow',
      ),
      sets: [
        TrainingSetController(
          weightController: TextEditingController(text: '120'),
          repsController: TextEditingController(text: '12'),
        ),
      ],
    );
    addTearDown(controller.dispose);

    await _pumpExerciseCard(tester, controller: controller, isExpanded: false);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.textContaining('120 kg'), findsOneWidget);
  });
}

Future<FakeIndexedDbDatabase> _pumpEntry(
  WidgetTester tester, {
  TrainingRecordReadModel? existingRecord,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final database = FakeIndexedDbDatabase();
  seedOperationState(database, '2026-07-31');
  final initialization = AppInitializationController()..markReady();
  AppRepositoryRegistry.beginStartup(controller: initialization);
  AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  await tester.pumpWidget(
    MaterialApp(home: TrainingEntryPage(existingRecord: existingRecord)),
  );
  await tester.pumpAndSettle();
  return database;
}

Future<void> _pumpExerciseCard(
  WidgetTester tester, {
  required TrainingExerciseController controller,
  required bool isExpanded,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: _ExerciseCardHarness(
            controller: controller,
            initiallyExpanded: isExpanded,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _ExerciseCardHarness extends StatefulWidget {
  const _ExerciseCardHarness({
    required this.controller,
    required this.initiallyExpanded,
  });

  final TrainingExerciseController controller;
  final bool initiallyExpanded;

  @override
  State<_ExerciseCardHarness> createState() => _ExerciseCardHarnessState();
}

class _ExerciseCardHarnessState extends State<_ExerciseCardHarness> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return TrainingExerciseCard(
      controller: widget.controller,
      onCopy: () {},
      onDelete: () {},
      canDelete: true,
      isEditMode: false,
      index: 0,
      activeSet: null,
      onSetActivated: (_) {},
      isExpanded: _expanded,
      onToggleExpanded: () => setState(() => _expanded = !_expanded),
    );
  }
}

class _ExerciseListHarness extends StatefulWidget {
  const _ExerciseListHarness({
    required this.exercises,
    required this.initiallyExpanded,
  });

  final List<TrainingExerciseController> exercises;
  final TrainingExerciseController initiallyExpanded;

  @override
  State<_ExerciseListHarness> createState() => _ExerciseListHarnessState();
}

class _ExerciseListHarnessState extends State<_ExerciseListHarness> {
  late TrainingExerciseController? _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return TrainingExerciseList(
      exercises: widget.exercises,
      isEditMode: true,
      expandedExercise: _expanded,
      onToggleExpanded: (exercise) {
        setState(() {
          _expanded = identical(_expanded, exercise) ? null : exercise;
        });
      },
      onCopy: (_) {},
      onDelete: (exercise) {
        setState(() {
          if (identical(_expanded, exercise)) _expanded = null;
          widget.exercises.remove(exercise);
        });
      },
    );
  }
}
