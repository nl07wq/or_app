import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/daily_nutrition_target_assessment.dart';

void main() {
  test('single targets use a ten percent on-track band', () {
    expect(
      assessSingleNutritionTarget(2369, 2300).status,
      DailyNutritionTargetStatus.onTrack,
    );
    expect(
      assessSingleNutritionTarget(3038, 2300).status,
      DailyNutritionTargetStatus.over,
    );
    expect(
      assessSingleNutritionTarget(87.8, 130).status,
      DailyNutritionTargetStatus.low,
    );
  });

  test('explicit ranges take precedence over the ten percent band', () {
    expect(
      assessRangedNutritionTarget(96.3, 64, 77).status,
      DailyNutritionTargetStatus.over,
    );
    expect(
      assessRangedNutritionTarget(70, 64, 77).status,
      DailyNutritionTargetStatus.onTrack,
    );
    expect(
      assessRangedNutritionTarget(63.9, 64, 77).status,
      DailyNutritionTargetStatus.low,
    );
  });

  test('case A produces the approved daily assessment statuses', () {
    expect(assessSingleNutritionTarget(2369, 2300).badgeLabel, 'ON TRACK');
    expect(assessSingleNutritionTarget(87.8, 130).badgeLabel, 'LOW');
    expect(assessRangedNutritionTarget(96.3, 64, 77).badgeLabel, 'OVER');
    expect(assessSingleNutritionTarget(303.1, 288).badgeLabel, 'ON TRACK');
  });

  test('case B keeps only protein low at the ten percent lower bound', () {
    expect(assessSingleNutritionTarget(3028, 2300).badgeLabel, 'OVER');
    expect(assessSingleNutritionTarget(116.4, 130).badgeLabel, 'LOW');
    expect(assessRangedNutritionTarget(119.1, 61, 74).badgeLabel, 'OVER');
    expect(assessSingleNutritionTarget(393.3, 273).badgeLabel, 'OVER');
  });
}
