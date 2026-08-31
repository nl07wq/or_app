import '../../../core/models/work_type.dart';
import '../../body_history/models/body_history_models.dart';
import '../models/daily_assessment.dart';

class DailyAssessmentRuleEngine {
  const DailyAssessmentRuleEngine();

  DailyAssessment evaluate(DailyAssessmentFacts facts) {
    final status = facts.currentStatus;
    final hasStatus = status != null;
    final sleepTime = hasStatus
        ? _sleepTime(status.sleepHours)
        : _notAvailable(
            DailyAssessmentModule.recovery,
            DailyAssessmentMetric.sleepTime,
          );
    final sleepScore = hasStatus
        ? _sleepScore(status.sleepScore)
        : _notAvailable(
            DailyAssessmentModule.recovery,
            DailyAssessmentMetric.sleepScore,
          );
    final plantar = hasStatus
        ? _plantar(status.footPain)
        : _notAvailable(
            DailyAssessmentModule.condition,
            DailyAssessmentMetric.plantarFasciitis,
          );
    final work = hasStatus
        ? _work(status.workType, status.workHours)
        : _notAvailable(
            DailyAssessmentModule.workLoad,
            DailyAssessmentMetric.work,
          );
    final weight = hasStatus
        ? facts.currentWeightReference.source ==
                  DailyWeightReferenceSource.measuredToday
              ? _dailyWeightChange(facts.currentWeightReference)
              : _weightTrend(facts.weightHistory)
        : _notAvailable(
            DailyAssessmentModule.body,
            DailyAssessmentMetric.weightTrend,
          );
    final calorie = _calorieBalance(facts.currentCalorieBalanceKcal);
    final protein = _protein(facts.currentProteinG);
    final hydration = _hydration(facts.currentHydrationMl);
    final steps = _steps(facts.currentOfficialSteps);
    final training = _training(facts.trainingReadiness);
    final assessments = [
      weight,
      sleepTime,
      sleepScore,
      plantar,
      work,
      calorie,
      protein,
      hydration,
      steps,
      training,
    ];
    final recoveryLevel = _worse(sleepTime.level, sleepScore.level);
    final constraints = <_Constraint>[];

    for (final item in assessments) {
      final level = item.level;
      if (level == null ||
          _severity(level) < _severity(DailyAssessmentLevel.watch)) {
        continue;
      }
      final label = _constraintLabel(item);
      if (label != null) constraints.add(_Constraint(label, level));
    }

    if (sleepTime.level == DailyAssessmentLevel.limit &&
        work.level == DailyAssessmentLevel.watch) {
      constraints.add(
        const _Constraint(
          'SLEEP × HIGH WORK LOAD',
          DailyAssessmentLevel.adjust,
        ),
      );
    }
    if (sleepTime.level == DailyAssessmentLevel.limit &&
        work.level == DailyAssessmentLevel.adjust) {
      constraints.add(
        const _Constraint(
          'SLEEP × EXTENDED WORK LOAD',
          DailyAssessmentLevel.limit,
        ),
      );
    }
    if ((status?.footPain ?? 0) >= 4 &&
        (facts.currentOfficialSteps ?? 0) > 12000) {
      constraints.add(_Constraint('FOOT LOAD CONSTRAINT', plantar.level!));
    }
    if (_atLeast(calorie.level, DailyAssessmentLevel.adjust) &&
        _atLeast(sleepTime.level, DailyAssessmentLevel.watch)) {
      constraints.add(
        const _Constraint('RECOVERY PRIORITY', DailyAssessmentLevel.adjust),
      );
    }
    if (_atLeast(protein.level, DailyAssessmentLevel.watch) &&
        facts.currentStrengthTrainingPerformed) {
      constraints.add(
        const _Constraint('NUTRITION PRIORITY', DailyAssessmentLevel.watch),
      );
    }
    if (_atLeast(hydration.level, DailyAssessmentLevel.watch) &&
        _atLeast(work.level, DailyAssessmentLevel.watch)) {
      constraints.add(
        const _Constraint('HYDRATION PRIORITY', DailyAssessmentLevel.watch),
      );
    }

    constraints.sort(
      (first, second) =>
          _severity(second.level).compareTo(_severity(first.level)),
    );
    final resources = <String>[];
    if (recoveryLevel == DailyAssessmentLevel.support) {
      resources.add('RECOVERY CAPACITY');
    }
    if (work.specificAssessment == 'REST DAY') resources.add('REST DAY');
    if (training.level == DailyAssessmentLevel.support) {
      resources.add('TRAINING READINESS');
    }

    return DailyAssessment(
      operationDate: facts.operationDate,
      assessments: assessments,
      primaryConstraints: _unique(constraints.map((value) => value.label)),
      availableResources: _unique(resources),
      currentWeightReference: facts.currentWeightReference,
      currentBodyFatPercent: status?.bodyFat,
      previousFormalBodyFatPercent: facts.previousFormalBodyFatPercent,
      workDisplayValue: facts.workDisplayValue,
    );
  }

