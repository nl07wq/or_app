import '../models/backup_package.dart';
import 'backup_export_service.dart';
import 'backup_file_gateway.dart';

class BackupFileExportResult {
  final BackupPackage package;
  final String fileName;
  final BackupFileDelivery delivery;

  const BackupFileExportResult({
    required this.package,
    required this.fileName,
    required this.delivery,
  });
}

class BackupFileExportService {
  final BackupExportService _exportService;
  final BackupFileGateway _fileGateway;

  BackupFileExportService({
    BackupExportService? exportService,
    BackupFileGateway? fileGateway,
  }) : _exportService = exportService ?? BackupExportService(),
       _fileGateway = fileGateway ?? BackupFileGateway.platform();

  Future<BackupFileExportResult> export() async {
    final package = await _exportService.create(origin: _fileGateway.origin);
    final fileName = fileNameFor(package.exportedAt.toLocal());
    final delivery = await _fileGateway.shareOrSave(
      fileName: fileName,
      content: BackupExportService.prettyEncode(package),
    );
    return BackupFileExportResult(
      package: package,
      fileName: fileName,
      delivery: delivery,
    );
  }

  static String fileNameFor(DateTime localTimestamp) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'operation_reboot_backup_'
        '${localTimestamp.year}-${two(localTimestamp.month)}-'
        '${two(localTimestamp.day)}_'
        '${two(localTimestamp.hour)}${two(localTimestamp.minute)}'
        '${two(localTimestamp.second)}.json';
  }
}
