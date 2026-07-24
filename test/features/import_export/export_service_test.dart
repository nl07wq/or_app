import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/features/import_export/models/export_data.dart';
import 'package:or_app/features/import_export/services/export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'exports a versioned UTF-8 JSON snapshot without modifying data',
    () async {
      final trainingSession = TrainingSession(
        date: '2026-07-25T10:00:00.000',
        memo: '脚の日',
        exercises: [
          TrainingExercise(
            exerciseName: 'HackSquat',
            equipmentId: 'hack_squat_machine',
            order: 1,
            sets: [TrainingSet(setNo: 1, weight: 80, reps: 10)],
          ),
        ],
      );
      const morningRecord = MorningData(
        date: '2026-07-25T06:00:00.000',
        weight: 72.5,
        bodyFat: 18.2,
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
        memo: '通常',
      );
      await TrainingRepository.save(trainingSession);
      await MorningRepository.save(morningRecord);
      final exportedAt = DateTime.utc(2026, 7, 25, 12, 30);

      final json = await ExportService.exportJson(
        exportedAt: exportedAt,
        applicationVersion: '1.0.0',
        devicePlatform: 'web',
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(utf8.decode(utf8.encode(json)), json);
      expect(decoded['schemaVersion'], ExportData.currentSchemaVersion);
      expect(decoded['exportedAt'], '2026-07-25T12:30:00.000Z');
      expect(decoded['metadata'], {
        'applicationVersion': '1.0.0',
        'devicePlatform': 'web',
      });
      expect((decoded['training'] as List).single['memo'], '脚の日');
      expect((decoded['morningFact'] as List).single['sleepScore'], 82);

      final trainingAfterExport = await TrainingRepository.getAll();
      final morningAfterExport = await MorningRepository.getAll();
      expect(trainingAfterExport, hasLength(1));
      expect(trainingAfterExport.single.toJson(), trainingSession.toJson());
      expect(morningAfterExport, hasLength(1));
      expect(morningAfterExport.single.toJson(), morningRecord.toJson());
    },
  );

  test('omits empty optional data sections', () async {
    final data = await ExportService.collect(
      exportedAt: DateTime.utc(2026, 7, 25),
    );
    final json = data.toJson();

    expect(json['schemaVersion'], '1.0');
    expect(json.containsKey('training'), isFalse);
    expect(json.containsKey('morningFact'), isFalse);
    expect(json['metadata'], isEmpty);
  });

  test('ExportData protects captured sections from mutation', () {
    final data = ExportData(
      schemaVersion: '1.0',
      exportedAt: DateTime.utc(2026, 7, 25),
      training: const [
        {
          'exercises': [
            {'name': 'BenchPress'},
          ],
        },
      ],
    );

    expect(
      () => data.training!.add(const {'date': 'later'}),
      throwsUnsupportedError,
    );
    expect(
      () => (data.training!.single['exercises'] as List).add('later'),
      throwsUnsupportedError,
    );
  });
}