  DailyAssessmentItem _sleepTime(double? hours) {
    if (hours == null) {
      return _notAvailable(
        DailyAssessmentModule.recovery,
        DailyAssessmentMetric.sleepTime,
      );
    }
    final minutes = (hours * 60).round();
    if (minutes >= 420) {
      return _item(
        DailyAssessmentModule.recovery,
        DailyAssessmentMetric.sleepTime,
        minutes,
        'SUFFICIENT',
        DailyAssessmentLevel.support,
      );
    }
    if (minutes >= 360) {
      return _item(
        DailyAssessmentModule.recovery,
        DailyAssessmentMetric.sleepTime,
        minutes,
        'ADEQUATE',
        DailyAssessmentLevel.stable,
      );
    }
    if (minutes >= 300) {
      return _item(
        DailyAssessmentModule.recovery,
        DailyAssessmentMetric.sleepTime,
        minutes,
        'SHORT',
        DailyAssessmentLevel.watch,
      );
    }
    if (minutes >= 240) {
      return _item(
        DailyAssessmentModule.recovery,
        DailyAssessmentMetric.sleepTime,
        minutes,
        'LOW',
        DailyAssessmentLevel.adjust,
      );
    }
    return _item(
      DailyAssessmentModule.recovery,
      DailyAssessmentMetric.sleepTime,
      minutes,
      'SEVERELY SHORT',
      DailyAssessmentLevel.limit,
    );
  }

  DailyAssessmentItem _sleepScore(int? score) {
    if (score == null) {
      return _notAvailable(
        DailyAssessmentModule.recovery,
        DailyAssessmentMetric.sleepScore,
      );
    }
    if (score >= 85) {
      return _item(
        DailyAssessmentModule.recovery,
        DailyAssessmentMetric.sleepScore,
        score,
        'GOOD',
        DailyAssessmentLevel.support,
      );
    }
    if (score >= 75) {
      return _item(
        DailyAssessmentModule.recovery,
        DailyAssessmentMetric.sleepScore,
        score,
        'NORMAL',
        DailyAssessmentLevel.stable,
      );
    }
    if (score >= 65) {
      return _item(
        DailyAssessmentModule.recovery,
        DailyAssessmentMetric.sleepScore,
        score,
        'FAIR',
        DailyAssessmentLevel.watch,
      );
    }
    if (score >= 50) {
      return _item(
        DailyAssessmentModule.recovery,
        DailyAssessmentMetric.sleepScore,
        score,
        'LOW',
        DailyAssessmentLevel.adjust,
      );
    }
    return _item(
      DailyAssessmentModule.recovery,
      DailyAssessmentMetric.sleepScore,
      score,
      'VERY LOW',
      DailyAssessmentLevel.limit,
    );
  }

