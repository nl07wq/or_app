import '../models/daily_assessment.dart';

String dailyAssessmentSpecificLabel(DailyAssessmentItem item) {
  final labels = switch (item.metric) {
    DailyAssessmentMetric.weightTrend => const {
      'ON TRACK': '順調な減量ペース',
      'SLOW PROGRESS': '緩やかな減量',
      'PLATEAU WATCH': '停滞傾向',
      'UPWARD TREND': '増加傾向',
      'RAPID LOSS': '減量ペース速め',
    },
    DailyAssessmentMetric.sleepTime => const {
      'SUFFICIENT': '十分',
      'ADEQUATE': '概ね十分',
      'SHORT': 'やや不足',
      'LOW': '不足',
      'SEVERELY SHORT': '大幅に不足',
    },
    DailyAssessmentMetric.sleepScore => const {
      'GOOD': '良好',
      'NORMAL': '標準',
      'FAIR': 'やや低め',
      'LOW': '低い',
      'VERY LOW': '非常に低い',
    },
    DailyAssessmentMetric.plantarFasciitis => const {
      'LOW': '症状軽度',
      'CONTROLLED': '安定',
      'MODERATE': '中程度',
      'HIGH': '強め',
      'SEVERE CONSTRAINT': '強い制約',
    },
    DailyAssessmentMetric.work => const {
      'REST DAY': '公休日',
      'STANDARD LOAD': '通常負荷',
      'HIGH LOAD': '高負荷',
      'EXTENDED LOAD': '長時間勤務',
    },
    DailyAssessmentMetric.calorieBalance => const {
      'TARGET DEFICIT': '目標範囲の赤字',
      'NEAR BALANCE': 'ほぼ収支均衡',
      'LARGE DEFICIT': '赤字大きめ',
      'VERY LARGE DEFICIT': '赤字が非常に大きい',
      'EXTREME DEFICIT': '赤字過大',
      'SURPLUS WATCH': '黒字傾向',
      'HIGH SURPLUS': '黒字大きめ',
    },
    DailyAssessmentMetric.protein => const {
      'TARGET MET': '目標達成',
      'ADEQUATE': '概ね十分',
      'BELOW TARGET': '目標未達',
      'LOW': '不足',
      'VERY LOW': '大幅に不足',
    },
    DailyAssessmentMetric.hydration => const {
      'TARGET MET': '目標達成',
      'ADEQUATE': '概ね十分',
      'BELOW TARGET': '目標未達',
      'LOW': '不足',
      'VERY LOW': '大幅に不足',
    },
    DailyAssessmentMetric.steps => const {
      'LOW LOAD': '低負荷',
      'MODERATE LOAD': '中程度の負荷',
      'HIGH LOAD': '高負荷',
      'VERY HIGH LOAD': '非常に高負荷',
    },
    DailyAssessmentMetric.trainingReadiness => const {'NOT AVAILABLE': '評価不可'},
  };
  return labels[item.specificAssessment] ?? item.specificAssessment;
}

String dailyAssessmentConstraintLabel(String canonical) =>
    const <String, String>{
      'WEIGHT TREND': '体重推移',
      'SEVERE SLEEP DEFICIT': '深刻な睡眠不足',
      'LOW SLEEP SCORE': '睡眠スコア低下',
      'PLANTAR FASCIITIS': '足底筋膜炎',
      'HIGH WORK LOAD': '高い勤務負荷',
      'CALORIE SURPLUS': 'カロリー黒字',
      'CALORIE DEFICIT': 'カロリー赤字',
      'LOW PROTEIN': 'たんぱく質不足',
      'LOW HYDRATION': '水分不足',
      'RECENT STEP LOAD': '直近歩数負荷',
      'RECENT TRAINING LOAD': '直近トレーニング負荷',
      'SLEEP × HIGH WORK LOAD': '睡眠不足 × 高勤務負荷',
      'SLEEP × EXTENDED WORK LOAD': '睡眠不足 × 長時間勤務',
      'FOOT LOAD CONSTRAINT': '足部負荷制約',
      'RECOVERY PRIORITY': '回復優先',
      'NUTRITION PRIORITY': '栄養優先',
      'HYDRATION PRIORITY': '水分補給優先',
    }[canonical] ??
    canonical;

String dailyAssessmentResourceLabel(String canonical) =>
    const <String, String>{
      'RECOVERY CAPACITY': '回復余力',
      'REST DAY': '公休日',
      'TRAINING READINESS': 'トレーニング余力',
    }[canonical] ??
    canonical;
