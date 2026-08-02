import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../import_export/models/backup_package.dart';

abstract final class AppMetadata {
  static const appVersion = '1.0.0';
  static const buildNumber = '1';
  static const operationRebootVersion = '5.2';
  static const copyright = '未設定';
  static const license = '未設定';

  static const databaseVersion = '${IndexedDbSchema.databaseVersion}';
  static const backupSchemaVersion = '${BackupPackage.currentSchemaVersion}.0';
}
