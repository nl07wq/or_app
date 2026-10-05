import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../import_export/models/backup_package.dart';

class ReleaseMetadata {
  const ReleaseMetadata({
    required this.lastUpdated,
    required this.releaseTitle,
    required this.releaseCommit,
  });

  static const unavailable = ReleaseMetadata(
    lastUpdated: 'NOT AVAILABLE',
    releaseTitle: 'NOT AVAILABLE',
    releaseCommit: 'NOT AVAILABLE',
  );

  final String lastUpdated;
  final String releaseTitle;
  final String releaseCommit;
}

abstract final class AppMetadata {
  static const appVersion = '1.0.0';
  static const buildNumber = '1';
  static const operationRebootVersion = '5.2';
  static const copyright = '未設定';
  static const license =
      'SE(Water_Drop02-1(Low-Reverb).mp3,Cyber03-1.mp3) by OtoLogic(https://otologic.jp)\n'
      'SE(キャンセル1.mp3) by 効果音ラボ(https://soundeffect-lab.info/)\n'
      'SE(ボタン音09.mp3) by On-Jin ～音人～(https://on-jin.com/)';
  static const releaseMetadata = ReleaseMetadata(
    lastUpdated: String.fromEnvironment(
      'OR_APP_LAST_UPDATED',
      defaultValue: 'NOT AVAILABLE',
    ),
    releaseTitle: String.fromEnvironment(
      'OR_APP_RELEASE_TITLE',
      defaultValue: 'NOT AVAILABLE',
    ),
    releaseCommit: String.fromEnvironment(
      'OR_APP_RELEASE_COMMIT',
      defaultValue: 'NOT AVAILABLE',
    ),
  );

  static const databaseVersion = '${IndexedDbSchema.databaseVersion}';
  static const backupSchemaVersion = '${BackupPackage.currentSchemaVersion}.0';
}
