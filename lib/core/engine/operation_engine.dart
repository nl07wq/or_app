import 'dart:collection';

import 'commander_analysis_snapshot.dart';
import 'commander_snapshot.dart';
import 'daily_operation_decision.dart';
import 'food_summary.dart';
import 'operation_input.dart';
import 'operation_status.dart';
import 'training_summary.dart';

class OperationEngine {
  const OperationEngine();

  static const _hydrationTargetMl = 3500.0;
  static const _proteinTargetGrams = 100.0;

  double estimateTDEE(OperationInput input) {
    const bmrPerKilogram = 22.0;
    const workCaloriesPerHour = 100.0;

    final bmr = input.morning.weight * bmrPerKilogram;
    final workModifier = input.morning.workHours * workCaloriesPerHour;
    return bmr + workModifier;
  }

  OperationStatus generateOperationStatus(OperationInput input) {
    final sleepHours =
        input.morning.sleepDuration.inMinutes / Duration.minutesPerHour;

    if (sleepHours >= 7) return OperationStatus.green;
    if (sleepHours >= 5) return OperationStatus.yellow;
    return OperationStatus.red;
  }

  CommanderSnapshot generateCommanderSnapshot(OperationInput input) {
    final decision = _generateDailyDecision(input);

    return CommanderSnapshot(
      status: decision.status,
      commanderIntent: decision.commanderIntent,
      summary: decision.dashboardSummary,
      actions: decision.recommendations,
    );
  }

  CommanderAnalysisSnapshot generateCommanderAnalysis(OperationInput input) {
    final decision = _generateDailyDecision(input);

    return CommanderAnalysisSnapshot(
      status: decision.status,
      situation: decision.situation,
      commanderIntent: decision.commanderIntent,
      primaryAction: decision.primaryAction,
      dashboardSummary: decision.dashboardSummary,
      recoveryAnalysis: decision.recoveryAnalysis,
      nutritionAnalysis: decision.nutritionAnalysis,
      hydrationAnalysis: decision.hydrationAnalysis,
      trainingAnalysis: decision.trainingAnalysis,
      recommendations: decision.recommendations,
    );
  }

  DailyOperationDecision _generateDailyDecision(OperationInput input) {
    final status = generateOperationStatus(input);
    final food = input.food;
    final training = input.training;
    final recoveryAnalysis = _recoveryAnalysis(status);
    final nutritionAnalysis = _nutritionAnalysis(food);
    final hydrationAnalysis = _hydrationAnalysis(food);
    final trainingAnalysis = _trainingAnalysis(training, status);
    final focus = _focus(status, food, training);
    final situation = _situation(status, food, training);

    return DailyOperationDecision(
      status: status,
      situation: situation,
      commanderIntent: focus.commanderIntent,
      primaryAction: focus.primaryAction,
      dashboardSummary: '$situation ${focus.primaryAction}',
      recoveryAnalysis: recoveryAnalysis,
      nutritionAnalysis: nutritionAnalysis,
      hydrationAnalysis: hydrationAnalysis,
      trainingAnalysis: trainingAnalysis,
      recommendations: _recommendations(
        status: status,
        food: food,
        training: training,
        primaryAction: focus.primaryAction,
      ),
    );
  }

  _DailyFocus _focus(
    OperationStatus status,
    FoodSummary? food,
    TrainingSummary? training,
  ) {
    if (status == OperationStatus.red) {
      return const _DailyFocus(
        commanderIntent: '回復を最優先にして負荷を抑える',
        primaryAction: '予定を軽くし、休息を確保する',
      );
    }

    if (status == OperationStatus.yellow) {
      return const _DailyFocus(
        commanderIntent: '無理を避けて安定運用を続ける',
        primaryAction: '負荷を上げず、基本行動を整える',
      );
    }

    if (food != null && food.hydrationMl < _hydrationTargetMl) {
      return const _DailyFocus(
        commanderIntent: '水分補給を優先して運用を整える',
        primaryAction: '次の機会に水分を補給する',
      );
    }

    if (food == null || food.mealCount == 0) {
      return const _DailyFocus(
        commanderIntent: '食事記録を開始して基盤を整える',
        primaryAction: '最初の食事を記録する',
      );
    }

    if (food.mealCount < 3) {
      return const _DailyFocus(
        commanderIntent: '食事回数を目標に近づける',
        primaryAction: '次の食事を記録する',
      );
    }

    if (food.protein < _proteinTargetGrams) {
      return const _DailyFocus(
        commanderIntent: 'タンパク質の確保を優先する',
        primaryAction: 'タンパク質を含む食事を選ぶ',
      );
    }

    if (training?.completed == true) {
      return const _DailyFocus(
        commanderIntent: '完了したトレーニング後の回復を整える',
        primaryAction: '回復と次の食事を整える',
      );
    }

    return const _DailyFocus(
      commanderIntent: '基本行動を継続して運用を進める',
      primaryAction: '予定と体調を確認して次の行動を選ぶ',
    );
  }

