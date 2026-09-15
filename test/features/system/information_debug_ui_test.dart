import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/dashboard/widgets/operation_ambient_animation.dart';
import 'package:or_app/core/engine/operation_status.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/system/models/information_notice.dart';
import 'package:or_app/features/system/pages/system_monitoring_page.dart';
import 'package:or_app/features/system/services/information_notice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRepositoryRegistry.install(
      AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase()),
    );
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('creates and clears explicitly marked test notices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SystemMonitoringPage()));
    await _settleUi(tester);

    expect(find.text('INFORMATION DEBUG'), findsOneWidget);
    expect(find.text('INFORMATION MARQUEE RUNTIME'), findsOneWidget);
    expect(find.text('SPEED  40 px/s'), findsOneWidget);
    expect(find.text('AMBIENT PULSE DEBUG'), findsOneWidget);
    expect(find.byType(OperationAmbientAnimation), findsNWidgets(4));
    expect(
      find.byKey(const ValueKey('ambient-pulse-debug-neutral')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ambient-pulse-debug-green')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ambient-pulse-debug-yellow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ambient-pulse-debug-red')),
      findsOneWidget,
    );
    expect(
      OperationAmbientPulseGeometry.forPreset(
        operationAmbientPulsePresetFor(OperationStatus.green),
      ).amplitude,
      8,
    );
    expect(
      tester
          .widgetList<OperationAmbientAnimation>(
            find.byType(OperationAmbientAnimation),
          )
          .map((animation) => animation.status),
      [
        null,
        OperationStatus.green,
        OperationStatus.yellow,
        OperationStatus.red,
      ],
    );
    expect(find.text('DAILY BRIEF V2 REVIEW'), findsOneWidget);
    await tester.tap(find.text('CREATE TEST NOTICE'));
    await _settleUi(tester);
    expect(find.text('INFORMATION TEST'), findsOneWidget);
    expect(find.text('PRIORITY'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '作成'));
    await _settleUi(tester);
    expect(find.text('TEST'), findsWidgets);
    expect(find.text('INFORMATION TEST'), findsOneWidget);
    expect(find.text('CLEAR TEST NOTICES'), findsOneWidget);

    await tester.tap(find.text('CLEAR TEST NOTICES'));
    await _settleUi(tester);
    expect(find.text('テスト通知をすべて削除しますか？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '削除'));
    await _settleUi(tester);
    expect(find.text('CLEAR TEST NOTICES'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard consumes a test notice through the production strip', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-09-14');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    appInitializationController.markReady();
    await InformationNoticeService().createDebugNotice(
      title: 'TEST INFORMATION — RECOVERY V2 BETA VALIDATION REVIEW READY',
      message: 'Dashboard pipeline test',
      priority: InformationNoticePriority.informational,
    );

    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    await _settleUi(tester);
    expect(
      find.byKey(const ValueKey('dashboard-information-strip')),
      findsOneWidget,
    );
    expect(
      find.text('TEST INFORMATION — RECOVERY V2 BETA VALIDATION REVIEW READY'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('dashboard-information-strip')));
    await _settleUi(tester);
    expect(find.text('Dashboard pipeline test'), findsOneWidget);
    await tester.tap(find.text('表示から消す'));
    await _settleUi(tester);
    expect(
      find.byKey(const ValueKey('dashboard-information-strip')),
      findsNothing,
    );
  });

  testWidgets('debug controls remain usable at compact and wide widths', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: SystemMonitoringPage()));
      await _settleUi(tester);
      expect(find.text('INFORMATION DEBUG'), findsOneWidget);
      expect(find.text('CREATE TEST NOTICE'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('AMBIENT PULSE DEBUG'), 300);
      await tester.pump();
      expect(find.byType(OperationAmbientAnimation), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

Future<void> _settleUi(WidgetTester tester) async {
  // Dashboard includes a deliberate perpetual ambient pulse. A bounded pump
  // flushes the finite interaction work without waiting for that pulse.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
