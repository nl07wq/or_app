import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/features/system/pages/operation_sync_page.dart';

void main() {
  testWidgets('Operation Sync opens Historical Training Import', (
    tester,
  ) async {
    await _pumpEntry(tester);

    await _open(tester, 'HISTORICAL TRAINING IMPORT');

    expect(find.byType(HistoricalTrainingImportPage), findsOneWidget);
    expect(
      find.widgetWithText(AppBar, 'HISTORICAL TRAINING IMPORT'),
      findsOneWidget,
    );
  });

  testWidgets('Operation Sync opens Historical DNS Import with formal name', (
    tester,
  ) async {
    await _pumpEntry(tester);

    await _open(tester, 'HISTORICAL DNS IMPORT');

    expect(find.byType(HistoricalDnsImportPage), findsOneWidget);
    expect(
      find.widgetWithText(AppBar, 'HISTORICAL DNS IMPORT'),
      findsOneWidget,
    );
    expect(find.text('DNS HISTORICAL IMPORT'), findsNothing);
  });

  testWidgets('both Historical Import pages return to Operation Sync', (
    tester,
  ) async {
    await _pumpEntry(tester);

    await _open(tester, 'HISTORICAL TRAINING IMPORT');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(OperationSyncPage), findsOneWidget);

    await _open(tester, 'HISTORICAL DNS IMPORT');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(OperationSyncPage), findsOneWidget);
  });
}

Future<void> _pumpEntry(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: const OperationSyncPage(),
      routes: {
        AppRoutes.historicalTrainingImport: (_) =>
            const HistoricalTrainingImportPage(),
        AppRoutes.historicalDnsImport: (_) => const HistoricalDnsImportPage(),
      },
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String label) async {
  final target = find.text(label).first;
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}
