import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/startup_diagnostic.dart';
import 'package:or_app/features/system/pages/startup_diagnostic_page.dart';

void main() {
  testWidgets('viewer refreshes and clears the temporary startup trace', (
    tester,
  ) async {
    StartupDiagnostic.instance.clear();
    StartupDiagnostic.instance.beginRun();
    StartupDiagnostic.instance.record('DART', 'DART_MAIN_ENTER');

    await tester.pumpWidget(const MaterialApp(home: StartupDiagnosticPage()));

    expect(
      find.byKey(const ValueKey('startup-diagnostic-trace')),
      findsOneWidget,
    );
    expect(find.text('COPY TRACE'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('startup-diagnostic-clear')));
    await tester.pump();
    expect(StartupDiagnostic.instance.events, isEmpty);
  });
}
