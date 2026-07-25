import '../../../core/models/activity_data.dart';
import '../../../core/models/bowel_movement_record.dart';
import '../../../core/models/morning_data.dart';

class BowelMovementResolver {
  const BowelMovementResolver();

  BowelMovementRecord resolve({
    ActivityData? activity,
    MorningData? legacyMorning,
    String? legacyMorningBowel,
  }) {
    final activityBowel = activity?.bowelMovement;
    if (activityBowel != null && activityBowel.isConfirmed) {
      return activityBowel;
    }

    final legacy = BowelMovementRecord.fromLegacy(
      amount: legacyMorning?.bowelAmount,
      shape: legacyMorning?.bowelShape,
    );
    if (legacy.isConfirmed) return legacy;

    return BowelMovementRecord.fromLegacyText(legacyMorningBowel);
  }
}
