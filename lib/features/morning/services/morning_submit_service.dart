import '../../../core/models/morning_data.dart';
import '../../../core/models/work_type.dart';
import '../../../core/repositories/morning_repository.dart';
import '../../../core/services/daily_log_mutation_guard.dart';
import '../../../core/services/work_calculator.dart';
import '../../operation_date/services/operation_date_service.dart';

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
    required SleepType sleepType,

    required String footPainText,

    required String workStart,
    required String workEnd,
    required String workBreak,

    required String memo,
    OperationDateService? operationDateService,
    String? operationLocalDate,
  }) async {
    // 必須入力チェック

    if (workType == WorkType.work || workType == WorkType.halfDay) {
      if (workStart.trim().isEmpty ||
          workEnd.trim().isEmpty ||
          workBreak.trim().isEmpty) {
        return '勤務時間を入力してください';
      }
    }

    // 数値変換

    final weightInput = weightText.trim();
    final weight = weightInput.isEmpty ? null : double.tryParse(weightInput);

    if (weightInput.isNotEmpty && weight == null) {
      return '体重は数字で入力してください';
    }

    final bodyFatInput = bodyFatText.trim();
    final bodyFat = bodyFatInput.isEmpty ? null : double.tryParse(bodyFatInput);

    if (bodyFatInput.isNotEmpty && bodyFat == null) {
      return '体脂肪率を入力してください';
    }

    final sleepInput = sleepText.trim();
    final sleep = sleepInput.isEmpty ? null : _parseTime(sleepInput);

    if (sleepInput.isNotEmpty && sleep == null) {
      return '睡眠時間は 7:30 の形式で入力してください';
    }

    final sleepScoreInput = sleepScoreText.trim();
    final sleepScore = sleepScoreInput.isEmpty
        ? null
        : int.tryParse(sleepScoreInput);

    if (sleepScoreInput.isNotEmpty && sleepScore == null) {
      return '睡眠スコアを入力してください';
    }
    if (sleepScore != null && (sleepScore < 0 || sleepScore > 100)) {
      return '睡眠スコアは0から100で入力してください';
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
        ? DateTime.parse(
            operationLocalDate ??
                (await (operationDateService ?? const OperationDateService())
                        .current())
                    .value,
          )
        : DateTime.parse(existingData.date);

    final morningData = MorningData(
      date: date.toIso8601String(),

      weight: weight,
      bodyFat: bodyFat,

      sleepHours: sleep,
      sleepScore: sleepScore,
      sleepType: sleepType,

      footPain: int.tryParse(footPainText) ?? 3,
      condition: existingData?.condition,
      previousCarryoverConfirmed: existingData?.previousCarryoverConfirmed,

      // Preserve legacy data when editing. New Morning records leave bowel
      // movement unconfirmed because Activity is now authoritative.
      bowelAmount: existingData?.bowelAmount,
      bowelShape: existingData?.bowelShape,

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
      await DailyLogMutationGuard.assertDateMutable(
        DateTime.parse(morningData.date),
      );
      await MorningRepository.save(morningData);
    } else {
      final date = DateTime.parse(morningData.date);
      await DailyLogMutationGuard.assertDateMutable(date);
      await MorningRepository.update(morningData);
      final records = await MorningRepository.getAll();
      final localDate = morningData.date.substring(0, 10);
      final readBack = records.where(
        (record) => record.date.substring(0, 10) == localDate,
      );
      if (readBack.length != 1 ||
          readBack.single.toJson().toString() !=
              morningData.toJson().toString()) {
        throw StateError('targetRecordReadBackFailed');
      }
    }

    await refreshMorningFact(localDate: morningData.date.substring(0, 10));

    return null;
  }
}
