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
        diagnostics: backupSchemaDiagnosticsForFailure(
          error,
          fallbackStage: 'backup_snapshot_validation',
        ),
      );
    }

    final BackupPackage decoded;
    try {
      decoded = _codec.decode(BackupExportService.encode(generated));
    } catch (error) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.backupValidationFailed,
        error,
        diagnostics: backupSchemaDiagnosticsForFailure(
          error,
          fallbackStage: 'backup_package_validation',
        ),
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
}

/// Preserves a diagnostic generated at a lower validation boundary. When the
/// error has no record context, this records the precise finalization boundary
/// instead of guessing a store, record, key, or value.
BackupSchemaDiagnostics backupSchemaDiagnosticsForFailure(
  Object error, {
  required String fallbackStage,
}) => error is BackupValidationDiagnosticsException
    ? error.diagnostics
    : BackupSchemaDiagnostics.unavailable(
        validationStage: fallbackStage,
        validationSubstage: 'no_structured_diagnostic',
        failureCategory: switch (error) {
          FormatException _ => 'format_exception',
          TypeError _ => 'type_error',
          BackupException _ => 'backup_contract',
          _ => 'unexpected_exception',
        },
        unavailableReason: 'failure_did_not_provide_record_context',
      );
