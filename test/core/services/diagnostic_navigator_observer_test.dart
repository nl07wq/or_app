import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/diagnostic_navigator_observer.dart';
import 'package:or_app/core/services/system_diagnostics.dart';

void main() {
  testWidgets('named-route observation does not alter navigation behavior', (
    tester,
  ) async {
    final diagnostics = SystemDiagnostics.instance..clear();
    addTearDown(diagnostics.clear);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[
          DiagnosticNavigatorObserver(diagnostics: diagnostics),
        ],
        routes: <String, WidgetBuilder>{
          '/': (_) => Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/next'),
              child: const Text('OPEN'),
            ),
          ),
          '/next': (_) => const Scaffold(body: Text('NEXT')),
        },
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('NEXT'), findsOneWidget);
    final trace = diagnostics.copyText();
    expect(trace, contains('ROUTE_REQUEST'));
    expect(trace, contains('push'));
    expect(trace, contains('/next'));
  });

  testWidgets(
    'invalid route evidence remains observable without interception',
    (tester) async {
      final diagnostics = SystemDiagnostics.instance..clear();
      addTearDown(diagnostics.clear);
      final observer = DiagnosticNavigatorObserver(diagnostics: diagnostics);
      final invalidRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: 'http://or-app.invalid:bad/path?token=secret',
        ),
        builder: (_) => const SizedBox.shrink(),
      );

      observer.didPush(invalidRoute, null);

      final trace = diagnostics.copyText();
      expect(trace, contains('http://or-app.invalid:bad/path'));
      expect(trace, contains('"valid": false'));
      expect(trace, isNot(contains('secret')));
    },
  );

  testWidgets('unnamed popup route can pop before a named system route push', (
    tester,
  ) async {
    final diagnostics = SystemDiagnostics.instance..clear();
    addTearDown(diagnostics.clear);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[
          DiagnosticNavigatorObserver(diagnostics: diagnostics),
        ],
        routes: <String, WidgetBuilder>{
          '/': (context) => Scaffold(
            body: PopupMenuButton<String>(
              onSelected: (route) => Navigator.of(context).pushNamed(route),
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: '/system', child: Text('SYSTEM')),
              ],
            ),
          ),
          '/system': (_) => const Scaffold(body: Text('SYSTEM PAGE')),
        },
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SYSTEM'));
    await tester.pumpAndSettle();

    expect(find.text('SYSTEM PAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final trace = diagnostics.copyText();
    expect(trace, contains('PopupMenuRoute'));
    expect(trace, contains('"action": "pop"'));
    expect(trace, contains('"path": "/system"'));
  });
}
