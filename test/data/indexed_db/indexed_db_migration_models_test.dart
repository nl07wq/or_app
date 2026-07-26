import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_quarantined_record.dart';

void main() {
  test('migration metadata round-trips and freezes collection fields', () {
    final sourceCounts = {'status': 2};
    final expectedIds = {
      'status': ['status:2026-07-26', 'legacy-status:2026-07-26:0001'],
    };
    final metadata = IndexedDbMigrationMetadata(
      id: 'shared_preferences_to_v2',
      status: IndexedDbMigrationStatus.prepared,
      source: 'shared_preferences',
      targetDatabaseVersion: 2,
      attempt: 1,
      startedAt: DateTime.parse('2026-07-26T08:00:00+09:00'),
      updatedAt: DateTime.parse('2026-07-26T08:01:00+09:00'),
      ownerId: 'migration-owner',
      leaseExpiresAt: DateTime.parse('2026-07-26T08:05:00+09:00'),
      sourceCounts: sourceCounts,
      validCounts: const {'status': 2},
      quarantinedCounts: const {'status': 0},
      expectedRecordIds: expectedIds,
      sourceDigest: 'digest',
      targetDigest: 'target-digest',
    );

    sourceCounts['status'] = 99;
    expectedIds['status']!.clear();

    expect(metadata.sourceCounts['status'], 2);
    expect(metadata.expectedRecordIds['status'], hasLength(2));
    expect(() => metadata.sourceCounts['food'] = 1, throwsUnsupportedError);
    expect(
      () => metadata.expectedRecordIds['status']!.add('another'),
      throwsUnsupportedError,
    );

    final restored = IndexedDbMigrationMetadata.fromRecord(metadata.toRecord());
    expect(restored.status, IndexedDbMigrationStatus.prepared);
    expect(restored.targetDatabaseVersion, 2);
    expect(restored.startedAt, DateTime.parse('2026-07-25T23:00:00Z'));
    expect(restored.expectedRecordIds, metadata.expectedRecordIds);
    expect(restored.sourceDigest, 'digest');
    expect(restored.targetDigest, 'target-digest');
  });

  test('migration metadata rejects invalid state', () {
    expect(
      () => IndexedDbMigrationMetadata.fromRecord({
        'id': 'migration',
        'status': 'not-a-state',
        'source': 'shared_preferences',
        'targetDatabaseVersion': 2,
        'attempt': 1,
        'startedAt': '2026-07-26T00:00:00Z',
        'updatedAt': '2026-07-26T00:00:00Z',
      }),
      throwsFormatException,
    );
  });

  test('quarantined record preserves and freezes its raw payload', () {
    final rawPayload = {
      'date': 'invalid',
      'values': [1, 2],
    };
    final quarantined = IndexedDbQuarantinedRecord(
      id: 'quarantine:status:0',
      migrationId: 'shared_preferences_to_v2',
      sourceSystem: 'shared_preferences',
      sourceKey: 'morning_records',
      sourceSection: 'morning_records',
      sourceIndex: 0,
      rawPayload: rawPayload,
      errorCode: 'invalidDate',
      errorMessage: 'date is invalid',
      quarantinedAt: DateTime.parse('2026-07-26T00:00:00Z'),
    );

    (rawPayload['values']! as List<int>).clear();
    final frozenPayload = quarantined.rawPayload! as Map<String, Object?>;
    expect(frozenPayload['values'], [1, 2]);
    expect(
      () => (frozenPayload['values']! as List<Object?>).add(3),
      throwsUnsupportedError,
    );

    final record = quarantined.toRecord();
    (record['rawPayload']! as Map<String, Object?>)['date'] = 'changed';
    expect(
      (quarantined.rawPayload! as Map<String, Object?>)['date'],
      'invalid',
    );

    final restored = IndexedDbQuarantinedRecord.fromRecord(
      quarantined.toRecord(),
    );
    expect(restored.sourceSection, 'morning_records');
    expect(restored.sourceSystem, 'shared_preferences');
    expect(restored.sourceKey, 'morning_records');
    expect(restored.sourceIndex, 0);
    expect(restored.errorCode, 'invalidDate');
    expect(restored.quarantinedAt, DateTime.parse('2026-07-26T00:00:00Z'));
  });
}
