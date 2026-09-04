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
    expect(find.text('COPY TRACE', skipOffstage: false), findsOneWidget);
    expect(find.text('CLEAR TRACE', skipOffstage: false), findsOneWidget);
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

  testWidgets('keeps a long trace inside a bounded, independently scrollable viewer', (
    tester,
  ) async {
    StartupDiagnostic.instance.clear();
    addTearDown(StartupDiagnostic.instance.clear);
    for (var index = 0; index < 200; index++) {
      StartupDiagnostic.instance.record(
        'TEST',
        'LONG_TRACE_EVENT',
        fields: {'index': index, 'detail': 'x' * 40},
      );
    }
    await tester.pumpWidget(const MaterialApp(home: StartupDiagnosticPage()));

    final viewer = find.byKey(
      const ValueKey('startup-diagnostic-trace-viewer'),
    );
    expect(tester.getSize(viewer).height, 280);
    expect(find.descendant(of: viewer, matching: find.text('RESET BOOT HEARTBEAT')), findsNothing);
    expect(find.byKey(const ValueKey('startup-diagnostic-reset-boot-heartbeat')), findsOneWidget);
    expect(find.text('REFRESH TRACE', skipOffstage: false), findsOneWidget);
    expect(find.text('COPY TRACE', skipOffstage: false), findsOneWidget);
    expect(find.text('CLEAR TRACE', skipOffstage: false), findsOneWidget);

    await tester.drag(viewer, const Offset(0, -180));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
