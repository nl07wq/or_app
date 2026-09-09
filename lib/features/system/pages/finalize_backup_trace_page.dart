import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/finalize_backup_trace.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

/// Temporary on-device viewer for Dashboard/Command Center parity evidence.
class FinalizeBackupTracePage extends StatefulWidget {
  const FinalizeBackupTracePage({super.key});

  @override
  State<FinalizeBackupTracePage> createState() =>
      _FinalizeBackupTracePageState();
}

class _FinalizeBackupTracePageState extends State<FinalizeBackupTracePage> {
  static const _traceViewerHeight = 280.0;
  String _trace = FinalizeBackupTrace.instance.copyText();

  void _refresh() =>
      setState(() => _trace = FinalizeBackupTrace.instance.copyText());

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _trace));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FINALIZE BACKUP TRACE COPIED')),
    );
  }

  void _clear() {
    FinalizeBackupTrace.instance.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FINALIZE BACKUP TRACE')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.compare_arrows_outlined,
          title: 'FINALIZE BACKUP PARITY TRACE',
        ),
        AppSpacing.gapSM,
        const Text(
          'Temporary lifecycle trace for comparing Dashboard and Command '
          'Center Backup prompt presentation. It contains no formal record data.',
        ),
        AppSpacing.gapMD,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${FinalizeBackupTrace.instance.events.length} EVENTS'),
              AppSpacing.gapSM,
              SizedBox(
                height: _traceViewerHeight,
                child: Scrollbar(
                  child: SingleChildScrollView(
                    key: const ValueKey('finalize-backup-trace-viewer'),
                    padding: const EdgeInsets.only(right: 8),
                    child: SelectableText(
                      _trace,
                      key: const ValueKey('finalize-backup-trace'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapMD,
        OperationButton(
          text: 'REFRESH TRACE',
          icon: Icons.refresh,
          onPressed: _refresh,
        ),
        AppSpacing.gapSM,
        OperationButton(
          text: 'COPY TRACE',
          icon: Icons.copy_outlined,
          onPressed: _copy,
        ),
        AppSpacing.gapSM,
        OperationButton(
          key: const ValueKey('finalize-backup-trace-clear'),
          text: 'CLEAR TRACE',
          icon: Icons.delete_outline,
          role: OperationActionRole.danger,
          onPressed: _clear,
        ),
        AppSpacing.gapLG,
      ],
    ),
  );
}
