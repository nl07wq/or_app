import 'backup_file_gateway_stub.dart'
    if (dart.library.html) 'backup_file_gateway_web.dart';

class BackupSelectedFile {
  final String name;
  final List<int> bytes;

  BackupSelectedFile({required this.name, required Iterable<int> bytes})
    : bytes = List.unmodifiable(bytes);
}

abstract interface class BackupFileGateway {
  String? get origin;

  Future<void> save({required String fileName, required String content});

  Future<BackupSelectedFile?> selectJson();

  factory BackupFileGateway.platform() => createBackupFileGateway();
}
