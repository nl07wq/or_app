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
    final dashboardSummary = _dashboardSummary(status, food, training);

    return DailyOperationDecision(
      status: status,
      situation: situation,
      commanderIntent: focus.commanderIntent,
      primaryAction: focus.primaryAction,
      dashboardSummary: dashboardSummary,
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

    if (food != null && food.hydrationMl < 1000) {
      return const _DailyFocus(
        commanderIntent: '水分補給を最優先して運用を整える',
        primaryAction: 'まずは1,000 mlを目標に水分を補給する',
      );
    }

    if (food != null && food.hydrationMl < 2000) {
      return const _DailyFocus(
        commanderIntent: '水分補給を優先して安定運用を支える',
        primaryAction: '次は2,000 mlを目標に水分を補給する',
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

    if (food.hydrationMl < _hydrationTargetMl) {
      return const _DailyFocus(
        commanderIntent: '水分補給を継続して目標達成へ進める',
        primaryAction: '3,500 mlの目標まで水分補給を続ける',
      );
    }

    if (_isMaintenanceState(status, food, training)) {
      return const _DailyFocus(
        commanderIntent: '達成状態を維持し、回復を整えて一日を終える',
        primaryAction: '余分な負荷を避け、現在の計画を維持する',
      );
    }

    if (training?.completed == true) {
      return const _DailyFocus(
        commanderIntent: 'トレーニング後の回復を優先する',
        primaryAction: '水分・食事・休息を確認する',
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

    if (food != null && food.hydrationMl < 1000) {
      return '水分補給が1,000 ml未満です。まずは最低ラインを目指しましょう。';
    }

    if (food != null && food.hydrationMl < 2000) {
      return '水分補給は進んでいますが、2,000 mlの目標まで補給が必要です。';
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

    if (food.hydrationMl < _hydrationTargetMl) {
      return '水分補給は順調です。3,500 mlの目標まで続けましょう。';
    }

    if (_isMaintenanceState(status, food, training)) {
      return '食事・水分・トレーニングの主要目標は達成済みです。';
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
    if (food == null) {
      return '水分データはまだありません。';
    }

    if (food.hydrationMl < 1000) {
      return '水分補給が大きく不足しています。まずは1,000 mlを目指しましょう。';
    }

    if (food.hydrationMl < 2000) {
      return '最低ラインには近づいています。次は2,000 mlを目指しましょう。';
    }

    if (food.hydrationMl < _hydrationTargetMl) {
      return '水分補給は順調です。3,500 mlの目標まで補給を続けましょう。';
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

    final hydrationRecommendation = _hydrationRecommendation(food);

    if (status == OperationStatus.red) {
      if (hydrationRecommendation != null) {
        recommendations.add(hydrationRecommendation);
      }
      recommendations.add('トレーニングは見送り、休息を確保する');
    } else {
      if (_isMaintenanceState(status, food, training)) {
        recommendations.add('回復のための休息を確保する');
        recommendations.add('現在の計画を無理なく維持する');
      } else {
        if (hydrationRecommendation != null) {
          recommendations.add(hydrationRecommendation);
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
    }

    recommendations.remove(primaryAction);
    if (recommendations.isEmpty) {
      recommendations.add('予定と回復を確認する');
    }

    return recommendations.take(3).toList(growable: false);
  }

  String? _hydrationRecommendation(FoodSummary? food) {
    if (food == null || food.hydrationMl >= _hydrationTargetMl) {
      return null;
    }

    if (food.hydrationMl < 1000) {
      return '手元の飲み物で1,000 mlまで補給する';
    }

    if (food.hydrationMl < 2000) {
      return '次の休憩で2,000 mlに届くよう水分を補給する';
    }

    return '残りの水分を分けて補給し、3,500 mlを目指す';
  }

  bool _isMaintenanceState(
    OperationStatus status,
    FoodSummary? food,
    TrainingSummary? training,
  ) {
    return status == OperationStatus.green &&
        food != null &&
        food.mealCount >= 3 &&
        food.protein >= _proteinTargetGrams &&
        food.hydrationMl >= _hydrationTargetMl &&
        training?.completed == true;
  }

  String _dashboardSummary(
    OperationStatus status,
    FoodSummary? food,
    TrainingSummary? training,
  ) {
    if (_isMaintenanceState(status, food, training)) {
      return '本日の主要目標は達成済みです。回復を整え、安定した運用を続けましょう。';
    }

    if (status == OperationStatus.red) {
      return '回復を最優先にする日です。無理のない予定へ調整しましょう。';
    }

    if (status == OperationStatus.yellow) {
      return '回復に配慮しながら進めましょう。負荷は上げすぎないでください。';
    }

    if (food != null && food.hydrationMl < 1000) {
      return '水分補給が不足しています。まずは1,000 mlを目標にしましょう。';
    }

    if (food != null && food.hydrationMl < 2000) {
      return '水分補給を続けましょう。次は2,000 mlが目安です。';
    }

    if (food == null || food.mealCount == 0) {
      return '食事記録はまだありません。最初の食事から整えましょう。';
    }

    if (food.mealCount < 3) {
      return '食事回数が目標に届いていません。次の食事を記録しましょう。';
    }

    if (food.protein < _proteinTargetGrams) {
      return 'タンパク質の確保が必要です。次の食事で補いましょう。';
    }

    if (food.hydrationMl < _hydrationTargetMl) {
      return '水分補給は順調です。3,500 mlの目標まで続けましょう。';
    }

    if (training?.completed == true) {
      return 'トレーニングは完了しています。回復を整えて一日を締めましょう。';
    }

    return '日次運用は安定しています。現在の計画を継続しましょう。';
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
