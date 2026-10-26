import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/global_touch_ripple.dart';

class ReportSyncActionBar extends StatelessWidget {
  const ReportSyncActionBar({
    super.key,
    required this.enabled,
    required this.onPaste,
    required this.onClear,
    required this.onValidate,
    this.deferPaste = false,
    this.deferValidate = false,
    this.reportUnavailableFeedback = false,
  });

  final bool enabled;
  final VoidCallback onPaste;
  final VoidCallback onClear;
  final VoidCallback onValidate;
  final bool deferPaste;
  final bool deferValidate;
  final bool reportUnavailableFeedback;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('report-sync-response-action-bar'),
    children: [
      Expanded(
        child: _ReportSyncActionButton(
          key: const ValueKey('report-sync-response-action-paste'),
          icon: Icons.content_paste_outlined,
          label: 'PASTE',
          onPressed: enabled ? onPaste : null,
          deferFeedback: deferPaste,
          reportUnavailableFeedback: reportUnavailableFeedback,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: _ReportSyncActionButton(
          key: const ValueKey('report-sync-response-action-clear'),
          icon: Icons.backspace_outlined,
          label: 'CLEAR',
          onPressed: enabled ? onClear : null,
          reportUnavailableFeedback: reportUnavailableFeedback,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: _ReportSyncActionButton(
          key: const ValueKey('report-sync-response-action-validate'),
          icon: Icons.fact_check_outlined,
          label: 'VALIDATE',
          onPressed: enabled ? onValidate : null,
          deferFeedback: deferValidate,
          reportUnavailableFeedback: reportUnavailableFeedback,
        ),
      ),
    ],
  );
}

class _ReportSyncActionButton extends StatelessWidget {
  const _ReportSyncActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.deferFeedback = false,
    this.reportUnavailableFeedback = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool deferFeedback;
  final bool reportUnavailableFeedback;

  @override
  Widget build(BuildContext context) => ActionableFeedbackRegion(
    enabled: onPressed != null || reportUnavailableFeedback,
    result: onPressed == null
        ? ActionableFeedbackResult.unavailable
        : ActionableFeedbackResult.accepted,
    deferResolution: onPressed != null && deferFeedback,
    child: SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(label),
            ],
          ),
        ),
      ),
    ),
  );
}
