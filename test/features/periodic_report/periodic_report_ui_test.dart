import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_center/pages/command_center_page.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/periodic_report/models/periodic_report.dart';
import 'package:or_app/features/periodic_report/pages/periodic_report_page.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  tearDown(AppRepositoryRegistry.resetForTesting);

  test('FINALIZE candidates retain weekly monthly yearly order', () {
    expect(periodicReportTypesForFinalizedDate(DateTime(2027, 1, 31)), [
      PeriodicReportType.weekly,
      PeriodicReportType.monthly,
    ]);
    expect(periodicReportTypesForFinalizedDate(DateTime(2027, 12, 31)), [
      PeriodicReportType.monthly,
      PeriodicReportType.yearly,
    ]);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('Periodic Report panel has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-31'),
      );
      AppRepositoryRegistry.install(container);
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PeriodicReportPanel(reportType: PeriodicReportType.weekly),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('WEEKLY REPORT'), findsOneWidget);
      expect(find.text('weekly:2026-08-24'), findsOneWidget);
      expect(find.text('CREATE REPORT'), findsOneWidget);
    });
  }
}
