import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/state/app_initialization_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import 'models/backup_package.dart';
import 'services/backup_file_export_service.dart';
import 'services/backup_file_gateway.dart';
import 'services/backup_import_service.dart';
import 'services/backup_package_codec.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  late final BackupFileGateway _fileGateway;
  BackupPackage? _selectedPackage;
  BackupImportPlan? _plan;
  BackupImportMode _mode = BackupImportMode.merge;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fileGateway = BackupFileGateway.platform();
  }

  bool get _available =>
      kIsWeb &&
      appInitializationController.value.mode ==
          PersistenceMode.indexedDbReadWrite;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await BackupFileExportService(
        fileGateway: _fileGateway,
      ).export();
      if (result.delivery == BackupFileDelivery.cancelled) {
        if (mounted) {
          setState(() => _message = 'BACKUPの保存をキャンセルしました。');
        }
        return;
      }
      final package = result.package;
      if (mounted) {
        setState(() {
          _message =
              'BACKUP READY — ${package.recordCounts.values.values.fold<int>(0, (a, b) => a + b)} records';
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
    });
    try {
      final file = await _fileGateway.selectJson();
      if (file == null) return;
      final package = const BackupPackageCodec().decodeUtf8(file.bytes);
      final mode = package.permitsReplaceAll ? _mode : BackupImportMode.merge;
      final plan = await BackupImportService().dryRun(package, mode);
      if (mounted) {
        setState(() {
          _selectedPackage = package;
          _mode = mode;
          _plan = plan;
          _message = plan.hasConflicts
              ? 'VALIDATION FAILED — conflicts detected'
              : 'BACKUP VALIDATED — review the import plan';
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
      if (mounted) setState(() => _plan = plan);
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null || plan.hasConflicts) return;
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
            text: 'EXPORT BACKUP',
            onPressed: _available && !_busy ? _export : null,
          ),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.upload_file_outlined,
            text: 'IMPORT BACKUP',
            onPressed: _available && !_busy ? _selectImport : null,
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
              '${section.key}: add ${section.value.add}, '
              'skip ${section.value.skip}, replace ${section.value.replace}, '
              'conflict ${section.value.conflicts.length}',
            ),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.restore,
            text: 'IMPORT DATA',
            onPressed: !_busy && !plan.hasConflicts ? _import : null,
          ),
        ],
      ),
    );
  }

  static String _errorMessage(Object error) => error is BackupException
      ? '${error.code}: ${error.message}'
      : 'backup_failed: $error';
}
