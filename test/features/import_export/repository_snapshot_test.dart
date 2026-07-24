import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/features/import_export/adapters/snapshot_export_adapter.dart';
import 'package:or_app/features/import_export/adapters/snapshot_import_adapter.dart';
import 'package:or_app/features/import_export/models/repository_snapshot.dart';
import 'package:or_app/features/import_export/models/repository_update_plan.dart';
import 'package:or_app/features/import_export/services/export_service.dart';
import 'package:or_app/features/import_export/services/import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('export adapter captures an immutable repository snapshot', () async {
    await _saveRecords();

    final snapshot = await SnapshotExportAdapter.capture();

    expect(snapshot.trainingRecords, hasLength(1));
    expect(snapshot.morningFactRecords, hasLength(1));
    expect(
      () => snapshot.trainingRecords!.add(const {'date': 'later'}),
      throwsUnsupportedError,
    );
    expect(
      () =>
          (snapshot.trainingRecords!.single['exercises'] as List).add('later'),
      throwsUnsupportedError,
    );
    expect(await TrainingRepository.getAll(), hasLength(1));
    expect(await MorningRepository.getAll(), hasLength(1));
  });

  test('export and import pipeline produces a non-executable plan', () async {
    await _saveRecords();
    final json = await ExportService.exportJson(
      exportedAt: DateTime.utc(2026, 7, 25, 12),
    );

    final imported = ImportService.importJson(json);
    final plan = SnapshotImportAdapter.createPlan(imported.data!.snapshot);

    expect(imported.success, isTrue);
    expect(plan, isNotNull);
    expect(plan!.operationType, RepositoryOperationType.restore);
    expect(plan.targetRepositories, [
      RepositoryTarget.training,
      RepositoryTarget.morningFact,
    ]);
    expect(plan.records[RepositoryTarget.training], hasLength(1));
    expect(plan.records[RepositoryTarget.morningFact], hasLength(1));
    expect(
      () =>
          plan.records[RepositoryTarget.training]!.add(const {'date': 'later'}),
      throwsUnsupportedError,
    );
    expect(await TrainingRepository.getAll(), hasLength(1));
    expect(await MorningRepository.getAll(), hasLength(1));
  });

  test('import adapter rejects repository-incompatible records', () {
    final snapshot = RepositorySnapshot(
      trainingRecords: const [
        {'unsupported': true},
      ],
    );

    final plan = SnapshotImportAdapter.createPlan(snapshot);

    expect(plan, isNull);
  });
}

Future<void> _saveRecords() async {
  await TrainingRepository.save(
    TrainingSession(
      date: '2026-07-25T10:00:00.000',
      memo: '',
      exercises: const [
        TrainingExercise(
          exerciseName: 'BenchPress',
          order: 1,
          sets: [TrainingSet(setNo: 1, weight: 80, reps: 10)],
        ),
      ],
    ),
  );
  await MorningRepository.save(
    const MorningData(
      date: '2026-07-25T06:00:00.000',
      weight: 72.5,
      bodyFat: 18,
      sleepHours: 7.5,
      sleepScore: 82,
      footPain: 2,
      bowelAmount: 2,
      bowelShape: 1,
      workType: WorkType.work,
      workStart: '11:00',
      workEnd: '18:00',
      workBreak: '01:00',
      workHours: 6,
      memo: '',
    ),
  );
}
