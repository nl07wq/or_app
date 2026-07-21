import '../../../core/models/morning_data.dart';
import '../../../core/models/work_type.dart';
import '../../../core/repositories/morning_repository.dart';
import '../../../core/services/daily_log_mutation_guard.dart';
import '../../../core/services/work_calculator.dart';

import '../models/morning_fact_state.dart';

class MorningSubmitService {
  const MorningSubmitService._();

  static double? _parseTime(String text) {
    final parts = text.trim().split(':');

    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (minute < 0 || minute >= 60) return null;

    return hour + minute / 60;
  }

  static Future<String?> submit({
    MorningData? existingData,
    required WorkType workType,

    required String weightText,
    required String bodyFatText,

    required String sleepText,
    required String sleepScoreText,

    required String footPainText,

    required String bowelAmountText,
    required String bowelShapeText,

    required String workStart,
    required String workEnd,
    required String workBreak,

    required String memo,
  }) async {
    // 必須入力チェック

    if (weightText.trim().isEmpty) {
      return '体重を入力してください';
    }

    if (sleepText.trim().isEmpty) {
      return '睡眠時間を入力してください';
    }

    if (workType == WorkType.work || workType == WorkType.halfDay) {
      if (workStart.trim().isEmpty ||
          workEnd.trim().isEmpty ||
          workBreak.trim().isEmpty) {
        return '勤務時間を入力してください';
      }
    }

    // 数値変換

    final weight = double.tryParse(weightText.trim());

    if (weight == null) {
      return '体重は数字で入力してください';
    }

    final bodyFat = double.tryParse(bodyFatText.trim());

    if (bodyFat == null) {
      return '体脂肪率を入力してください';
    }

    final sleep = _parseTime(sleepText);

    if (sleep == null) {
      return '睡眠時間は 7:30 の形式で入力してください';
    }

    final sleepScore = int.tryParse(sleepScoreText.trim());

    if (sleepScore == null) {
      return '睡眠スコアを入力してください';
    }

    final double workHours =
        workType == WorkType.work || workType == WorkType.halfDay
        ? WorkCalculator.calculate(
            start: workStart,
            end: workEnd,
            workBreak: workBreak,
          )
        : 0.0;

    final date = existingData == null
        ? DateTime.now()
        : DateTime.parse(existingData.date);

    final morningData = MorningData(
      date: date.toIso8601String(),

      weight: weight,
      bodyFat: bodyFat,

      sleepHours: sleep,
      sleepScore: sleepScore,

      footPain: int.tryParse(footPainText) ?? 3,

      bowelAmount: int.tryParse(bowelAmountText) ?? 2,

      bowelShape: (int.tryParse(bowelAmountText) ?? 0) == 0
          ? 0
          : int.tryParse(bowelShapeText) ?? 2,

      workType: workType,

      workStart: workType == WorkType.work || workType == WorkType.halfDay
          ? workStart
          : "",

      workEnd: workType == WorkType.work || workType == WorkType.halfDay
          ? workEnd
          : "",

      workBreak: workType == WorkType.work || workType == WorkType.halfDay
          ? workBreak
          : "",

      workHours: workHours,

      memo: memo.trim(),
    );

    if (existingData == null) {
      await DailyLogMutationGuard.assertDateMutable(DateTime.parse(morningData.date));
      await MorningRepository.save(morningData);
    } else {
      await DailyLogMutationGuard.assertDateMutable(DateTime.parse(morningData.date));
      await MorningRepository.update(morningData);
    }

    await refreshMorningFact();

    return null;
  }
}
