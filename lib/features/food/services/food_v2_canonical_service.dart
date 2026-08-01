import '../../import_export/services/backup_canonical_codec.dart';

abstract final class FoodV2CanonicalService {
  static Map<String, Object?> value(Map<String, Object?> recordJson) => {
    for (final entry in recordJson.entries)
      if (entry.key != 'createdAt' && entry.key != 'updatedAt')
        entry.key: entry.value,
  };

  static String encode(Map<String, Object?> recordJson) =>
      BackupCanonicalCodec.encode(value(recordJson));

  static String digest(Map<String, Object?> recordJson) =>
      BackupCanonicalCodec.digest(value(recordJson));
}
