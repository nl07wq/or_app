import 'commander_analysis_snapshot.dart';
import 'commander_snapshot.dart';
import 'operation_input.dart';
import 'operation_status.dart';

class OperationEngine {
  const OperationEngine();

  double estimateTDEE(OperationInput input) {
    const bmrPerKilogram = 22.0;
    const workCaloriesPerHour = 100.0;

    final bmr = input.morning.weight * bmrPerKilogram;
    final workModifier = input.morning.workHours * workCaloriesPerHour;
    final estimatedTDEE = bmr + workModifier;

    return estimatedTDEE;
  }

  OperationStatus generateOperationStatus(OperationInput input) {
    final sleepHours =
        input.morning.sleepDuration.inMinutes / Duration.minutesPerHour;

    if (sleepHours >= 7) {
      return OperationStatus.green;
    }

    if (sleepHours >= 5) {
      return OperationStatus.yellow;
    }

    return OperationStatus.red;
  }

  CommanderSnapshot generateCommanderSnapshot(OperationInput input) {
    final status = generateOperationStatus(input);
    final food = input.food;
    final training = input.training;

    if (status == OperationStatus.red) {
      return CommanderSnapshot(
        status: status,
        commanderIntent: '回復を優先して運用する',
        summary: '睡眠が短いため、追加のトレーニングは推奨しません。',
        actions: const [
          '回復を優先する',
          '水分を補給する',
          '次の食事を整える',
        ],
      );
    }

    if (training?.completed == true) {
      return CommanderSnapshot(
        status: status,
        commanderIntent: 'トレーニング後の回復を優先する',
        summary: '本日のトレーニングは完了しています。回復を優先しましょう。',
        actions: const [
          '水分を補給する',
          'タンパク質を確保する',
          '十分な休息を取る',
        ],
      );
    }

    if (food == null || food.mealCount == 0) {
      return CommanderSnapshot(
        status: status,
        commanderIntent: '食事を記録して運用を開始する',
        summary: '本日の食事記録はまだありません。',
        actions: const [
          '最初の食事を記録する',
          'タンパク質を確保する',
          '水分を補給する',
        ],
      );
    }

    if (food.protein < 100) {
      return CommanderSnapshot(
        status: status,
        commanderIntent: 'タンパク質を優先して補給する',
        summary: '食事記録は進行中です。タンパク質を意識しましょう。',
        actions: const [
          'タンパク質を含む食事を記録する',
          '次の食事を準備する',
          '水分を補給する',
        ],
      );
    }

    return CommanderSnapshot(
      status: status,
      commanderIntent: '予定通り運用を継続する',
      summary: 'Recoveryは良好です。',
      actions: const [
        '水分を十分補給する',
        'タンパク質を確保する',
        '通常メニューで運用する',
      ],
    );
  }

  CommanderAnalysisSnapshot generateCommanderAnalysis(OperationInput input) {
    final status = generateOperationStatus(input);
    final commanderSnapshot = generateCommanderSnapshot(input);

    return CommanderAnalysisSnapshot(
      status: status,
      overview: commanderSnapshot.commanderIntent,
      recoveryAnalysis: _recoveryAnalysis(status),
      nutritionAnalysis: _nutritionAnalysis(input),
      trainingAnalysis: _trainingAnalysis(input, status),
      recommendations: commanderSnapshot.actions,
    );
  }

  String _recoveryAnalysis(OperationStatus status) {
    switch (status) {
      case OperationStatus.green:
        return 'Recoveryは良好です。';
      case OperationStatus.yellow:
        return '睡眠に余裕はありません。今日は無理を避けて運用しましょう。';
      case OperationStatus.red:
        return '睡眠不足が大きいため、休養を優先して運動を控えましょう。';
      case OperationStatus.black:
        return '緊急条件は現在のルールでは判定しません。';
    }
  }

  String _nutritionAnalysis(OperationInput input) {
    final food = input.food;

    if (food == null || food.mealCount == 0) {
      return '本日の食事記録はまだありません。';
    }

    if (food.mealCount < 3) {
      return '食事回数が目標に達していません。';
    }

    if (food.protein < 100) {
      return 'タンパク質の確保を優先しましょう。';
    }

    return '食事記録は順調に進んでいます。';
  }

  String _trainingAnalysis(OperationInput input, OperationStatus status) {
    if (input.training?.completed == true) {
      return '本日のTrainingは完了しています。回復を優先しましょう。';
    }

    if (status == OperationStatus.red) {
      return '本日はTrainingを追加せず、回復を優先しましょう。';
    }

    return 'Trainingは未実施です。実施可否はRecoveryと予定を基準に判断しましょう。';
  }
}