  DailyAssessmentItem _plantar(int? level) {
    const labels = {
      1: ('LOW', DailyAssessmentLevel.support),
      2: ('CONTROLLED', DailyAssessmentLevel.stable),
      3: ('MODERATE', DailyAssessmentLevel.watch),
      4: ('HIGH', DailyAssessmentLevel.adjust),
      5: ('SEVERE CONSTRAINT', DailyAssessmentLevel.limit),
    };
    final result = labels[level];
    if (result == null) {
      return _notAvailable(
        DailyAssessmentModule.condition,
        DailyAssessmentMetric.plantarFasciitis,
      );
    }
    return _item(
      DailyAssessmentModule.condition,
      DailyAssessmentMetric.plantarFasciitis,
      level,
      result.$1,
      result.$2,
    );
  }

  DailyAssessmentItem _work(WorkType? type, double? hours) {
    if (type == null || hours == null) {
      return _notAvailable(
        DailyAssessmentModule.workLoad,
        DailyAssessmentMetric.work,
      );
    }
    if (type == WorkType.holiday) {
      return _item(
        DailyAssessmentModule.workLoad,
        DailyAssessmentMetric.work,
        'HOLIDAY',
        'REST DAY',
        DailyAssessmentLevel.support,
      );
    }
    if (!type.isWorking || hours <= 0) {
      return _notAvailable(
        DailyAssessmentModule.workLoad,
        DailyAssessmentMetric.work,
      );
    }
    if (hours <= 8) {
      return _item(
        DailyAssessmentModule.workLoad,
        DailyAssessmentMetric.work,
        hours,
        'STANDARD LOAD',
        DailyAssessmentLevel.stable,
      );
    }
    if (hours <= 10) {
      return _item(
        DailyAssessmentModule.workLoad,
        DailyAssessmentMetric.work,
        hours,
        'HIGH LOAD',
        DailyAssessmentLevel.watch,
      );
    }
    return _item(
      DailyAssessmentModule.workLoad,
      DailyAssessmentMetric.work,
      hours,
      'EXTENDED LOAD',
      DailyAssessmentLevel.adjust,
    );
  }

  DailyAssessmentItem _weightTrend(List<BodyHistoryDataPoint> history) {
    final validPoints =
        history
            .where(
              (point) => point.weightKg != null && point.weightKg!.isFinite,
            )
            .toList()
          ..sort(
            (first, second) =>
                first.operationDate.compareTo(second.operationDate),
          );
    if (validPoints.length < 14) {
      return _notAvailable(
        DailyAssessmentModule.body,
        DailyAssessmentMetric.weightTrend,
      );
    }
    final points = validPoints.sublist(validPoints.length - 14);
    final previous =
        points.take(7).fold<double>(0, (sum, point) => sum + point.weightKg!) /
        7;
    final recent =
        points.skip(7).fold<double>(0, (sum, point) => sum + point.weightKg!) /
        7;
    final change = double.parse((recent - previous).toStringAsFixed(6));
    if (change < -0.90) {
      return _item(
        DailyAssessmentModule.body,
        DailyAssessmentMetric.weightTrend,
        change,
        'RAPID LOSS',
        DailyAssessmentLevel.watch,
      );
    }
    if (change <= -0.30) {
      return _item(
        DailyAssessmentModule.body,
        DailyAssessmentMetric.weightTrend,
        change,
        'ON TRACK',
        DailyAssessmentLevel.support,
      );
    }
    if (change < -0.10) {
      return _item(
        DailyAssessmentModule.body,
        DailyAssessmentMetric.weightTrend,
        change,
        'SLOW PROGRESS',
        DailyAssessmentLevel.stable,
      );
    }
    if (change <= 0.10) {
      return _item(
        DailyAssessmentModule.body,
        DailyAssessmentMetric.weightTrend,
        change,
        'PLATEAU WATCH',
        DailyAssessmentLevel.watch,
      );
    }
    return _item(
      DailyAssessmentModule.body,
      DailyAssessmentMetric.weightTrend,
      change,
      'UPWARD TREND',
      DailyAssessmentLevel.adjust,
    );
  }

