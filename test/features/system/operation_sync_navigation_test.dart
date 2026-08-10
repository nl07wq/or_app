import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/features/system/pages/device_transfer_page.dart';

void main() {
  testWidgets('TASK-092 Device Transfer exposes formal child entries', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DeviceTransferPage()));

    for (final label in [
      'BACKUP & RESTORE',
      'OPERATION SYNC',
      'SYSTEM MONITORING',
      'HISTORICAL TRAINING IMPORT',
      'HISTORICAL DNS IMPORT',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final stage in [
      'SELECT TRANSFER PACKAGE',
      'VALIDATION',
      'PREVIEW',
      'APPLY',
      'VERIFY',
      'COMPLETE',
    ]) {
      expect(find.text(stage), findsNothing);
    }
  });

  testWidgets('TASK-092 child pages return through Device Transfer to System', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: Text('SYSTEM ROUTE')),
        routes: {
          AppRoutes.deviceTransfer: (_) => const DeviceTransferPage(),
          AppRoutes.backupRestore: (_) =>
              Scaffold(appBar: AppBar(title: const Text('BACKUP & RESTORE'))),
          AppRoutes.operationSync: (_) =>
              Scaffold(appBar: AppBar(title: const Text('OPERATION SYNC'))),
          AppRoutes.systemMonitoring: (_) =>
              Scaffold(appBar: AppBar(title: const Text('SYSTEM MONITORING'))),
          AppRoutes.historicalTrainingImport: (_) => Scaffold(
            appBar: AppBar(title: const Text('HISTORICAL TRAINING IMPORT')),
          ),
          AppRoutes.historicalDnsImport: (_) => Scaffold(
            appBar: AppBar(title: const Text('HISTORICAL DNS IMPORT')),
          ),
        },
      ),
    );
    Navigator.of(
      tester.element(find.text('SYSTEM ROUTE')),
    ).pushNamed(AppRoutes.deviceTransfer);
    await tester.pumpAndSettle();

    for (final label in [
      'BACKUP & RESTORE',
      'OPERATION SYNC',
      'SYSTEM MONITORING',
      'HISTORICAL TRAINING IMPORT',
      'HISTORICAL DNS IMPORT',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, label), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DeviceTransferPage), findsOneWidget);
    }

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('SYSTEM ROUTE'), findsOneWidget);
  });

  testWidgets('TASK-092 removes AVAILABLE and ARCHIVE surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DeviceTransferPage()));
    expect(find.text('AVAILABLE'), findsNothing);
    expect(find.text('ARCHIVE'), findsNothing);
    expect(find.text('DNS ARCHIVE IMPORT'), findsNothing);
  });
}
