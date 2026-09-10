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
    await tester.scrollUntilVisible(find.text('REPS'), 300);
    expect(find.text('REPS'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('RECORDED SETS'), 300);
    expect(find.text('RECORDED SETS'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('TRAINING FREQUENCY'), 300);
    expect(find.text('TRAINING FREQUENCY'), findsOneWidget);
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

    expect(find.text('SESSIONS'), findsOneWidget);
    expect(find.text('TRAINING DAYS'), findsOneWidget);
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
