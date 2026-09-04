import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/startup_diagnostic.dart';
import 'package:or_app/features/system/pages/startup_diagnostic_page.dart';

void main() {
  testWidgets('shows heartbeat reset and no rejected force boot control', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StartupDiagnosticPage()));
    expect(find.text('REFRESH TRACE'), findsOneWidget);
    expect(find.text('COPY TRACE'), findsOneWidget);
    expect(find.text('CLEAR TRACE'), findsOneWidget);
    expect(find.text('RESET BOOT HEARTBEAT'), findsOneWidget);
    expect(find.text('FORCE NEXT BOOT'), findsNothing);
  });

  testWidgets('reset reports success and records the heartbeat reset event', (
    tester,
  ) async {
    StartupDiagnostic.instance.clear();
    addTearDown(StartupDiagnostic.instance.clear);
    await tester.pumpWidget(const MaterialApp(home: StartupDiagnosticPage()));

    await tester.tap(
      find.byKey(const ValueKey('startup-diagnostic-reset-boot-heartbeat')),
    );
    await tester.pump();

    expect(find.text('BOOT HEARTBEAT RESET'), findsOneWidget);
    expect(
      StartupDiagnostic.instance.events.any(
        (event) => event['event'] == 'BOOT_HEARTBEAT_RESET',
      ),
      isTrue,
    );
  });
}
