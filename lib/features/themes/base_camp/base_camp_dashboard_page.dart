import 'package:flutter/material.dart';

import 'package:or_app/features/dashboard/dashboard_page.dart';

/// BASE CAMP owns a distinct Dashboard entrypoint. Its V1 delta is limited to
/// the Base Camp QUICK ACCESS presentation; all Dashboard data and actions are
/// deliberately the same shared implementation as STANDARD.
class BaseCampDashboardPage extends StatelessWidget {
  const BaseCampDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => const DashboardPage(
    quickAccessPresentation: DashboardQuickAccessPresentation.baseCamp,
  );
}
