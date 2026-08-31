import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/state/app_initialization_state.dart';
import '../../core/services/persistence_access.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import 'models/backup_package.dart';
import 'models/backup_audit_package.dart';
import 'services/backup_audit_package_codec.dart';
import 'services/backup_file_export_service.dart';
import 'services/backup_file_gateway.dart';
import 'services/backup_import_service.dart';
import 'services/backup_package_codec.dart';
import 'services/backup_v14_transform.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  late final BackupFileGateway _fileGateway;
  BackupPackage? _selectedPackage;
  BackupPackage? _selectedNormalPackage;
  BackupAuditPackage? _selectedAuditPackage;
  BackupImportPlan? _plan;
  BackupImportMode _mode = BackupImportMode.merge;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fileGateway = BackupFileGateway.platform();
  }

  bool get _exportAvailable =>
      kIsWeb &&
      (appInitializationController.value.mode ==
              PersistenceMode.indexedDbReadWrite ||
          (appInitializationController.value.isReadOnly &&
              PersistenceAccess.canReadIndexedDb));

  bool get _importAvailable =>
      kIsWeb &&
      appInitializationController.value.mode ==
          PersistenceMode.indexedDbReadWrite;

  Future<void> _exportV14() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await BackupFileExportService(
        fileGateway: _fileGateway,
      ).exportV14Bundle();
      if (result.normalDelivery == BackupFileDelivery.cancelled) {
        if (mounted) {
          setState(() => _message = 'BACKUPの保存をキャンセルしました。');
        }
        return;
      }
      final package = result.bundle.normal;
      if (mounted) {
        setState(() {
          _message =
              'V14 NORMAL READY — ${package.recordCounts.values.values.fold<int>(0, (a, b) => a + b)} records; '
              'AUDIT ${result.auditDelivery == BackupFileDelivery.cancelled ? 'CANCELLED' : 'READY'}';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportLegacyV13() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await BackupFileExportService(
        fileGateway: _fileGateway,
      ).exportLegacyV13();
      if (mounted) {
        setState(() {
          _message = result.delivery == BackupFileDelivery.cancelled
              ? 'V13 FULL BACKUP CANCELLED'
              : 'V13 FULL BACKUP READY';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectImport() async {
    setState(() {
      _busy = true;
      _message = null;
      _plan = null;
      _selectedAuditPackage = null;
    });
    try {
      final file = await _fileGateway.selectJson();
      if (file == null) {
        if (mounted) setState(() => _message = 'IMPORT CANCELLED');
        return;
      }
      final package = const BackupPackageCodec().decodeUtf8(file.bytes);
      final mode = package.permitsReplaceAll ? _mode : BackupImportMode.merge;
      final plan = await BackupImportService().dryRun(package, mode);
      if (mounted) {
        setState(() {
          _selectedPackage = package;
          _selectedNormalPackage = package;
          _mode = mode;
          _plan = plan;
          _message = _planMessage(plan);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectAuditArchive() async {
    final normal = _selectedNormalPackage;
    if (normal == null || normal.schemaVersion != 14) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file = await _fileGateway.selectJson();
      if (file == null) {
        if (mounted) setState(() => _message = 'AUDIT IMPORT CANCELLED');
        return;
      }
      final audit = const BackupAuditPackageCodec().decodeUtf8(file.bytes);
      final hydrated = BackupV14Transform.hydratePackage(normal, audit);
      final plan = await BackupImportService().dryRun(hydrated, _mode);
      if (mounted) {
        setState(() {
          _selectedAuditPackage = audit;
          _selectedPackage = hydrated;
          _plan = plan;
          _message = 'NORMAL + AUDIT VALIDATED — review the import plan';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeMode(BackupImportMode mode) async {
    final package = _selectedPackage;
    if (package == null ||
        (mode == BackupImportMode.replaceAll && !package.permitsReplaceAll)) {
      return;
    }
    setState(() {
      _busy = true;
      _mode = mode;
    });
    try {
      final plan = await BackupImportService().dryRun(package, mode);
      if (mounted) {
        setState(() {
          _plan = plan;
          _message = _planMessage(plan);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null || plan.hasBlockingConflicts) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          plan.mode == BackupImportMode.replaceAll
              ? 'REPLACE ALL DATA?'
              : 'IMPORT BACKUP?',
        ),
        content: Text(
          plan.mode == BackupImportMode.replaceAll
              ? 'This will replace all local records. Create a backup before continuing.'
              : 'Only records that do not already exist will be added.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('IMPORT DATA'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await BackupImportService().execute(plan);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.success
          ? 'BACKUP RESTORED'
          : '${result.errorCode}: ${result.message}';
      if (result.success) {
        _selectedPackage = null;
        _selectedNormalPackage = null;
        _selectedAuditPackage = null;
        _plan = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BACKUP & RESTORE')),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(
            icon: Icons.security_outlined,
            title: 'BACKUP & RESTORE',
          ),
          AppSpacing.gapMD,
          const OperationCard(
            child: Text(
              'Backup files contain personal health and activity data. '
              'They are not encrypted. Store and share them carefully.',
            ),
          ),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.download_outlined,
            text: 'EXPORT V14 NORMAL + AUDIT',
            onPressed: _exportAvailable && !_busy ? _exportV14 : null,
          ),
          AppSpacing.gapSM,
          OperationButton(
            icon: Icons.archive_outlined,
            text: 'EXPORT LEGACY V13 FULL',
            onPressed: _exportAvailable && !_busy ? _exportLegacyV13 : null,
          ),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.upload_file_outlined,
            text: 'IMPORT BACKUP',
            onPressed: _importAvailable && !_busy ? _selectImport : null,
          ),
          if (!kIsWeb) ...[
            AppSpacing.gapMD,
            const Text(
              'Backup import and export are available on Web/PWA only.',
            ),
          ],
          if (_plan != null) ...[AppSpacing.gapXL, _buildPlan(_plan!)],
          if (_message != null) ...[
            AppSpacing.gapMD,
            SelectableText(_message!),
          ],
        ],
      ),
    );
  }

  Widget _buildPlan(BackupImportPlan plan) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('IMPORT PLAN', style: Theme.of(context).textTheme.titleMedium),
          Text('BACKUP SCHEMA ${plan.package.schemaVersion}.0'),
          if (plan.package.schemaVersion == 14) ...[
            AppSpacing.gapSM,
            Text(
              _selectedAuditPackage == null
                  ? 'NORMAL ONLY — archived detail will be unavailable'
                  : 'NORMAL + MATCHED AUDIT ARCHIVE',
            ),
            AppSpacing.gapSM,
            OperationButton(
              icon: Icons.inventory_2_outlined,
              text: 'ATTACH AUDIT ARCHIVE',
              onPressed: !_busy ? _selectAuditArchive : null,
            ),
          ],
          if (plan.package.schemaVersion < 8) ...[
            AppSpacing.gapSM,
            const Text(
              'このBackupにはプロフィール情報が含まれていません。'
              '現在のプロフィールは維持されます。',
            ),
          ],
          AppSpacing.gapMD,
          SegmentedButton<BackupImportMode>(
            segments: const [
              ButtonSegment(
                value: BackupImportMode.merge,
                label: Text('MERGE'),
              ),
              ButtonSegment(
                value: BackupImportMode.replaceAll,
                label: Text('REPLACE ALL'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: _selectedPackage!.permitsReplaceAll && !_busy
                ? (value) => _changeMode(value.single)
                : null,
          ),
          AppSpacing.gapMD,
          for (final section in plan.sections.entries)
            Text(
              plan.mode == BackupImportMode.merge &&
                      section.key == BackupSections.operationState
                  ? '${section.key}: CURRENT STATE WILL BE KEPT'
                  : '${section.key}: add ${section.value.add}, '
                        'skip ${section.value.skip}, '
                        'replace ${section.value.replace}, '
                        'conflict ${section.value.conflicts.length}',
            ),
          if (plan.mode == BackupImportMode.merge && plan.hasConflicts) ...[
            AppSpacing.gapMD,
            const Text('CONFLICT RECORDS WILL BE EXCLUDED'),
          ],
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.restore,
            text: 'IMPORT DATA',
            onPressed: !_busy && !plan.hasBlockingConflicts ? _import : null,
          ),
        ],
      ),
    );
  }

  static String _errorMessage(Object error) => error is BackupException
      ? '${error.code}: ${error.message}'
      : 'backup_failed: $error';

  static String _planMessage(BackupImportPlan plan) =>
      plan.hasConflicts && plan.mode == BackupImportMode.merge
      ? 'BACKUP VALIDATED — conflict records will be excluded'
      : plan.hasBlockingConflicts
      ? 'VALIDATION FAILED — conflicts detected'
      : 'BACKUP VALIDATED — review the import plan';
}
