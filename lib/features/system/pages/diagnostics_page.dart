import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/global_touch_ripple.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const ActionableBackButton(),
      title: const Text('DIAGNOSTICS'),
    ),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.monitor_heart_outlined,
          title: 'DIAGNOSTICS',
        ),
        AppSpacing.gapSM,
        _DiagnosticDestination(
          title: 'STARTUP',
          description: '既存の起動トレースとBOOT heartbeatを確認します。',
          buttonText: 'OPEN STARTUP',
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.startupDiagnostic),
        ),
        AppSpacing.gapXL,
        _DiagnosticDestination(
          title: 'DASHBOARD',
          description: 'BASE CAMPの表示・アセット・例外・前回セッションを確認します。',
          buttonText: 'OPEN DASHBOARD',
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.dashboardDiagnostic),
        ),
        AppSpacing.gapLG,
      ],
    ),
  );
}

class _DiagnosticDestination extends StatelessWidget {
  const _DiagnosticDestination({
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(icon: Icons.bug_report_outlined, title: title),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description),
            AppSpacing.gapMD,
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.open_in_new),
                label: Text(buttonText),
              ).actionableFeedback(),
            ),
          ],
        ),
      ),
    ],
  );
}
