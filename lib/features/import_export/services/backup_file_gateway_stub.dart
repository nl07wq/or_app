import 'backup_file_gateway.dart';

BackupFileGateway createBackupFileGateway() => _UnsupportedBackupFileGateway();

class _UnsupportedBackupFileGateway implements BackupFileGateway {
  @override
  String? get origin => null;

  @override
  Future<void> save({required String fileName, required String content}) {
    throw UnsupportedError('Backup file export is available on Web only.');
  }

  @override
  Future<BackupSelectedFile?> selectJson() {
    throw UnsupportedError('Backup file import is available on Web only.');
  }
}
