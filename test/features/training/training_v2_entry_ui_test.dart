import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';
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
    expect(find.text('Overall Evaluation'), findsNothing);
    expect(find.text('Evaluation'), findsNothing);
    expect(find.text('Next Target'), findsNothing);
    expect(find.text('Set Type'), findsOneWidget);
    expect(find.text('RPE'), findsOneWidget);
    expect(find.text('Rest'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('30')).dy,
      tester.getTopLeft(find.text('120')).dy,
    );
    final weightTop = tester
        .getTopLeft(find.byKey(const Key('v2-set-0-weight')))
        .dy;
    final repsTop = tester
        .getTopLeft(find.byKey(const Key('v2-set-0-reps')))
        .dy;
    expect(weightTop, repsTop);
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

  for (final width in <double>[320, 390]) {
    testWidgets(
      'rest presets keep one 48px hit row and seconds at ${width.toInt()}px',
      (tester) async {
        await _pump(tester, width: width);
        final restField = find.byKey(const Key('v2-set-0-rest'));
        const presets = [30, 45, 60, 90, 120];
        double? rowTop;

        for (final seconds in presets) {
          final button = find.widgetWithText(OutlinedButton, '$seconds');
          expect(button, findsOneWidget);
          final rect = tester.getRect(button);
          rowTop ??= rect.top;
          expect(rect.top, rowTop);
          expect(rect.height, greaterThanOrEqualTo(48));
          await tester.tapAt(Offset(rect.center.dx, rect.bottom - 1));
          expect(
            tester.widget<TextField>(restField).controller!.text,
            '$seconds',
          );
        }

        await tester.enterText(restField, '75');
        expect(tester.widget<TextField>(restField).controller!.text, '75');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final width in <double>[320, 390, 900, 1280]) {
      testWidgets(
        'cardio editor has localized single inputs without overflow at '
        '${width.toInt()}px ${brightness.name}',
        (tester) async {
          await _pump(tester, width: width, brightness: brightness);
          await tester.tap(find.text('ADD CARDIO'));
          await tester.pumpAndSettle();

          expect(find.text('目的'), findsOneWidget);
          expect(find.text('種目'), findsOneWidget);
          expect(find.text('時間'), findsOneWidget);
          expect(find.text('距離'), findsOneWidget);
          expect(find.text('METs'), findsOneWidget);
          expect(find.text('平均心拍'), findsOneWidget);
          expect(find.text('最大心拍'), findsOneWidget);
          expect(find.text('平均速度'), findsOneWidget);
          expect(find.text('推定消費カロリー'), findsOneWidget);
          expect(find.text('メモ'), findsOneWidget);
          expect(find.text('Minutes'), findsNothing);
          expect(find.text('Seconds'), findsNothing);
          expect(find.byKey(const Key('v2-cardio-0-equipment')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('ADD SET preserves copy actions and rest presets', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '8');
    await tester.tap(find.text('90'));
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

  testWidgets('weight and reps adjustment buttons update safely', (
    tester,
  ) async {
    await _pump(tester, width: 320);
    await tester.enterText(find.byKey(const Key('v2-set-0-weight')), '80');
    await tester.enterText(find.byKey(const Key('v2-set-0-reps')), '5');

    final weightAdjustments = find.byKey(
      const Key('v2-set-0-weight-adjustments'),
    );
    final repsAdjustments = find.byKey(const Key('v2-set-0-reps-adjustments'));
    await tester.tap(
      find.descendant(of: weightAdjustments, matching: find.text('+2.5')),
    );
    await tester.tap(
      find.descendant(of: repsAdjustments, matching: find.text('-10')),
    );

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-0-weight')))
          .controller!
          .text,
      '82.5',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-0-reps')))
          .controller!
          .text,
      '0',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('equipment accepts built-in, none, and custom snapshots', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('なし'), findsNothing);
    _setExercise(tester, 'BenchPress');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    expect(find.text('なし'), findsOneWidget);
    expect(find.text('Custom Equipment'), findsOneWidget);
    expect(find.text('45°レッグプレス'), findsNothing);
    final builtIn = find.text('パワーラック').first;
    await tester.tap(builtIn);
    await tester.pumpAndSettle();
    expect(find.text('パワーラック'), findsOneWidget);

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
    await tester.tap(find.text('なし').last);
    await tester.pumpAndSettle();
    expect(find.text('なし'), findsOneWidget);
  });

  testWidgets('exercise change preserves only compatible equipment', (
    tester,
  ) async {
    await _pump(tester);
    _setExercise(tester, 'BenchPress');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('スミスマシン'));
    await tester.pumpAndSettle();

    _setExercise(tester, 'ShoulderPress');
    await tester.pumpAndSettle();
    expect(find.text('スミスマシン'), findsOneWidget);

    _setExercise(tester, 'LegPress');
    await tester.pumpAndSettle();
    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('なし'), findsNothing);
  });

  testWidgets('insight panels precede sets and omit responsibility fields', (
    tester,
  ) async {
    await _pump(tester, width: 320);
    _setExercise(tester, 'BenchPress');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('なし'));
    await tester.pumpAndSettle();

    final previous = tester.getTopLeft(find.text('Previous')).dy;
    final progression = tester.getTopLeft(find.text('PROGRESSION')).dy;
    final personalRecord = tester.getTopLeft(find.text('PERSONAL RECORD')).dy;
    final firstSet = tester.getTopLeft(find.text('SET 1')).dy;
    expect(previous, lessThan(progression));
    expect(progression, lessThan(personalRecord));
    expect(personalRecord, lessThan(firstSet));
    expect(find.text('STATISTICS'), findsNothing);
    expect(find.text('前回　記録なし'), findsOneWidget);
    expect(find.text('今回　提案なし'), findsOneWidget);
    expect(find.text('自己ベスト'), findsOneWidget);
    expect(find.text('Overall Evaluation'), findsNothing);
    expect(find.text('Evaluation'), findsNothing);
    expect(find.text('Next Target'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('statistics results stay outside entry for valid main sets', (
    tester,
  ) async {
    await _pump(tester, width: 320);
    _setExercise(tester, 'BenchPress');
    await tester.enterText(find.byKey(const Key('v2-set-0-weight')), '80');
    await tester.enterText(find.byKey(const Key('v2-set-0-reps')), '8');
    await tester.pump();

    expect(find.text('STATISTICS'), findsNothing);
    expect(find.text('総重量 640 kg'), findsNothing);
    expect(find.text('セット数 1'), findsNothing);
    expect(find.text('総レップ数 8'), findsNothing);
    expect(find.text('平均重量 80 kg'), findsNothing);
    expect(find.text('最高重量 80 kg × 8'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing sets preserves hidden evaluation and next target', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    final existing = TrainingRecordReadModel.v2(
      id: 'training:11112222-3333-4444-8555-666677778888',
      localDate: '2026-07-30',
      createdAt: DateTime.utc(2026, 7, 30),
      updatedAt: DateTime.utc(2026, 7, 30),
      data: TrainingSessionV2(
        date: '2026-07-30T12:00:00',
        overallEvaluation: 'Keep session evaluation',
        exercises: [
          TrainingExerciseV2(
            exerciseName: 'BenchPress',
            order: 1,
            equipment: TrainingEquipmentSnapshot(
              catalogId: 'power_rack',
              name: 'Power Rack',
            ),
            sets: [
              TrainingSetV2(
                setNo: 1,
                setType: TrainingSetType.main,
                weightKg: 80,
                reps: 5,
              ),
            ],
            evaluation: 'Keep exercise evaluation',
            nextTarget: TrainingNextTarget(
              targetWeightKg: 82.5,
              targetReps: [5],
              notes: 'Keep target',
            ),
          ),
        ],
      ),
    );
    database.seed(IndexedDbStoreNames.trainingRecords, existing.id, {
      'id': existing.id,
      'recordVersion': 2,
      'localDate': existing.localDate,
      'createdAt': existing.createdAt.toIso8601String(),
      'updatedAt': existing.updatedAt.toIso8601String(),
      'data': existing.v2Data!.toJson(),
    });
    await _pump(tester, existingRecord: existing, database: database);

    await tester.tap(find.bySemanticsLabel('ベンチプレス, collapsed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '6');
    await tester.tap(find.text('UPDATE TRAINING'));
    await tester.pumpAndSettle();

    final stored = await database.findById(
      IndexedDbStoreNames.trainingRecords,
      existing.id,
    );
    final data = stored!['data'] as Map<String, dynamic>;
    final exercise = (data['exercises'] as List).single as Map<String, dynamic>;
    expect(data['overallEvaluation'], 'Keep session evaluation');
    expect(exercise['evaluation'], 'Keep exercise evaluation');
    expect(exercise['nextTarget'], containsPair('targetWeightKg', 82.5));
    expect(exercise['nextTarget'], containsPair('notes', 'Keep target'));
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
          .widget<TextField>(find.widgetWithText(TextField, '時間'))
          .controller!
          .text,
      '2:05',
    );
    expect(find.text('推定消費カロリー'), findsOneWidget);
    expect(find.text('Equipment'), findsNothing);
    expect(find.text('Minutes'), findsNothing);
    expect(find.text('Seconds'), findsNothing);
    expect(find.text('種目'), findsOneWidget);
    expect(find.text('距離'), findsOneWidget);
    expect(find.text('平均心拍'), findsOneWidget);
    expect(find.text('最大心拍'), findsOneWidget);
    expect(find.text('平均速度'), findsOneWidget);
    expect(find.text('メモ'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '平均速度'))
          .keyboardType,
      TextInputType.text,
    );
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

  testWidgets('built-in equipment display keeps stable saved identity', (
    tester,
  ) async {
    final database = await _pump(tester);
    _setExercise(tester, 'BenchPress');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('パワーラック'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '5');

    await tester.tap(find.text('SAVE TRAINING'));
    await tester.pumpAndSettle();

    final records = await database.findAll(IndexedDbStoreNames.trainingRecords);
    final data = records.single['data'] as Map<String, dynamic>;
    final exercise = (data['exercises'] as List).single as Map<String, dynamic>;
    expect(exercise['equipment'], containsPair('catalogId', 'power_rack'));
    expect(exercise['equipment'], containsPair('name', 'Power Rack'));
  });

  testWidgets('cardio preview uses same-date STATUS without calories input', (
    tester,
  ) async {
    final now = DateTime.now();
    final localDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final database = FakeIndexedDbDatabase();
    final status = PersistedStatusRecord(
      id: PersistedStatusRecord.canonicalId(localDate),
      localDate: localDate,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
      canonicalDate: localDate,
      recordKind: StatusRecordKind.canonical,
      data: MorningData(
        date: '${localDate}T07:00:00',
        weight: 96.8,
        bodyFat: 20,
        sleepHours: 7,
        sleepScore: 80,
        footPain: 0,
        workType: WorkType.work,
        workStart: '09:00',
        workEnd: '18:00',
        workBreak: '01:00',
        workHours: 8,
        memo: '',
      ),
    );
    database.seed(
      IndexedDbStoreNames.statusRecords,
      status.id,
      status.toRecord(),
    );
    await _pump(tester, database: database);

    await tester.tap(find.text('ADD CARDIO'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '時間'), '5:00');
    await tester.enterText(find.widgetWithText(TextField, 'METs'), '4');
    await tester.pump();

    expect(find.text('34 kcal'), findsOneWidget);
    expect(
      find.text('Calculated from METs, duration, and STATUS weight'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, '推定消費カロリー'), findsNothing);
  });
}

void _setExercise(WidgetTester tester, String name) {
  tester
          .widget<ExerciseSelector>(find.byType(ExerciseSelector))
          .controller
          .text =
      name;
}

Future<FakeIndexedDbDatabase> _pump(
  WidgetTester tester, {
  double width = 900,
  Brightness brightness = Brightness.light,
  TrainingRecordReadModel? existingRecord,
  FakeIndexedDbDatabase? database,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final initialization = AppInitializationController()..markReady();
  AppRepositoryRegistry.beginStartup(controller: initialization);
  final targetDatabase = database ?? FakeIndexedDbDatabase();
  AppRepositoryRegistry.install(
    AppRepositoryContainer.indexedDb(targetDatabase),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      home: TrainingEntryPage(existingRecord: existingRecord),
    ),
  );
  await tester.pumpAndSettle();
  return targetDatabase;
}
