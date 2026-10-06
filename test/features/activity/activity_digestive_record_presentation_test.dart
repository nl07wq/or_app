import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/models/digestive_event.dart';
import 'package:or_app/features/activity/services/activity_digestive_record_presentation.dart';

void main() {
  group('ActivityDigestiveRecordPresentation', () {
    test(
      'keeps a legacy unconfirmed record as not entered without inference',
      () {
        expect(
          ActivityDigestiveRecordPresentation.format(_activity()),
          'BOWEL: Not entered',
        );
      },
    );

    test('keeps an absent current contract as legacy BOWEL data', () {
      final record = _activity(
        bowel: BowelMovementRecord.recorded(amount: 2, shape: 3),
      );

      expect(
        ActivityDigestiveRecordPresentation.format(record),
        'BOWEL: Amount 2, shape 3',
      );
    });

    test('shows current empty Digestive data as not entered', () {
      expect(
        ActivityDigestiveRecordPresentation.format(_activity(events: const [])),
        'DIGESTIVE: NOT ENTERED',
      );
    });

    test('keeps explicit Amount none distinct from not entered', () {
      expect(
        ActivityDigestiveRecordPresentation.format(
          _activity(events: [_event(amount: 0, shape: null, relief: null)]),
        ),
        'DIGESTIVE: なし',
      );
    });

    test('shows one complete current Digestive entry', () {
      expect(
        ActivityDigestiveRecordPresentation.format(
          _activity(events: [_event(amount: 2, shape: 2, relief: 1)]),
        ),
        'DIGESTIVE: 普通 · 普通便 · 普通',
      );
    });

    test(
      'summarizes multiple current Digestive entries without merging them',
      () {
        expect(
          ActivityDigestiveRecordPresentation.format(
            _activity(
              events: [
                _event(sequence: 1),
                _event(id: 'digestive:2026-10-01:2', sequence: 2),
              ],
            ),
          ),
          'DIGESTIVE: 2 ENTRIES',
        );
      },
    );
  });
}

ActivityData _activity({
  BowelMovementRecord bowel = const BowelMovementRecord.unconfirmed(),
  Iterable<DigestiveEvent>? events,
}) {
  return ActivityData(
    date: DateTime(2026, 10, 1),
    measuredSteps: 1000,
    bowelMovement: bowel,
    digestiveEvents: events,
  );
}

DigestiveEvent _event({
  String id = 'digestive:2026-10-01:1',
  int sequence = 1,
  int amount = 2,
  int? shape = 2,
  int? relief = 1,
}) {
  return DigestiveEvent(
    id: id,
    sequence: sequence,
    amount: amount,
    shape: shape,
    relief: relief,
    recordedAt: DateTime.utc(2026, 10, 1, 8),
  );
}
