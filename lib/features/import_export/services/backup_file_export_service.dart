import '../models/backup_package.dart';
import '../models/backup_audit_package.dart';
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

class BackupV14FileExportResult {
  const BackupV14FileExportResult({
    required this.bundle,
    required this.normalDelivery,
    required this.auditDelivery,
  });

  final BackupV14Bundle bundle;
  final BackupFileDelivery normalDelivery;
  final BackupFileDelivery auditDelivery;
}

class BackupFileExportService {
  static const fileName = 'operation_reboot_backup.json';
  static const legacyFileName = 'operation_reboot_backup_v13_full.json';
  static const normalFileName = 'operation_reboot_backup_v14_normal.json';
  static const auditFileName = 'operation_reboot_backup_v14_audit.json';

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

  Future<BackupFileExportResult> exportLegacyV13() async {
    final package = await _exportService.createLegacyV13(
      origin: _fileGateway.origin,
    );
    final delivery = await _fileGateway.shareOrSave(
      fileName: legacyFileName,
      content: BackupExportService.prettyEncode(package),
    );
    return BackupFileExportResult(
      package: package,
      fileName: legacyFileName,
      delivery: delivery,
    );
  }

  Future<BackupV14FileExportResult> exportV14Bundle() async {
    final bundle = await _exportService.createV14Bundle(
      origin: _fileGateway.origin,
    );
    final normalDelivery = await _fileGateway.shareOrSave(
      fileName: normalFileName,
      content: BackupExportService.prettyEncode(bundle.normal),
    );
    if (normalDelivery == BackupFileDelivery.cancelled) {
      return BackupV14FileExportResult(
        bundle: bundle,
        normalDelivery: normalDelivery,
        auditDelivery: BackupFileDelivery.cancelled,
      );
    }
    final auditDelivery = await _fileGateway.shareOrSave(
      fileName: auditFileName,
      content: BackupExportService.prettyEncodeAudit(bundle.audit),
    );
    return BackupV14FileExportResult(
      bundle: bundle,
      normalDelivery: normalDelivery,
      auditDelivery: auditDelivery,
    );
  }
}
