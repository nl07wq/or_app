import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/startup_diagnostic.dart';
import '../../../core/services/active_session_heartbeat.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

/// Temporary on-device viewer for the bounded startup lifecycle trace.
class StartupDiagnosticPage extends StatefulWidget {
  const StartupDiagnosticPage({super.key});

  @override
  State<StartupDiagnosticPage> createState() => _StartupDiagnosticPageState();
}

class _StartupDiagnosticPageState extends State<StartupDiagnosticPage> {
  static const _traceViewerHeight = 280.0;
  String _trace = StartupDiagnostic.instance.copyText();

  void _refresh() =>
      setState(() => _trace = StartupDiagnostic.instance.copyText());

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _trace));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('STARTUP TRACE COPIED')));
  }

  void _clear() {
    StartupDiagnostic.instance.clear();
    _refresh();
  }

  void _resetBootHeartbeat() {
    final reset = ActiveSessionHeartbeat.instance.resetHeartbeat();
    StartupDiagnostic.instance.record(
      'SYSTEM',
      reset ? 'BOOT_HEARTBEAT_RESET' : 'BOOT_HEARTBEAT_RESET_FAILED',
    );
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reset ? 'BOOT HEARTBEAT RESET' : 'BOOT HEARTBEAT RESET FAILED',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('STARTUP DIAGNOSTIC')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.bug_report_outlined,
          title: 'STARTUP DIAGNOSTIC',
        ),
        AppSpacing.gapSM,
        const Text(
          'Temporary lifecycle trace for iOS/PWA startup investigation. '
          'It contains no application record data.',
        ),
        AppSpacing.gapMD,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${StartupDiagnostic.instance.events.length} EVENTS'),
              AppSpacing.gapSM,
              SizedBox(
                height: _traceViewerHeight,
                child: Scrollbar(
                  child: SingleChildScrollView(
                    key: const ValueKey('startup-diagnostic-trace-viewer'),
                    padding: const EdgeInsets.only(right: 8),
                    child: SelectableText(
                      _trace,
                      key: const ValueKey('startup-diagnostic-trace'),
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
          key: const ValueKey('startup-diagnostic-reset-boot-heartbeat'),
          text: 'RESET BOOT HEARTBEAT',
          icon: Icons.restart_alt,
          onPressed: _resetBootHeartbeat,
        ),
        AppSpacing.gapSM,
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
          key: const ValueKey('startup-diagnostic-clear'),
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
