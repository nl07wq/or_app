import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/services/system_diagnostics.dart';
import 'package:or_app/features/system/pages/dashboard_diagnostic_page.dart';
import 'package:or_app/features/system/pages/diagnostics_page.dart';
import 'package:or_app/features/system/pages/startup_diagnostic_page.dart';

void main() {
  testWidgets('DIAGNOSTICS opens STARTUP and DASHBOARD destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const DiagnosticsPage(),
        routes: {
          AppRoutes.startupDiagnostic: (_) => const StartupDiagnosticPage(),
          AppRoutes.dashboardDiagnostic: (_) => const DashboardDiagnosticPage(),
        },
      ),
    );

    expect(find.text('STARTUP'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);
    await tester.tap(find.text('OPEN STARTUP'));
    await tester.pumpAndSettle();
    expect(find.text('STARTUP DIAGNOSTIC'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN DASHBOARD'));
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD DIAGNOSTICS'), findsOneWidget);
  });

  testWidgets('dashboard diagnostics provides copy export and clear', (
    tester,
  ) async {
    SystemDiagnostics.instance
      ..clear()
      ..beginSession()
      ..record('BASE_CAMP', 'MAP_DISPLAY_COMPLETE');
    addTearDown(SystemDiagnostics.instance.clear);
    await tester.pumpWidget(const MaterialApp(home: DashboardDiagnosticPage()));

    expect(find.textContaining('SAVED SESSIONS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dashboard-diagnostic-copy')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('dashboard-diagnostic-copy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-diagnostic-export')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dashboard-diagnostic-clear')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('dashboard-diagnostic-clear')));
    await tester.pump();
    expect(find.text('SAVED SESSIONS  0 / 5'), findsOneWidget);
  });
}
