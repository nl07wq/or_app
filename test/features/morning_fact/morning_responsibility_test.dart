import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/features/morning/services/morning_submit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new Morning save leaves bowel movement unconfirmed', () async {
    final error = await MorningSubmitService.submit(
      workType: WorkType.holiday,
      weightText: '72.5',
      bodyFatText: '18',
      sleepText: '7:30',
      sleepScoreText: '80',
      footPainText: '2',
      workStart: '',
      workEnd: '',
      workBreak: '',
      memo: '',
    );

    expect(error, isNull);
    final saved = (await MorningRepository.getAll()).single;
    expect(saved.bowelAmount, isNull);
    expect(saved.bowelShape, isNull);
  });

  test(
    'editing Morning preserves legacy bowel values without new input',
    () async {
      final legacy = MorningData(
        date: DateTime.now().toIso8601String(),
        weight: 72.5,
        bodyFat: 18,
        sleepHours: 7.5,
        sleepScore: 80,
        footPain: 2,
        bowelAmount: 3,
        bowelShape: 2,
        workType: WorkType.holiday,
        workStart: '',
        workEnd: '',
        workBreak: '',
        workHours: 0,
        memo: '',
      );
      await MorningRepository.save(legacy);

      final error = await MorningSubmitService.submit(
        existingData: legacy,
        workType: WorkType.holiday,
        weightText: '73',
        bodyFatText: '18',
        sleepText: '7:30',
        sleepScoreText: '80',
        footPainText: '2',
        workStart: '',
        workEnd: '',
        workBreak: '',
        memo: '',
      );

      expect(error, isNull);
      final saved = (await MorningRepository.getAll()).single;
      expect(saved.bowelAmount, 3);
      expect(saved.bowelShape, 2);
    },
  );
}