  DailyAssessmentItem _dailyWeightChange(DailyWeightReference reference) {
    final today = reference.valueKg;
    final previous = reference.previousFormalWeightKg;
    if (today == null || previous == null) {
      return _notAvailable(
        DailyAssessmentModule.body,
        DailyAssessmentMetric.weightTrend,
      );
    }
    final change = double.parse((today - previous).toStringAsFixed(6));
    if (change < 0) {
      return _item(
        DailyAssessmentModule.body,
        DailyAssessmentMetric.weightTrend,
        change,
        'DECREASED FROM PREVIOUS',
        DailyAssessmentLevel.support,
      );
    }
    if (change > 0) {
      return _item(
        DailyAssessmentModule.body,
        DailyAssessmentMetric.weightTrend,
        change,
        'INCREASED FROM PREVIOUS',
        DailyAssessmentLevel.watch,
      );
    }
    return _item(
      DailyAssessmentModule.body,
      DailyAssessmentMetric.weightTrend,
      change,
      'UNCHANGED FROM PREVIOUS',
      DailyAssessmentLevel.stable,
    );
  }

  DailyAssessmentItem _calorieBalance(double? value) {
    if (value == null) {
      return _notAvailable(
        DailyAssessmentModule.calorieBalance,
        DailyAssessmentMetric.calorieBalance,
      );
    }
    if (value < -1300) {
      return _item(
        DailyAssessmentModule.calorieBalance,
        DailyAssessmentMetric.calorieBalance,
        value,
        'EXTREME DEFICIT',
        DailyAssessmentLevel.limit,
      );
    }
    if (value < -1000) {
      return _item(
        DailyAssessmentModule.calorieBalance,
        DailyAssessmentMetric.calorieBalance,
        value,
        'VERY LARGE DEFICIT',
        DailyAssessmentLevel.adjust,
      );
    }
    if (value < -800) {
      return _item(
        DailyAssessmentModule.calorieBalance,
        DailyAssessmentMetric.calorieBalance,
        value,
        'LARGE DEFICIT',
        DailyAssessmentLevel.watch,
      );
    }
    if (value <= -300) {
      return _item(
        DailyAssessmentModule.calorieBalance,
        DailyAssessmentMetric.calorieBalance,
        value,
        'TARGET DEFICIT',
        DailyAssessmentLevel.support,
      );
    }
    if (value <= 200) {
      return _item(
        DailyAssessmentModule.calorieBalance,
        DailyAssessmentMetric.calorieBalance,
        value,
        'NEAR BALANCE',
        DailyAssessmentLevel.stable,
      );
    }
    if (value <= 500) {
      return _item(
        DailyAssessmentModule.calorieBalance,
        DailyAssessmentMetric.calorieBalance,
        value,
        'SURPLUS WATCH',
        DailyAssessmentLevel.watch,
      );
    }
    return _item(
      DailyAssessmentModule.calorieBalance,
      DailyAssessmentMetric.calorieBalance,
      value,
      'HIGH SURPLUS',
      DailyAssessmentLevel.adjust,
    );
  }

