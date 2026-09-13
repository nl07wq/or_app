import 'training_frequency_recommendation_service.dart';

/// Human-readable Training Analysis text. This keeps presentation precision
/// and Rule-result interpretation out of Formal Training data and Rule logic.
abstract final class TrainingAnalysisPresentation {
  static String rpe(double? value) => value?.toStringAsFixed(1) ?? '—';

  static String recommendationBasis(
    TrainingFrequencyRecommendation recommendation,
  ) => switch (recommendation.status) {
    TrainingFrequencyRecommendationStatus.personalized => '実績から推定',
    TrainingFrequencyRecommendationStatus.unavailable => '判定不可',
    TrainingFrequencyRecommendationStatus.baselineOnly ||
    TrainingFrequencyRecommendationStatus.conflicting => 'データ不足',
  };

  static String recommendationRange(
    TrainingFrequencyRecommendation recommendation,
  ) {
    if (recommendation.status ==
        TrainingFrequencyRecommendationStatus.unavailable) {
      return '算出不可';
    }
    final minimum = recommendation.recommendedMinHours;
    if (minimum == null) return '算出不可';
    final maximum = recommendation.recommendedMaxHours;
    if (maximum == null || maximum == minimum) {
      return '暫定 ${hoursAtLeast(minimum)}';
    }
    if (_isNearWholeDay(minimum) && _isNearWholeDay(maximum)) {
      return '${(minimum / 24).round()}〜${(maximum / 24).round()}日';
    }
    return '${hours(minimum)}〜${hours(maximum)}';
  }

  static String frequencyNote({
    required String exerciseName,
    required TrainingFrequencyRecommendation recommendation,
  }) {
    final recovery = hoursAtLeast(recommendation.recoveryReferenceHours);
    switch (recommendation.status) {
      case TrainingFrequencyRecommendationStatus.unavailable:
        return '$exerciseNameは回復基準を確認できないため、推奨実施間隔を算出できません。';
      case TrainingFrequencyRecommendationStatus.personalized:
        return '$exerciseNameは回復基準$recovery。観測${recommendation.validObservationCount}件のうち'
            '${recommendation.supportedObservationCount}件が条件を満たしているため、'
            'これまでの実績から${recommendationRange(recommendation)}を推定しています。'
            '履歴の蓄積に応じて推奨範囲は更新されます。';
      case TrainingFrequencyRecommendationStatus.conflicting:
        return '$exerciseNameは回復基準$recovery。観測${recommendation.validObservationCount}件の'
            '実績に一貫性がないため、個人の実施間隔は推定せず、$recoveryを目安としています。';
      case TrainingFrequencyRecommendationStatus.baselineOnly:
        return '$exerciseNameは回復基準$recovery。観測${recommendation.validObservationCount}件では'
            '個人の実施間隔を十分に推定できないため、$recoveryを暫定的な目安としています。';
    }
  }

  /// Saved/generated prose is free text, but machine precision is never useful
  /// to a reader. Dedicated metric renderers still own their normal precision.
  static String cleanNarrativeNumbers(String value) => value.replaceAllMapped(
    RegExp(r'(?<![\d.])-?\d+\.\d{7,}'),
    (match) => double.parse(match.group(0)!).toStringAsFixed(1),
  );

  static String hoursAtLeast(num? value) =>
      value == null ? '算出不可' : '${hours(value)}以上';

  static String hours(num value) => '${value.round()}時間';

  static bool _isNearWholeDay(num value) =>
      ((value / 24) - (value / 24).round()).abs() <= .125;
}
