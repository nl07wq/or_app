import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/digestive_summary.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/models/digestive_event.dart';
import 'package:or_app/features/activity/services/activity_summary_engine.dart';

void main() {
  group('DigestiveEvent', () {
    test('accepts every boundary value and formats Japanese labels', () {
      for (final amount in [1, 2, 3]) {
        expect(_event(amount: amount).amount, amount);
      }
      for (final shape in [1, 2, 3]) {
        expect(_event(shape: shape).shape, shape);
      }
      for (final relief in [0, 2]) {
        expect(_event(relief: relief).relief, relief);
      }

      expect(DigestiveEvent.amountLabel(1), '少量');
      expect(DigestiveEvent.amountLabel(2), '普通');
      expect(DigestiveEvent.amountLabel(3), '多量');
      expect(DigestiveEvent.shapeLabel(1), '硬便');
      expect(DigestiveEvent.shapeLabel(2), '普通便');
      expect(DigestiveEvent.shapeLabel(3), '軟便');
      expect(DigestiveEvent.reliefLabel(0), '残便感あり');
      expect(DigestiveEvent.reliefLabel(1), '普通');
      expect(DigestiveEvent.reliefLabel(2), 'スッキリ');
    });

    test('rejects values outside the formal ranges', () {
      for (final amount in [0, 4]) {
        expect(() => _event(amount: amount), throwsArgumentError);
      }
      for (final shape in [0, 4]) {
        expect(() => _event(shape: shape), throwsArgumentError);
      }
      for (final relief in [-1, 3]) {
        expect(() => _event(relief: relief), throwsArgumentError);
      }
      expect(() => _event(id: ''), throwsArgumentError);
      expect(() => _event(sequence: 0), throwsArgumentError);
    });

    test('JSON round trip, equality, and copyWith preserve the event', () {
      final event = _event();
      final decoded = DigestiveEvent.fromJson(event.toJson());

      expect(decoded, event);
      expect(decoded.hashCode, event.hashCode);
      expect(decoded.copyWith(), event);
      expect(decoded.copyWith(amount: 3).amount, 3);
      expect(
        () => DigestiveEvent.fromJson({
          ...event.toJson(),
          'recordedAt': 'invalid',
        }),
        throwsFormatException,
      );
    });
  });

  group('Digestive event list', () {
    test('supports null, empty, one, and multiple immutable events', () {
      final legacy = _activity();
      final empty = _activity(events: const []);
      final one = _activity(events: [_event()]);
      final multiple = _activity(
        events: [
          _event(id: 'second', sequence: 2),
          _event(id: 'first', sequence: 1),
        ],
      );

      expect(legacy.digestiveEvents, isNull);
      expect(empty.digestiveEvents, isEmpty);
      expect(one.digestiveEvents, hasLength(1));
      expect(multiple.digestiveEvents!.map((event) => event.sequence), [1, 2]);
      expect(
        () => multiple.digestiveEvents!.add(_event(id: 'third', sequence: 3)),
        throwsUnsupportedError,
      );
      expect(multiple.digestiveEvents!.last.recordedAt, _recordedAt);
    });

    test('rejects duplicate IDs, duplicate sequence, and sequence gaps', () {
      expect(
        () => _activity(
          events: [
            _event(id: 'same', sequence: 1),
            _event(id: 'same', sequence: 2),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => _activity(
          events: [
            _event(id: 'one', sequence: 1),
            _event(id: 'two', sequence: 1),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => _activity(events: [_event(sequence: 2)]),
        throwsFormatException,
      );
    });

    test('rejects a malformed event mixed into ActivityData JSON', () {
      final json = _activity(events: [_event()]).toJson();
      (json['digestiveEvents']! as List).add({
        ..._event(id: 'bad', sequence: 2).toJson(),
        'shape': 4,
      });

      expect(() => ActivityData.fromJson(json), throwsFormatException);
    });
  });

  group('DigestiveSummary', () {
    test('uses sequence order for totals, latest values, and trends', () {
      final summary = DigestiveSummary.fromEvents([
        _event(id: 'third', sequence: 3, amount: 1, shape: 3, relief: 2),
        _event(id: 'first', sequence: 1, amount: 1, shape: 1, relief: 0),
        _event(id: 'second', sequence: 2, amount: 2, shape: 2, relief: 1),
      ]);

      expect(summary.eventCount, 3);
      expect(summary.totalAmount, 4);
      expect(summary.latestShape, 3);
      expect(summary.latestRelief, 2);
      expect(summary.shapeTrend, [1, 2, 3]);
      expect(summary.reliefTrend, [0, 1, 2]);
      expect(summary.toJson().containsKey('average'), isFalse);
      expect(() => summary.shapeTrend.add(3), throwsUnsupportedError);
      expect(
        DigestiveSummary.fromJson(summary.toJson()).toJson(),
        summary.toJson(),
      );
    });

    test('represents zero events without inferred latest values', () {
      final summary = DigestiveSummary.fromEvents(const []);

      expect(summary.eventCount, 0);
      expect(summary.totalAmount, 0);
      expect(summary.latestShape, isNull);
      expect(summary.latestRelief, isNull);
      expect(summary.shapeTrend, isEmpty);
      expect(summary.reliefTrend, isEmpty);
    });
  });

  group('ActivityData compatibility', () {
    test('round trips new events and preserves null versus empty', () {
      final event = _event();
      final newRecord = _activity(events: [event]);
      final emptyRecord = _activity(events: const []);
      final legacyRecord = _activity();

      expect(ActivityData.fromJson(newRecord.toJson()).digestiveEvents, [
        event,
      ]);
      expect(
        ActivityData.fromJson(emptyRecord.toJson()).digestiveEvents,
        isEmpty,
      );
      expect(legacyRecord.toJson().containsKey('digestiveEvents'), isFalse);
      expect(
        ActivityData.fromJson(legacyRecord.toJson()).digestiveEvents,
        isNull,
      );
      expect(newRecord.copyWith(digestiveEvents: null).digestiveEvents, isNull);
    });

    for (final shape in [1, 2, 3]) {
      test('legacy bowel shape $shape remains legacy without inference', () {
        final legacy = _activity(
          bowel: BowelMovementRecord.recorded(amount: 2, shape: shape),
        );
        final decoded = ActivityData.fromJson(legacy.toJson());
        final summary = const ActivitySummaryEngine().generate(record: decoded);

        expect(decoded.bowelMovement.amount, 2);
        expect(decoded.bowelMovement.shape, shape);
        expect(decoded.digestiveEvents, isNull);
        expect(summary.digestiveSummary, isNull);
      });
    }

    test('new events are authoritative over the legacy bowel field', () {
      final record = _activity(
        bowel: BowelMovementRecord.recorded(amount: 3, shape: 1),
        events: [_event(amount: 1, shape: 3, relief: 2)],
      );
      final summary = const ActivitySummaryEngine().generate(record: record);

      expect(summary.digestiveSummary?.totalAmount, 1);
      expect(summary.digestiveSummary?.latestShape, 3);
      expect(summary.digestiveSummary?.latestRelief, 2);
      expect(
        summary.warnings.map((warning) => warning.code),
        isNot(contains(ActivitySummaryWarningCode.bowelUnconfirmed)),
      );
    });

    test(
      'empty new event list confirms zero events without a fake timeline',
      () {
        final summary = const ActivitySummaryEngine().generate(
          record: _activity(events: const []),
        );

        expect(summary.digestiveSummary?.eventCount, 0);
        expect(summary.digestiveSummary?.shapeTrend, isEmpty);
        expect(
          summary.warnings.map((warning) => warning.code),
          isNot(contains(ActivitySummaryWarningCode.bowelUnconfirmed)),
        );
      },
    );
  });
}

final _recordedAt = DateTime.utc(2026, 7, 27, 8);

DigestiveEvent _event({
  String id = 'digestive:2026-07-27:1',
  int sequence = 1,
  int amount = 2,
  int shape = 2,
  int relief = 1,
}) {
  return DigestiveEvent(
    id: id,
    sequence: sequence,
    amount: amount,
    shape: shape,
    relief: relief,
    recordedAt: _recordedAt,
  );
}

ActivityData _activity({
  BowelMovementRecord bowel = const BowelMovementRecord.unconfirmed(),
  Iterable<DigestiveEvent>? events,
}) {
  return ActivityData(
    date: DateTime(2026, 7, 27),
    measuredSteps: 1000,
    plannedWork: 'rest',
    actualWork: 'rest',
    trainingStatus: ActivityTrainingStatus.skipped,
    bowelMovement: bowel,
    digestiveEvents: events,
    createdAt: DateTime.utc(2026, 7, 27, 7),
    updatedAt: DateTime.utc(2026, 7, 27, 9),
  );
}
