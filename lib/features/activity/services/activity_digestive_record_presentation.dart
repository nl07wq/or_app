import '../../../core/models/activity_data.dart';
import '../../../core/models/bowel_movement_record.dart';
import '../../../core/models/digestive_event.dart';

/// Formats the Activity Record digestive line without inferring values across
/// the legacy BOWEL and current DIGESTIVE contracts.
class ActivityDigestiveRecordPresentation {
  const ActivityDigestiveRecordPresentation._();

  static String format(ActivityData data) {
    final events = data.digestiveEvents;
    if (events == null) {
      return 'BOWEL: ${_formatLegacyBowel(data.bowelMovement)}';
    }
    if (events.isEmpty) return 'DIGESTIVE: NOT ENTERED';
    if (events.length > 1) return 'DIGESTIVE: ${events.length} ENTRIES';

    final event = events.single;
    if (event.amount == 0) {
      return 'DIGESTIVE: ${DigestiveEvent.amountLabel(event.amount)}';
    }
    return 'DIGESTIVE: '
        '${DigestiveEvent.amountLabel(event.amount)} · '
        '${DigestiveEvent.shapeLabel(event.shape!)} · '
        '${DigestiveEvent.reliefLabel(event.relief!)}';
  }

  static String _formatLegacyBowel(BowelMovementRecord record) {
    return switch (record.status) {
      BowelMovementStatus.unconfirmed => 'Not entered',
      BowelMovementStatus.none => 'None',
      BowelMovementStatus.recorded =>
        record.amount == null
            ? 'Recorded (legacy)'
            : 'Amount ${record.amount}, shape ${record.shape ?? '-'}',
    };
  }
}
