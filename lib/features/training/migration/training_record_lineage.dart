import '../models/persisted_training_record.dart';
import '../repository/training_record_id_generator.dart';

abstract final class TrainingRecordLineage {
  static const shadowMigrationId = 'training_records_v1_to_v2_shadow_v1';
  static const legacyStoreMigrationId =
      'legacy_trainings_to_training_records_v2_v1';

  static const shadowSourceSystem = 'indexeddb:training_records:v1';
  static const legacyStoreSourceSystem = 'indexeddb:trainings:v1';

  static TrainingMigrationSource shadowSource({
    required String sourceRecordId,
    required int sourceIndex,
  }) {
    PersistedTrainingRecord.validateId(sourceRecordId);
    return TrainingMigrationSource(
      migrationId: shadowMigrationId,
      sourceSystem: shadowSourceSystem,
      sourceKey: sourceRecordId,
      sourceIndex: sourceIndex,
      duplicateOrdinal: 0,
    );
  }

  static TrainingMigrationSource legacyStoreSource({
    required String sourceRecordId,
    required int sourceIndex,
  }) {
    if (sourceRecordId.isEmpty) {
      throw const FormatException('Legacy TRAINING source ID is required.');
    }
    return TrainingMigrationSource(
      migrationId: legacyStoreMigrationId,
      sourceSystem: legacyStoreSourceSystem,
      sourceKey: sourceRecordId,
      sourceIndex: sourceIndex,
      duplicateOrdinal: 0,
    );
  }

  static String shadowIdForV1(String sourceRecordId) {
    PersistedTrainingRecord.validateId(sourceRecordId);
    return _targetId(
      migrationId: shadowMigrationId,
      sourceSystem: shadowSourceSystem,
      sourceRecordId: sourceRecordId,
    );
  }

  static String targetIdForLegacyStore(String sourceRecordId) {
    if (sourceRecordId.isEmpty) {
      throw const FormatException('Legacy TRAINING source ID is required.');
    }
    return _targetId(
      migrationId: legacyStoreMigrationId,
      sourceSystem: legacyStoreSourceSystem,
      sourceRecordId: sourceRecordId,
    );
  }

  static int sourceIndexFor(String sourceRecordId) {
    if (sourceRecordId.isEmpty) {
      throw const FormatException('TRAINING lineage source ID is required.');
    }
    return int.parse(
      TrainingLegacyIdGenerator.fnv1aDigest(sourceRecordId),
      radix: 16,
    );
  }

  static String stableDigest(String value) {
    return List.generate(
      4,
      (index) => TrainingLegacyIdGenerator.fnv1aDigest('$index\u0000$value'),
    ).join();
  }

  static String? supersededV1Id(PersistedTrainingRecord target) {
    final source = target.migrationSource;
    if (source?.migrationId != shadowMigrationId ||
        source?.sourceSystem != shadowSourceSystem ||
        source?.duplicateOrdinal != 0) {
      return null;
    }
    final sourceId = source!.sourceKey;
    try {
      PersistedTrainingRecord.validateId(sourceId);
    } on FormatException {
      return null;
    }
    return target.recordVersion ==
                PersistedTrainingRecord.version2RecordVersion &&
            target.id == shadowIdForV1(sourceId)
        ? sourceId
        : null;
  }

  static bool isShadowOf(
    PersistedTrainingRecord target,
    String sourceRecordId,
  ) {
    if (target.recordVersion != PersistedTrainingRecord.version2RecordVersion) {
      return false;
    }
    final source = target.migrationSource;
    return source?.migrationId == shadowMigrationId &&
        source?.sourceSystem == shadowSourceSystem &&
        source?.sourceKey == sourceRecordId &&
        source?.duplicateOrdinal == 0 &&
        target.id == shadowIdForV1(sourceRecordId);
  }

  static bool hasValidKnownLineage(PersistedTrainingRecord target) {
    final source = target.migrationSource;
    if (source == null) return true;
    if (source.migrationId == shadowMigrationId) {
      return supersededV1Id(target) != null;
    }
    if (source.migrationId == legacyStoreMigrationId) {
      return target.recordVersion ==
              PersistedTrainingRecord.version2RecordVersion &&
          source.sourceSystem == legacyStoreSourceSystem &&
          source.sourceKey.isNotEmpty &&
          source.duplicateOrdinal == 0 &&
          target.id == targetIdForLegacyStore(source.sourceKey);
    }
    return true;
  }

  static String _targetId({
    required String migrationId,
    required String sourceSystem,
    required String sourceRecordId,
  }) {
    final seed = '$migrationId\u0000$sourceSystem\u0000$sourceRecordId';
    final hex = stableDigest(seed);
    final chars = hex.split('');
    chars[12] = '4';
    final variant = int.parse(chars[16], radix: 16);
    chars[16] = (8 | (variant & 3)).toRadixString(16);
    final value = chars.join();
    final uuid =
        '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20, 32)}';
    final id = 'training:$uuid';
    PersistedTrainingRecord.validateId(id);
    return id;
  }
}
