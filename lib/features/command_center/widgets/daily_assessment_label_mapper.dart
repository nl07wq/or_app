import '../models/daily_assessment.dart';

String dailyAssessmentSpecificLabel(DailyAssessmentItem item) {
  final labels = switch (item.metric) {
    DailyAssessmentMetric.weightTrend => const {
      'ON TRACK': '減量ペースは目標範囲で推移しています。',
      'SLOW PROGRESS': '減量は緩やかに進んでいます。',
      'PLATEAU WATCH': '体重は停滞傾向にあります。',
      'UPWARD TREND': '体重は増加傾向にあります。',
      'RAPID LOSS': '減量ペースがやや速くなっています。',
    },
    DailyAssessmentMetric.sleepTime => const {
      'SUFFICIENT': '十分な睡眠時間を確保できています。',
      'ADEQUATE': '睡眠時間は概ね確保できています。',
      'SHORT': '睡眠時間がやや不足しています。',
      'LOW': '睡眠時間が不足しています。',
      'SEVERELY SHORT': '睡眠時間が大幅に不足しています。',
    },
    DailyAssessmentMetric.sleepScore => const {
      'GOOD': '睡眠の質は良好です。',
      'NORMAL': '睡眠の質は標準的です。',
      'FAIR': '睡眠の質はやや低めです。',
      'LOW': '睡眠の質が低下しています。',
      'VERY LOW': '睡眠の質が大きく低下しています。',
    },
    DailyAssessmentMetric.plantarFasciitis => const {
      'LOW': '足底症状は軽い状態です。',
      'CONTROLLED': '足底症状は安定しています。',
      'MODERATE': '足底症状は中程度です。',
      'HIGH': '足底症状が強く、活動負荷の調整が必要です。',
      'SEVERE CONSTRAINT': '足底症状が非常に強く、活動負荷を制限する必要があります。',
    },
    DailyAssessmentMetric.work => const {
      'REST DAY': '勤務による追加負荷はありません。',
      'STANDARD LOAD': '通常の勤務負荷が見込まれます。',
      'HIGH LOAD': '高い勤務負荷が見込まれます。',
      'EXTENDED LOAD': '長時間勤務による負荷が見込まれます。',
    },
    DailyAssessmentMetric.calorieBalance => const {
      'TARGET DEFICIT': '前日のカロリー収支は目標の赤字範囲です。',
      'NEAR BALANCE': '前日のカロリー収支はほぼ均衡しています。',
      'LARGE DEFICIT': '前日のカロリー赤字がやや大きくなっています。',
      'VERY LARGE DEFICIT': '前日のカロリー赤字が非常に大きくなっています。',
      'EXTREME DEFICIT': '前日のカロリー赤字が過大です。',
      'SURPLUS WATCH': '前日のカロリー収支は黒字になっています。',
      'HIGH SURPLUS': '前日のカロリー黒字が大きくなっています。',
    },
    DailyAssessmentMetric.protein => const {
      'TARGET MET': 'たんぱく質は目標量を確保できています。',
      'ADEQUATE': 'たんぱく質は概ね確保できています。',
      'BELOW TARGET': 'たんぱく質が目標量に届いていません。',
      'LOW': 'たんぱく質が不足しています。',
      'VERY LOW': 'たんぱく質が大幅に不足しています。',
    },
    DailyAssessmentMetric.hydration => const {
      'TARGET MET': '水分摂取量は目標を達成しています。',
      'ADEQUATE': '水分摂取量は概ね確保できています。',
      'BELOW TARGET': '水分摂取量が目標に届いていません。',
      'LOW': '水分摂取量が不足しています。',
      'VERY LOW': '水分摂取量が大幅に不足しています。',
    },
    DailyAssessmentMetric.steps => const {
      'LOW LOAD': '前日の歩行負荷は低い状態です。',
      'MODERATE LOAD': '前日の歩行負荷は中程度です。',
      'HIGH LOAD': '前日の歩行負荷は高い状態です。',
      'VERY HIGH LOAD': '前日の歩行負荷が非常に高い状態です。',
    },
    DailyAssessmentMetric.trainingReadiness => const {
      'NOT AVAILABLE': '現在の記録ではトレーニング間隔を評価できません。',
    },
  };
  return labels[item.specificAssessment] ?? item.specificAssessment;
}

String dailyAssessmentConstraintLabel(String canonical) =>
    const <String, String>{
      'WEIGHT TREND': '減量ペースが速いため、体重推移を確認する必要があります。',
      'SEVERE SLEEP DEFICIT': '睡眠時間が大幅に不足しています。',
      'LOW SLEEP SCORE': '睡眠の質が低下しています。',
      'PLANTAR FASCIITIS': '足底症状が強く、活動負荷を抑える必要があります。',
      'HIGH WORK LOAD': '勤務負荷が高い状態です。',
      'CALORIE SURPLUS': '前日のカロリー収支が黒字です。',
      'CALORIE DEFICIT': '前日のカロリー赤字が大きい状態です。',
      'LOW PROTEIN': 'たんぱく質が不足しています。',
      'LOW HYDRATION': '水分摂取量が不足しています。',
      'RECENT STEP LOAD': '前日の歩行負荷が高い状態です。',
      'RECENT TRAINING LOAD': '直近のトレーニング負荷が高い状態です。',
      'SLEEP × HIGH WORK LOAD': '睡眠不足と高い勤務負荷が重なっています。',
      'SLEEP × EXTENDED WORK LOAD': '睡眠不足と長時間勤務が重なっています。',
      'FOOT LOAD CONSTRAINT': '足底症状と歩行負荷が重なっています。',
      'RECOVERY PRIORITY': '回復面の制約があります。',
      'NUTRITION PRIORITY': '栄養状態に制約があります。',
      'HYDRATION PRIORITY': '水分状態に制約があります。',
    }[canonical] ??
    canonical;

String dailyAssessmentResourceLabel(String canonical) =>
    const <String, String>{
      'RECOVERY CAPACITY': '十分な回復状態を確保できています。',
      'REST DAY': '公休日のため、勤務負荷のない時間を利用できます。',
      'TRAINING READINESS': 'トレーニングを行える身体的余力があります。',
    }[canonical] ??
    canonical;
