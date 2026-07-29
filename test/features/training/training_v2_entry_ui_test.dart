import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/training_entry_page.dart';
import 'package:or_app/features/training/widgets/exercise_selector.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(AppRepositoryRegistry.resetForTesting);
  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('new v2 entry exposes session and set fields at 320px', (
    tester,
  ) async {
    await _pump(tester, width: 320);

    expect(find.text('Session Name'), findsOneWidget);
    expect(find.text('Session Grade'), findsOneWidget);
    expect(find.text('Session Memo'), findsOneWidget);
    expect(find.text('Dynamic Stretch'), findsOneWidget);
    expect(find.text('Cooldown Stretch'), findsOneWidget);
    expect(find.text('Overall Evaluation'), findsOneWidget);
    expect(find.text('Set Type'), findsOneWidget);
    expect(find.text('RPE'), findsOneWidget);
    expect(find.text('Rest'), findsOneWidget);
    expect(find.text('30 sec'), findsOneWidget);
    expect(find.text('120 sec'), findsOneWidget);
    expect(find.text('SAVE TRAINING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[390, 900, 1280]) {
    testWidgets('new v2 entry has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pump(tester, width: width);

      expect(find.text('SAVE TRAINING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('new v2 entry has no overflow in dark theme', (tester) async {
    await _pump(tester, width: 390, brightness: Brightness.dark);

    expect(find.text('SAVE TRAINING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ADD SET preserves copy actions and rest presets', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '8');
    await tester.tap(find.text('90 sec'));
    await tester.tap(find.text('ADD SET'));
    await tester.pumpAndSettle();

    expect(find.text('SET 2'), findsOneWidget);
    expect(find.byTooltip('Copy previous weight'), findsOneWidget);
    expect(find.byTooltip('Copy previous reps'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy previous weight'));
    await tester.tap(find.byTooltip('Copy previous reps'));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-1-weight')))
          .controller!
          .text,
      '80',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-1-reps')))
          .controller!
          .text,
      '8',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-1-rest')))
          .controller!
          .text,
      '90',
    );
  });

  testWidgets('equipment accepts built-in, none, and custom snapshots', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    expect(find.text('None'), findsWidgets);
    expect(find.text('Custom Equipment'), findsOneWidget);
    final builtIn = find.text('Power Rack').first;
    await tester.tap(builtIn);
    await tester.pumpAndSettle();
    expect(find.text('Power Rack'), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom Equipment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Equipment Name'),
      'Custom Handle',
    );
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    expect(find.text('Custom Handle'), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('editable v2 restores fields and cardio calories stay disabled', (
    tester,
  ) async {
    final record = TrainingRecordReadModel.v2(
      id: 'training:00112233-4455-4677-8899-aabbccddeeff',
      localDate: '2026-07-30',
      createdAt: DateTime.utc(2026, 7, 30),
      updatedAt: DateTime.utc(2026, 7, 30),
      data: TrainingSessionV2(
        date: '2026-07-30T12:00:00',
        sessionName: 'Express',
        cardioEntries: [
          CardioEntryV2(
            purpose: CardioPurpose.main,
            type: CardioType.running,
            durationSeconds: 125,
            mets: 7,
            averageHeartRateBpm: 130,
            maximumHeartRateBpm: 150,
            averageSpeedKmh: 11,
          ),
        ],
      ),
    );

    await _pump(tester, existingRecord: record);

    expect(find.text('UPDATE TRAINING'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Session Name'))
          .controller!
          .text,
      'Express',
    );
    expect(find.bySemanticsLabel('ランニング, collapsed'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('ランニング, collapsed'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Minutes'))
          .controller!
          .text,
      '2',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Seconds'))
          .controller!
          .text,
      '5',
    );
    expect(find.text('Estimated Calories'), findsOneWidget);
    expect(find.text('Not calculated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double SAVE TRAINING creates only one v2 record', (
    tester,
  ) async {
    final database = await _pump(tester);
    tester
            .widget<ExerciseSelector>(find.byType(ExerciseSelector))
            .controller
            .text =
        'Squat';
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '5');

    final save = find.text('SAVE TRAINING');
    await tester.tap(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final records = await database.findAll(IndexedDbStoreNames.trainingRecords);
    expect(records, hasLength(1));
    expect(records.single['recordVersion'], 2);
  });
}

Future<FakeIndexedDbDatabase> _pump(
  WidgetTester tester, {
  double width = 900,
  Brightness brightness = Brightness.light,
  TrainingRecordReadModel? existingRecord,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final initialization = AppInitializationController()..markReady();
  AppRepositoryRegistry.beginStartup(controller: initialization);
  final database = FakeIndexedDbDatabase();
  AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      home: TrainingEntryPage(existingRecord: existingRecord),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}