  DailyAssessmentItem _protein(double? value) {
    if (value == null) {
      return _notAvailable(
        DailyAssessmentModule.nutrition,
        DailyAssessmentMetric.protein,
      );
    }
    if (value >= 130) {
      return _item(
        DailyAssessmentModule.nutrition,
        DailyAssessmentMetric.protein,
        value,
        'TARGET MET',
        DailyAssessmentLevel.support,
      );
    }
    if (value >= 110) {
      return _item(
        DailyAssessmentModule.nutrition,
        DailyAssessmentMetric.protein,
        value,
        'ADEQUATE',
        DailyAssessmentLevel.stable,
      );
    }
    if (value >= 90) {
      return _item(
        DailyAssessmentModule.nutrition,
        DailyAssessmentMetric.protein,
        value,
        'BELOW TARGET',
        DailyAssessmentLevel.watch,
      );
    }
    if (value >= 70) {
      return _item(
        DailyAssessmentModule.nutrition,
        DailyAssessmentMetric.protein,
        value,
        'LOW',
        DailyAssessmentLevel.adjust,
      );
    }
    return _item(
      DailyAssessmentModule.nutrition,
      DailyAssessmentMetric.protein,
      value,
      'VERY LOW',
      DailyAssessmentLevel.limit,
    );
  }

  DailyAssessmentItem _hydration(double? value) {
    if (value == null) {
      return _notAvailable(
        DailyAssessmentModule.hydration,
        DailyAssessmentMetric.hydration,
      );
    }
    if (value >= 2500) {
      return _item(
        DailyAssessmentModule.hydration,
        DailyAssessmentMetric.hydration,
        value,
        'TARGET MET',
        DailyAssessmentLevel.support,
      );
    }
    if (value >= 2000) {
      return _item(
        DailyAssessmentModule.hydration,
        DailyAssessmentMetric.hydration,
        value,
        'ADEQUATE',
        DailyAssessmentLevel.stable,
      );
    }
    if (value >= 1500) {
      return _item(
        DailyAssessmentModule.hydration,
        DailyAssessmentMetric.hydration,
        value,
        'BELOW TARGET',
        DailyAssessmentLevel.watch,
      );
    }
    if (value >= 1000) {
      return _item(
        DailyAssessmentModule.hydration,
        DailyAssessmentMetric.hydration,
        value,
        'LOW',
        DailyAssessmentLevel.adjust,
      );
    }
    return _item(
      DailyAssessmentModule.hydration,
      DailyAssessmentMetric.hydration,
      value,
      'VERY LOW',
      DailyAssessmentLevel.limit,
    );
  }

  DailyAssessmentItem _steps(int? value) {
    if (value == null) {
      return _notAvailable(
        DailyAssessmentModule.recentLoad,
        DailyAssessmentMetric.steps,
      );
    }
    if (value <= 6000) {
      return _item(
        DailyAssessmentModule.recentLoad,
        DailyAssessmentMetric.steps,
        value,
        'LOW LOAD',
        DailyAssessmentLevel.stable,
      );
    }
    if (value <= 10000) {
      return _item(
        DailyAssessmentModule.recentLoad,
        DailyAssessmentMetric.steps,
        value,
        'MODERATE LOAD',
        DailyAssessmentLevel.stable,
      );
    }
    if (value <= 14000) {
      return _item(
        DailyAssessmentModule.recentLoad,
        DailyAssessmentMetric.steps,
        value,
        'HIGH LOAD',
        DailyAssessmentLevel.watch,
      );
    }
    return _item(
      DailyAssessmentModule.recentLoad,
      DailyAssessmentMetric.steps,
      value,
      'VERY HIGH LOAD',
      DailyAssessmentLevel.adjust,
    );
  }

  DailyAssessmentItem _item(
    DailyAssessmentModule module,
    DailyAssessmentMetric metric,
    Object? rawValue,
    String assessment,
    DailyAssessmentLevel level,
  ) => DailyAssessmentItem(
    module: module,
    metric: metric,
    rawValue: rawValue,
    specificAssessment: assessment,
    level: level,
  );

