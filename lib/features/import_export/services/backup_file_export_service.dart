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
  static const fileName = 'operation_reboot_backup.json';

  final BackupExportService _exportService;
  final BackupFileGateway _fileGateway;

  BackupFileExportService({
    BackupExportService? exportService,
    BackupFileGateway? fileGateway,
  }) : _exportService = exportService ?? BackupExportService(),
       _fileGateway = fileGateway ?? BackupFileGateway.platform();

  Future<BackupFileExportResult> export() async {
    final package = await _exportService.create(origin: _fileGateway.origin);
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
}