  String _situation(
    OperationStatus status,
    FoodSummary? food,
    TrainingSummary? training,
  ) {
    if (status == OperationStatus.red) {
      return '睡眠不足により回復を優先する状態です。';
    }

    if (status == OperationStatus.yellow) {
      return '回復に配慮しながら安定して進める状態です。';
    }

    if (food != null && food.hydrationMl == 0) {
      return '水分記録はまだありません。';
    }

    if (food != null && food.hydrationMl < _hydrationTargetMl) {
      return '水分補給が目標に達していません。';
    }

    if (food == null || food.mealCount == 0) {
      return '本日の食事記録はまだありません。';
    }

    if (food.mealCount < 3) {
      return '食事回数が目標に達していません。';
    }

    if (food.protein < _proteinTargetGrams) {
      return 'タンパク質の確保が必要です。';
    }

    if (training?.completed == true) {
      return '本日のトレーニングは完了しています。';
    }

    return '日次運用は安定して進んでいます。';
  }

  String _recoveryAnalysis(OperationStatus status) {
    switch (status) {
      case OperationStatus.green:
        return '睡眠は良好です。通常の計画で運用できます。';
      case OperationStatus.yellow:
        return '睡眠に配慮が必要です。無理のない負荷で進めましょう。';
      case OperationStatus.red:
        return '睡眠不足が大きいため、今日は回復を優先しましょう。';
      case OperationStatus.black:
        return '緊急状態です。通常運用を停止して状況を確認してください。';
    }
  }

  String _nutritionAnalysis(FoodSummary? food) {
    if (food == null || food.mealCount == 0) {
      return '本日の食事記録はまだありません。';
    }

    if (food.mealCount < 3 && food.protein < _proteinTargetGrams) {
      return '食事回数とタンパク質の両方が目標に達していません。';
    }

    if (food.mealCount < 3) {
      return '食事回数が目標に達していません。';
    }

    if (food.protein < _proteinTargetGrams) {
      return 'タンパク質の確保を意識しましょう。';
    }

    return '食事回数とタンパク質は目標に達しています。';
  }

  String _hydrationAnalysis(FoodSummary? food) {
    if (food == null || food.hydrationMl == 0) {
      return '水分記録はまだありません。';
    }

    if (food.hydrationMl < _hydrationTargetMl) {
      return '水分補給が目標に達していません。';
    }

    return '水分目標を達成しています。';
  }

  String _trainingAnalysis(
    TrainingSummary? training,
    OperationStatus status,
  ) {
    if (training?.completed == true) {
      return '本日のトレーニングは完了しています。回復を整えましょう。';
    }

    if (status == OperationStatus.red) {
      return '今日は追加のトレーニングを避け、回復を優先しましょう。';
    }

    return 'トレーニングは未実施です。回復と予定を見て判断しましょう。';
  }

  List<String> _recommendations({
    required OperationStatus status,
    required FoodSummary? food,
    required TrainingSummary? training,
    required String primaryAction,
  }) {
    final recommendations = LinkedHashSet<String>();

    if (status == OperationStatus.red) {
      recommendations.add('水分と食事を無理のない範囲で整える');
      recommendations.add('トレーニングは見送り、休息を確保する');
    } else {
      if (food == null || food.hydrationMl < _hydrationTargetMl) {
        recommendations.add('水分を補給する');
      }
      if (food == null || food.mealCount == 0) {
        recommendations.add('最初の食事を記録する');
      } else if (food.mealCount < 3) {
        recommendations.add('次の食事を記録する');
      }
      if (food != null && food.protein < _proteinTargetGrams) {
        recommendations.add('タンパク質を含む食事を選ぶ');
      }
      if (training?.completed == true) {
        recommendations.add('トレーニング後の回復を整える');
      }
    }

    recommendations.remove(primaryAction);
    if (recommendations.isEmpty) {
      recommendations.add('予定と回復を確認する');
    }

    return recommendations.take(3).toList(growable: false);
  }
}

class _DailyFocus {
  final String commanderIntent;
  final String primaryAction;

  const _DailyFocus({
    required this.commanderIntent,
    required this.primaryAction,
  });
}
