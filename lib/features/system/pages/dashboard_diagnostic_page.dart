import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/system_diagnostics.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/global_touch_ripple.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../themes/base_camp/widgets/base_camp_operation_panel.dart';

class DashboardDiagnosticPage extends StatefulWidget {
  const DashboardDiagnosticPage({super.key});

  @override
  State<DashboardDiagnosticPage> createState() =>
      _DashboardDiagnosticPageState();
}

class _DashboardDiagnosticPageState extends State<DashboardDiagnosticPage> {
  static const _viewerHeight = 320.0;
  late String _trace;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => _trace = SystemDiagnostics.instance.copyText();

  void _refreshState() => setState(_refresh);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _trace));
    if (!mounted) return;
    _showNotice('DASHBOARD DIAGNOSTICS COPIED');
  }

  Future<void> _copyUriEvidence() async {
    await Clipboard.setData(
      ClipboardData(text: SystemDiagnostics.instance.copyUriEvidenceText()),
    );
    if (!mounted) return;
    _showNotice('URI EXCEPTION EVIDENCE COPIED');
  }

  Future<void> _copySlowStartupEvidence() async {
    await Clipboard.setData(
      ClipboardData(
        text: SystemDiagnostics.instance.copySlowStartupEvidenceText(),
      ),
    );
    if (!mounted) return;
    _showNotice('SLOW STARTUP EVIDENCE COPIED');
  }

  Future<void> _export() async {
    final exported = await SystemDiagnostics.instance.export();
    if (!mounted) return;
    _showNotice(
      exported ? 'DIAGNOSTICS EXPORTED' : 'EXPORT UNAVAILABLE',
      failure: !exported,
    );
  }

  void _showNotice(String message, {bool failure = false}) =>
      showBaseCampOperationNotice(
        context,
        title: 'DASHBOARD DIAGNOSTICS',
        message: message,
        result: failure
            ? BaseCampOperationNoticeResult.failure
            : BaseCampOperationNoticeResult.success,
      );

  void _clear() {
    SystemDiagnostics.instance.clear();
    _refreshState();
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = SystemDiagnostics.instance;
    return Scaffold(
      appBar: AppBar(
        leading: const ActionableBackButton(),
        title: const Text('DASHBOARD DIAGNOSTICS'),
      ),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(
            icon: Icons.speed_outlined,
            title: 'BASE CAMP DASHBOARD',
          ),
          AppSpacing.gapSM,
          const Text(
            '端末内に最大5セッション・各200イベントを保存します。'
            'OSまたはWebKit強制終了は確定できないため、未完了セッションは異常終了の疑いとして表示します。',
          ),
          AppSpacing.gapMD,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('SESSION  ${diagnostics.sessionId ?? 'NOT STARTED'}'),
                AppSpacing.gapSM,
                Text('SAVED SESSIONS  ${diagnostics.sessions.length} / 5'),
                AppSpacing.gapSM,
                Text(
                  diagnostics.previousSessionAbnormalSuspected
                      ? 'PREVIOUS SESSION  ABNORMAL TERMINATION SUSPECTED'
                      : 'PREVIOUS SESSION  NO SUSPICION RECORDED',
                  key: const ValueKey('dashboard-diagnostic-abnormal-status'),
                ),
                AppSpacing.gapMD,
                SizedBox(
                  height: _viewerHeight,
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      key: const ValueKey('dashboard-diagnostic-trace-viewer'),
                      padding: const EdgeInsets.only(right: 8),
                      child: SelectableText(
                        _trace,
                        key: const ValueKey('dashboard-diagnostic-trace'),
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
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  diagnostics.slowStartupEvidenceOperational
                      ? 'SLOW STARTUP CAPTURE  OPERATIONAL'
                      : 'SLOW STARTUP CAPTURE  UNAVAILABLE',
                  key: const ValueKey('slow-startup-evidence-status'),
                ),
                AppSpacing.gapSM,
                Text(
                  'RETAINED INCIDENTS  '
                  '${diagnostics.slowStartupIncidentCount} / 5',
                  key: const ValueKey('slow-startup-incident-count'),
                ),
                if (diagnostics.slowStartupIncidentSummaries.isNotEmpty) ...[
                  AppSpacing.gapSM,
                  ...diagnostics.slowStartupIncidentSummaries.map(
                    (incident) => Text(
                      '${incident['timestamp']}  '
                      '${incident['captureCompleteness']}  '
                      '${incident['status']}',
                    ),
                  ),
                ],
                AppSpacing.gapSM,
                const Text(
                  'Slow launches are retained separately from routine session '
                  'rotation and URI evidence. Export is local and bounded.',
                ),
              ],
            ),
          ),
          AppSpacing.gapMD,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  diagnostics.uriEvidenceOperational
                      ? 'URI CAPTURE  OPERATIONAL'
                      : 'URI CAPTURE  UNAVAILABLE',
                  key: const ValueKey('uri-evidence-operational-status'),
                ),
                AppSpacing.gapSM,
                Text(
                  'RETAINED INCIDENTS  ${diagnostics.uriIncidentCount} / 5',
                  key: const ValueKey('uri-evidence-incident-count'),
                ),
                if (diagnostics.uriIncidentSummaries.isNotEmpty) ...[
                  AppSpacing.gapSM,
                  ...diagnostics.uriIncidentSummaries.map(
                    (incident) => Text(
                      '${incident['timestamp']}  '
                      '${incident['captureCompleteness']}  '
                      '${incident['status']}',
                    ),
                  ),
                ],
                AppSpacing.gapSM,
                const Text(
                  'Evidence is stored separately from routine session rotation. '
                  'Export is local and user initiated; no automatic upload occurs.',
                ),
              ],
            ),
          ),
          AppSpacing.gapMD,
          OperationButton(
            text: 'REFRESH',
            icon: Icons.refresh,
            onPressed: _refreshState,
          ),
          AppSpacing.gapSM,
          OperationButton(
            key: const ValueKey('uri-evidence-copy'),
            text: 'COPY URI EVIDENCE',
            icon: Icons.link_outlined,
            onPressed: _copyUriEvidence,
          ),
          AppSpacing.gapSM,
          OperationButton(
            key: const ValueKey('slow-startup-evidence-copy'),
            text: 'COPY SLOW STARTUP EVIDENCE',
            icon: Icons.timer_outlined,
            onPressed: _copySlowStartupEvidence,
          ),
          AppSpacing.gapSM,
          OperationButton(
            key: const ValueKey('dashboard-diagnostic-copy'),
            text: 'COPY',
            icon: Icons.copy_outlined,
            onPressed: _copy,
          ),
          AppSpacing.gapSM,
          OperationButton(
            key: const ValueKey('dashboard-diagnostic-export'),
            text: 'EXPORT',
            icon: Icons.download_outlined,
            onPressed: _export,
          ),
          AppSpacing.gapSM,
          OperationButton(
            key: const ValueKey('dashboard-diagnostic-clear'),
            text: 'CLEAR',
            icon: Icons.delete_outline,
            role: OperationActionRole.danger,
            onPressed: _clear,
          ),
          AppSpacing.gapLG,
        ],
      ),
    );
  }
}