  DailyAssessmentItem _training(TrainingReadinessFacts? facts) {
    if (facts == null) {
      return _notAvailable(
        DailyAssessmentModule.training,
        DailyAssessmentMetric.trainingReadiness,
      );
    }
    final hours = facts.lastTraining.thresholdHours;
    final base = hours < 24
        ? DailyAssessmentLevel.adjust
        : hours < 36
        ? DailyAssessmentLevel.watch
        : hours < 72
        ? DailyAssessmentLevel.stable
        : DailyAssessmentLevel.support;
    final sessionShift = facts.last7DaysSessionCount >= 5
        ? 2
        : facts.last7DaysSessionCount == 4
        ? 1
        : 0;
    final consecutiveShift = facts.consecutiveTrainingDays >= 3 ? 1 : 0;
    final shift = sessionShift > consecutiveShift
        ? sessionShift
        : consecutiveShift;
    final adjustedIndex = (base.index + shift).clamp(
      DailyAssessmentLevel.support.index,
      DailyAssessmentLevel.adjust.index,
    );
    final level = DailyAssessmentLevel.values[adjustedIndex];
    final assessment = shift > 0
        ? switch (level) {
            DailyAssessmentLevel.stable => 'FREQUENCY MODERATED',
            DailyAssessmentLevel.watch => 'FREQUENCY WATCH',
            DailyAssessmentLevel.adjust => 'FREQUENCY ADJUSTMENT',
            _ => 'SUFFICIENT INTERVAL',
          }
        : switch (level) {
            DailyAssessmentLevel.support => 'SUFFICIENT INTERVAL',
            DailyAssessmentLevel.stable => 'STANDARD INTERVAL',
            DailyAssessmentLevel.watch => 'SHORT INTERVAL WATCH',
            DailyAssessmentLevel.adjust => 'LOAD ADJUSTMENT',
            DailyAssessmentLevel.limit => 'LOAD ADJUSTMENT',
          };
    return _item(
      DailyAssessmentModule.training,
      DailyAssessmentMetric.trainingReadiness,
      facts,
      assessment,
      level,
    );
  }

  DailyAssessmentItem _notAvailable(
    DailyAssessmentModule module,
    DailyAssessmentMetric metric,
  ) => DailyAssessmentItem(
    module: module,
    metric: metric,
    rawValue: null,
    specificAssessment: 'NOT AVAILABLE',
    level: null,
  );

  DailyAssessmentLevel? _worse(
    DailyAssessmentLevel? first,
    DailyAssessmentLevel? second,
  ) {
    if (first == null) return second;
    if (second == null) return first;
    return _severity(first) >= _severity(second) ? first : second;
  }

  static int _severity(DailyAssessmentLevel level) => level.index;

  static bool _atLeast(
    DailyAssessmentLevel? actual,
    DailyAssessmentLevel threshold,
  ) => actual != null && _severity(actual) >= _severity(threshold);

  static String? _constraintLabel(DailyAssessmentItem item) =>
      switch (item.metric) {
        DailyAssessmentMetric.weightTrend =>
          item.specificAssessment.endsWith('FROM PREVIOUS')
              ? 'WEIGHT CHANGE'
              : 'WEIGHT TREND',
        DailyAssessmentMetric.sleepTime => 'SEVERE SLEEP DEFICIT',
        DailyAssessmentMetric.sleepScore => 'LOW SLEEP SCORE',
        DailyAssessmentMetric.plantarFasciitis => 'PLANTAR FASCIITIS',
        DailyAssessmentMetric.work => 'HIGH WORK LOAD',
        DailyAssessmentMetric.calorieBalance =>
          item.rawValue is num && (item.rawValue as num) > 200
              ? 'CALORIE SURPLUS'
              : 'CALORIE DEFICIT',
        DailyAssessmentMetric.protein => 'LOW PROTEIN',
        DailyAssessmentMetric.hydration => 'LOW HYDRATION',
        DailyAssessmentMetric.steps => 'RECENT STEP LOAD',
        DailyAssessmentMetric.trainingReadiness => 'RECENT TRAINING LOAD',
      };

  static List<String> _unique(Iterable<String> values) =>
      List.unmodifiable(values.toSet());
}

class _Constraint {
  const _Constraint(this.label, this.level);

  final String label;
  final DailyAssessmentLevel level;
}
