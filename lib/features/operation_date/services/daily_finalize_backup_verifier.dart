import '../../import_export/models/backup_package.dart';
import '../../import_export/services/backup_export_service.dart';
import '../../import_export/services/backup_package_codec.dart';
import '../../import_export/services/backup_schema_diagnostics.dart';
import '../models/daily_finalize_result.dart';

class VerifiedFinalizeBackup {
  final String packageDigest;
  final DateTime generatedAt;

  const VerifiedFinalizeBackup({
    required this.packageDigest,
    required this.generatedAt,
  });
}

class DailyFinalizeBackupVerifier {
  final BackupExportService _exportService;
  final BackupPackageCodec _codec;

  const DailyFinalizeBackupVerifier(
    this._exportService, [
    this._codec = const BackupPackageCodec(),
  ]);

  Future<VerifiedFinalizeBackup> generateAndVerify() async {
    final BackupPackage generated;
    try {
      generated = await _exportService.create();
    } catch (error) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.backupGenerationFailed,
        error,
        diagnostics: _diagnosticsFor(error, 'backup_snapshot_validation'),
      );
    }

    final BackupPackage decoded;
    try {
      decoded = _codec.decode(BackupExportService.encode(generated));
    } catch (error) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.backupValidationFailed,
        error,
        diagnostics: _diagnosticsFor(error, 'backup_package_validation'),
      );
    }
    if (decoded.digests.package != generated.digests.package) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.backupDigestMismatch,
        StateError('Backup package digest does not match after decode.'),
      );
    }
    return VerifiedFinalizeBackup(
      packageDigest: decoded.digests.package,
      generatedAt: decoded.exportedAt.toUtc(),
    );
  }

  BackupSchemaDiagnostics _diagnosticsFor(Object error, String stage) =>
      error is BackupRecordValidationException
      ? error.diagnostics
      : BackupSchemaDiagnostics.unavailable(validationStage: stage);
}
