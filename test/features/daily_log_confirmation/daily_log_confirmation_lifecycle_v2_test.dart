import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/features/daily_log_confirmation/models/daily_log_confirmation_lifecycle.dart';
import 'package:or_app/features/daily_log_confirmation/models/daily_log_confirmation_lifecycle_projection.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';

import 'daily_log_confirmation_test_fixture.dart';

void main() {
  const id = 'confirmation:2026-07-26';
  const localDate = '2026-07-26';
  final createdAt = DateTime.utc(2026, 7, 26, 22);

  test('projects v1 as finalized revision 1 without rewriting it', () {
    final v1 = PersistedDailyLogConfirmationRecord(
      id: id,
      localDate: localDate,
      createdAt: createdAt,
      updatedAt: createdAt,
      data: completeConfirmation(),
    );
    final before = v1.toRecord();
    final parsed = PersistedDailyLogConfirmationRecord.fromRecord(before);
    final projection = DailyLogConfirmationLifecycleProjection.fromRecord(
      parsed,
    );

    expect(parsed.recordVersion, 1);
    expect(
      parsed.projectedLifecycleStatus,
      DailyLogConfirmationLifecycleStatus.finalized,
    );
    expect(parsed.projectedRevision, 1);
    expect(projection.isFinalized, isTrue);
    expect(projection.isLocked, isTrue);
    expect(projection.isEditable, isFalse);
    expect(parsed.toRecord(), before);
  });

  test('round-trips strict finalized v2 with unknown source versions', () {
    final record = PersistedDailyLogConfirmationRecord.initialFinalizedV2(
      id: id,
      localDate: localDate,
      data: completeConfirmation(),
      timestamp: createdAt,
    );
    final parsed = PersistedDailyLogConfirmationRecord.fromRecord(
      record.toRecord(),
    );
    final projection = DailyLogConfirmationLifecycleProjection.fromRecord(
      parsed,
    );

    expect(parsed.recordVersion, 2);
    expect(
      parsed.lifecycleStatus,
      DailyLogConfirmationLifecycleStatus.finalized,
    );
    expect(parsed.revision, 1);
    expect(parsed.snapshotDigest, parsed.originalSnapshotDigest);
    expect(
      parsed.snapshotDigest,
      PersistedDailyLogConfirmationRecord.digestSnapshot(parsed.data),
    );
    expect(parsed.reopenedAt, isNull);
    expect(parsed.reopenReason, isNull);
    expect(parsed.previousRevisions, isEmpty);
    expect(parsed.sourceRecordVersions!.toJson(), {
      'status': null,
      'food': null,
      'activity': null,
      'training': null,
    });
    expect(projection.isLocked, isTrue);
    expect(projection.isEditable, isFalse);
  });

  test('round-trips reopened v2 without changing Snapshot or revision', () {
    final snapshot = completeConfirmation();
    final digest = PersistedDailyLogConfirmationRecord.digestSnapshot(snapshot);
    final record = PersistedDailyLogConfirmationRecord.v2(
      id: id,
      localDate: localDate,
      lifecycleStatus: DailyLogConfirmationLifecycleStatus.reopened,
      revision: 1,
      data: snapshot,
      snapshotDigest: digest,
      originalSnapshotDigest: digest,
      finalizedAt: snapshot.confirmedAt,
      reopenedAt: DateTime.utc(2026, 7, 27),
      lastRefinalizedAt: null,
      reopenReason: DailyLogConfirmationReopenReason.userCorrection,
      sourceRecordVersions:
          const DailyLogConfirmationSourceRecordVersions.unknown(),
      previousRevisions: const [],
      createdAt: createdAt,
      updatedAt: DateTime.utc(2026, 7, 27),
    );
    final parsed = PersistedDailyLogConfirmationRecord.fromRecord(
      record.toRecord(),
    );
    final projection = DailyLogConfirmationLifecycleProjection.fromRecord(
      parsed,
    );

    expect(
      parsed.lifecycleStatus,
      DailyLogConfirmationLifecycleStatus.reopened,
    );
    expect(parsed.revision, 1);
    expect(parsed.snapshotDigest, digest);
    expect(parsed.data.toJson(), snapshot.toJson());
    expect(
      parsed.reopenReason,
      DailyLogConfirmationReopenReason.userCorrection,
    );
    expect(projection.isReopened, isTrue);
    expect(projection.isFinalized, isFalse);
    expect(projection.isLocked, isFalse);
    expect(projection.isEditable, isTrue);
  });

  test('preserves ordered previous revisions and their Snapshot digests', () {
    final first = completeConfirmation(
      confirmedAt: DateTime.utc(2026, 7, 26, 20),
      trainingName: 'Revision 1',
    );
    final second = completeConfirmation(
      confirmedAt: DateTime.utc(2026, 7, 27, 20),
      trainingName: 'Revision 2',
    );
    final current = completeConfirmation(
      confirmedAt: DateTime.utc(2026, 7, 28, 20),
      trainingName: 'Revision 3',
    );
    final record = PersistedDailyLogConfirmationRecord.v2(
      id: id,
      localDate: localDate,
      lifecycleStatus: DailyLogConfirmationLifecycleStatus.finalized,
      revision: 3,
      data: current,
      snapshotDigest: PersistedDailyLogConfirmationRecord.digestSnapshot(
        current,
      ),
      originalSnapshotDigest:
          PersistedDailyLogConfirmationRecord.digestSnapshot(first),
      finalizedAt: first.confirmedAt,
      reopenedAt: null,
      lastRefinalizedAt: current.confirmedAt,
      reopenReason: null,
      sourceRecordVersions:
          const DailyLogConfirmationSourceRecordVersions.unknown(),
      previousRevisions: [
        _revision(1, first, DateTime.utc(2026, 7, 27)),
        _revision(2, second, DateTime.utc(2026, 7, 28)),
      ],
      createdAt: first.confirmedAt,
      updatedAt: current.confirmedAt,
    );

    final parsed = PersistedDailyLogConfirmationRecord.fromRecord(
      record.toRecord(),
    );

    expect(parsed.previousRevisions.map((item) => item.revision), [1, 2]);
    for (final previous in parsed.previousRevisions) {
      expect(
        previous.snapshotDigest,
        PersistedDailyLogConfirmationRecord.digestSnapshot(previous.snapshot),
      );
    }
  });

  test('rejects invalid lifecycle, revision, digest, and null contracts', () {
    final valid = PersistedDailyLogConfirmationRecord.initialFinalizedV2(
      id: id,
      localDate: localDate,
      data: completeConfirmation(),
      timestamp: createdAt,
    ).toRecord();

    for (final mutate in <void Function(Map<String, Object?>)>[
      (record) => record['lifecycleStatus'] = 'unknown',
      (record) => record['lifecycleStatus'] = null,
      (record) => record['revision'] = 0,
      (record) => record['snapshotDigest'] = 'invalid',
      (record) => record['reopenedAt'] = '2026-07-27T00:00:00.000Z',
      (record) => record['reopenReason'] = 'userCorrection',
    ]) {
      final invalid = _deepCopy(valid);
      mutate(invalid);
      expect(
        () => PersistedDailyLogConfirmationRecord.fromRecord(invalid),
        throwsFormatException,
      );
    }
  });

  test('rejects duplicate, current, and out-of-order history revisions', () {
    final first = completeConfirmation(
      confirmedAt: DateTime.utc(2026, 7, 26, 20),
      trainingName: 'Revision 1',
    );
    final second = completeConfirmation(
      confirmedAt: DateTime.utc(2026, 7, 27, 20),
      trainingName: 'Revision 2',
    );
    final current = completeConfirmation(
      confirmedAt: DateTime.utc(2026, 7, 28, 20),
      trainingName: 'Revision 3',
    );
    final valid = PersistedDailyLogConfirmationRecord.v2(
      id: id,
      localDate: localDate,
      lifecycleStatus: DailyLogConfirmationLifecycleStatus.finalized,
      revision: 3,
      data: current,
      snapshotDigest: PersistedDailyLogConfirmationRecord.digestSnapshot(
        current,
      ),
      originalSnapshotDigest:
          PersistedDailyLogConfirmationRecord.digestSnapshot(first),
      finalizedAt: first.confirmedAt,
      reopenedAt: null,
      lastRefinalizedAt: current.confirmedAt,
      reopenReason: null,
      sourceRecordVersions:
          const DailyLogConfirmationSourceRecordVersions.unknown(),
      previousRevisions: [
        _revision(1, first, DateTime.utc(2026, 7, 27)),
        _revision(2, second, DateTime.utc(2026, 7, 28)),
      ],
      createdAt: first.confirmedAt,
      updatedAt: current.confirmedAt,
    ).toRecord();

    final duplicate = _deepCopy(valid);
    (duplicate['previousRevisions']! as List)[1]['revision'] = 1;
    final currentMixed = _deepCopy(valid);
    (currentMixed['previousRevisions']! as List)[1]['revision'] = 3;
    final outOfOrder = _deepCopy(valid);
    (outOfOrder['previousRevisions']! as List).setAll(0, [
      (outOfOrder['previousRevisions']! as List)[1],
      (outOfOrder['previousRevisions']! as List)[0],
    ]);

    for (final invalid in [duplicate, currentMixed, outOfOrder]) {
      expect(
        () => PersistedDailyLogConfirmationRecord.fromRecord(invalid),
        throwsFormatException,
      );
    }
  });

  test('source record versions accept positive integers or null only', () {
    expect(
      DailyLogConfirmationSourceRecordVersions.fromJson(const {
        'status': 1,
        'food': null,
        'activity': 2,
        'training': null,
      }).toJson(),
      {'status': 1, 'food': null, 'activity': 2, 'training': null},
    );
    for (final invalid in [
      {'status': 0, 'food': null, 'activity': null, 'training': null},
      {'status': null, 'food': null, 'activity': null},
      {
        'status': null,
        'food': null,
        'activity': null,
        'training': null,
        'unknown': null,
      },
    ]) {
      expect(
        () => DailyLogConfirmationSourceRecordVersions.fromJson(invalid),
        throwsFormatException,
      );
    }
  });
}

DailyLogConfirmationRevision _revision(
  int revision,
  DailyLogConfirmation snapshot,
  DateTime reopenedAt,
) => DailyLogConfirmationRevision(
  revision: revision,
  snapshot: snapshot,
  snapshotDigest: PersistedDailyLogConfirmationRecord.digestSnapshot(snapshot),
  finalizedAt: snapshot.confirmedAt,
  reopenedAt: reopenedAt,
  sourceRecordVersions:
      const DailyLogConfirmationSourceRecordVersions.unknown(),
);

Map<String, Object?> _deepCopy(Map source) => {
  for (final entry in source.entries)
    entry.key.toString(): _deepCopyValue(entry.value),
};

Object? _deepCopyValue(Object? value) {
  if (value is Map) return _deepCopy(value);
  if (value is Iterable)
    return [for (final item in value) _deepCopyValue(item)];
  return value;
}
