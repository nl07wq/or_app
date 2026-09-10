import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/features/training/data_center_training_history_page.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';

void main() {
  testWidgets('renders overview metrics and charts at narrow widths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRAINING HISTORY'), findsWidgets);
    expect(find.text('RECORDED VOLUME'), findsWidgets);
    expect(find.text('STRENGTH OVERVIEW'), findsOneWidget);
    expect(find.text('1 WEEK'), findsOneWidget);
    expect(find.text('6 MONTHS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an intentional no-history state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DataCenterTrainingHistoryPage(recordsLoader: _noRecords),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('TRAINING HISTORYはまだありません'), findsOneWidget);
  });

  testWidgets('keeps the summary grid usable at iPhone-class width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('STRENGTH SESSIONS'), findsOneWidget);
    expect(find.text('STRENGTH DAYS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens exercise weight history without exposing recovery', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DataCenterTrainingHistoryPage(recordsLoader: () async => [_record()], clock: () => DateTime(2026, 8, 3))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EXERCISE'));
    await tester.pumpAndSettle();

    expect(find.text('WEIGHT HISTORY'), findsOneWidget);
    expect(find.text('LAST TRAINED'), findsOneWidget);
    expect(find.text('RECOVERY'), findsNothing);
  });

  testWidgets('switches exercise metric between weight reps and volume', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('EXERCISE'));
    await tester.pumpAndSettle();

    expect(find.text('WEIGHT HISTORY'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'REPS'));
    await tester.pumpAndSettle();
    expect(find.text('LATEST REPS'), findsOneWidget);
    expect(find.text('REPS HISTORY'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'VOLUME'));
    await tester.pumpAndSettle();
    expect(find.text('LATEST RECORDED VOLUME'), findsOneWidget);
    expect(find.text('RECORDED VOLUME HISTORY'), findsOneWidget);
    expect(find.text('RPE'), findsNothing);
    expect(find.text('WORKING VOLUME'), findsNothing);
    expect(find.text('CHANGE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps all exercise metrics usable at 320px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('EXERCISE'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'WEIGHT'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'REPS'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'VOLUME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('presents equipment as readable selector metadata', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => _recordsWithEquipment(),
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('EXERCISE'));
    await tester.pumpAndSettle();

    expect(find.text('EXERCISE'), findsWidgets);
    expect(find.text('EQUIPMENT'), findsOneWidget);
    expect(find.text('ベンチプレス'), findsOneWidget);
    expect(find.text('ダンベル'), findsOneWidget);
    expect(find.textContaining('hammer_strength'), findsNothing);
    await tester.tap(find.byKey(const Key('exercise-equipment-selector')));
    await tester.pumpAndSettle();

    expect(find.text('ALL EQUIPMENT'), findsOneWidget);
    expect(find.text('HAMMER STRENGTH パワーラック'), findsOneWidget);
    expect(find.text('EQUIPMENT NOT RECORDED'), findsOneWidget);
    await tester.tap(find.text('HAMMER STRENGTH パワーラック'));
    await tester.pumpAndSettle();
    expect(find.text('WEIGHT HISTORY'), findsOneWidget);
    expect(find.text('HAMMER STRENGTH パワーラック'), findsOneWidget);

    await tester.tap(find.byKey(const Key('exercise-equipment-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALL EQUIPMENT'));
    await tester.pumpAndSettle();
    expect(
      find.text('SELECT EQUIPMENT TO VIEW WEIGHT, REPS, OR VOLUME HISTORY'),
      findsOneWidget,
    );
    expect(find.text('WEIGHT HISTORY'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps two-line exercise selector usable at 320px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => _recordsWithEquipment(),
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('EXERCISE'));
    await tester.pumpAndSettle();

    expect(find.text('ベンチプレス'), findsOneWidget);
    expect(find.text('ダンベル'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides all equipment when a category has one variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'EXERCISE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exercise-equipment-selector')));
    await tester.pumpAndSettle();

    expect(find.text('ALL EQUIPMENT'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<List<TrainingRecordReadModel>> _noRecords() async => const [];

TrainingRecordReadModel _record() => TrainingRecordReadModel.v1(
  id: 'record',
  localDate: '2026-08-03',
  createdAt: DateTime.utc(2026, 8, 3),
  updatedAt: DateTime.utc(2026, 8, 3),
  data: TrainingSession(
    date: '2026-08-03T00:00:00.000',
    memo: '',
    exercises: [
      TrainingExercise(
        exerciseName: 'Bench Press',
        order: 1,
        sets: [const TrainingSet(setNo: 1, weight: 50, reps: 10)],
      ),
    ],
  ),
);

List<TrainingRecordReadModel> _recordsWithEquipment() => [
  _recordWithEquipment(
    id: 'rack',
    date: '2026-08-02',
    equipmentId: 'hammer_strength_power_rack',
    weight: 50,
  ),
  _recordWithEquipment(
    id: 'dumbbells',
    date: '2026-08-03',
    equipmentId: 'dumbbells',
    weight: 20,
  ),
  _recordWithEquipment(
    id: 'unrecorded',
    date: '2026-08-01',
    equipmentId: null,
    weight: 40,
  ),
];

TrainingRecordReadModel _recordWithEquipment({
  required String id,
  required String date,
  required String? equipmentId,
  required double weight,
}) => TrainingRecordReadModel.v1(
  id: id,
  localDate: date,
  createdAt: DateTime.parse('${date}T00:00:00Z'),
  updatedAt: DateTime.parse('${date}T00:00:00Z'),
  data: TrainingSession(
    date: '${date}T00:00:00.000',
    memo: '',
    exercises: [
      TrainingExercise(
        exerciseName: 'Bench Press',
        equipmentId: equipmentId,
        order: 1,
        sets: [TrainingSet(setNo: 1, weight: weight, reps: 10)],
      ),
    ],
  ),
);
