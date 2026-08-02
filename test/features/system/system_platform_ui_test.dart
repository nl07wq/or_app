import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/models/daily_log_confirmation_status.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/services/daily_log_confirmation_state.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/system/pages/about_page.dart';
import 'package:or_app/features/system/pages/operation_sync_page.dart';
import 'package:or_app/features/system/pages/profile_page.dart';
import 'package:or_app/features/system/pages/system_page.dart';
import 'package:or_app/features/system/services/app_data_initialization_service.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(() {
    appInitializationController.markReady();
    dailyLogConfirmationNotifier.value = DailyLogConfirmationStatus.unconfirmed(
      DateTime(2026, 8, 2),
    );
    morningFactNotifier.value = null;
    foodSummaryNotifier.value = null;
    trainingSummaryNotifier.value = null;
    activitySummaryNotifier.value = const ActivitySummary.empty();
  });

  testWidgets('HOME menu exposes and navigates to the three formal pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.dashboard,
        routes: {
          AppRoutes.dashboard: (_) => const DashboardPage(),
          AppRoutes.profile: (_) => const ProfilePage(),
          AppRoutes.about: (_) => const AboutPage(),
          AppRoutes.system: (_) => const SystemPage(),
        },
      ),
    );
    await tester.pump();

    expect(find.byTooltip('SYSTEM MENU'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    await tester.tap(find.byTooltip('SYSTEM MENU'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.account_circle), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('SYSTEM'), findsOneWidget);

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    Navigator.of(tester.element(find.byType(ProfilePage))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('SYSTEM MENU'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ABOUT'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(AboutPage))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('SYSTEM MENU'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SYSTEM'));
    await tester.pumpAndSettle();
    expect(find.byType(SystemPage), findsOneWidget);
  });

  testWidgets('PROFILE and ABOUT have distinct display-only responsibilities', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    expect(find.text('User Name'), findsOneWidget);
    expect(find.text('Version'), findsNothing);
    expect(find.text('Operation Reboot Version'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Operation Reboot Version'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Theme'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('SYSTEM shows storage and data health and opens OPERATION SYNC', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: SystemPage(
          dataHealthLoader: () async => const SystemDataHealthSnapshot(
            integrity: 'READABLE',
            recoveryStatus: 'NO RECOVERY REQUIRED',
            healthStatus: 'HEALTHY',
          ),
        ),
        routes: {AppRoutes.operationSync: (_) => const OperationSyncPage()},
      ),
    );

    expect(find.text('OPERATION SYNC'), findsWidgets);
    expect(find.text('EXPORT'), findsNothing);
    expect(find.text('IMPORT'), findsNothing);
    expect(find.text('DIAGNOSTICS'), findsNothing);
    expect(find.text('STORAGE'), findsOneWidget);
    expect(find.text('Database Size'), findsOneWidget);
    expect(find.text('Last Backup'), findsOneWidget);
    expect(find.text('Storage Usage'), findsOneWidget);
    expect(find.text('DATA HEALTH'), findsOneWidget);
    await tester.pump();
    expect(find.text('Integrity'), findsOneWidget);
    expect(find.text('READABLE'), findsOneWidget);
    expect(find.text('Recovery Status'), findsOneWidget);
    expect(find.text('NO RECOVERY REQUIRED'), findsOneWidget);
    expect(find.text('Health Status'), findsOneWidget);
    expect(find.text('HEALTHY'), findsOneWidget);

    await tester.tap(find.text('OPEN OPERATION SYNC'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSyncPage), findsOneWidget);
  });

  testWidgets('INITIALIZE requires exact confirmation and resets app data', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    database.seed(IndexedDbStoreNames.statusRecords, 'status-1', {
      'id': 'status-1',
      'value': 'recorded',
    });
    final service = AppDataInitializationService(
      database,
      clock: () => DateTime.utc(2026, 8, 2, 12),
    );
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SystemPage(
          initializationService: service,
          dataHealthLoader: () async => const SystemDataHealthSnapshot(
            integrity: 'READABLE',
            recoveryStatus: 'NO RECOVERY REQUIRED',
            healthStatus: 'HEALTHY',
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('initialize-app-data')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('initialize-app-data')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Backupを作成してください'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirm-initialize-app-data')),
    );
    expect(confirm.onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('initialize-confirmation-input')),
      'initialize',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-initialize-app-data')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('initialize-confirmation-input')),
      'INITIALIZE',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-initialize-app-data')));
    await tester.pumpAndSettle();

    expect(find.text('APP DATA INITIALIZED'), findsOneWidget);
    expect(await database.findAll(IndexedDbStoreNames.statusRecords), isEmpty);
    expect(
      database.rawRecord(IndexedDbStoreNames.operationState, 'current'),
      isNotNull,
    );
  });

  testWidgets('OPERATION SYNC exposes the formal transfer surface', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OperationSyncPage()));

    expect(
      find.text('Transfer data between devices with a verified package.'),
      findsOneWidget,
    );
    for (final module in OperationSyncPage.modules) {
      expect(find.text(module), findsOneWidget);
    }
    expect(find.text('SELECT TRANSFER PACKAGE'), findsWidgets);
    expect(find.text('VALIDATION'), findsOneWidget);
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('APPLY'), findsOneWidget);
    expect(find.text('VERIFY'), findsOneWidget);
    expect(find.text('COMPLETE'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('export-transfer-package')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('EXPORT TRANSFER PACKAGE'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('OPERATION SYNC HISTORY'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('OPERATION SYNC HISTORY'), findsOneWidget);
  });

  for (final pageCase in const <({String name, Widget page})>[
    (name: 'PROFILE', page: ProfilePage()),
    (name: 'ABOUT', page: AboutPage()),
    (name: 'OPERATION SYNC', page: OperationSyncPage()),
  ]) {
    for (final width in [320.0, 390.0, 900.0, 1280.0]) {
      testWidgets('${pageCase.name} is overflow-free at ${width.toInt()}px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final theme in [ThemeData.light(), ThemeData.dark()]) {
          await tester.pumpWidget(
            MaterialApp(theme: theme, home: pageCase.page),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('SYSTEM is overflow-free at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: SystemPage(
              dataHealthLoader: () async => const SystemDataHealthSnapshot(
                integrity: 'READABLE',
                recoveryStatus: 'NO RECOVERY REQUIRED',
                healthStatus: 'HEALTHY',
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
