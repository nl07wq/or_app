import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/models/daily_log_confirmation_status.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/services/daily_log_confirmation_state.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/system/pages/operation_sync_page.dart';
import 'package:or_app/features/system/pages/profile_page.dart';
import 'package:or_app/features/system/pages/settings_page.dart';
import 'package:or_app/features/system/pages/system_page.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';

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
          AppRoutes.settings: (_) => const SettingsPage(),
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
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('SYSTEM'), findsOneWidget);

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('PROFILE and SETTINGS are display-only', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    expect(find.text('User Name'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Operation Reboot Version'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('SYSTEM keeps placeholders disabled and opens OPERATION SYNC', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: const SystemPage(),
        routes: {AppRoutes.operationSync: (_) => const OperationSyncPage()},
      ),
    );

    expect(find.text('OPERATION SYNC'), findsWidgets);
    expect(find.text('EXPORT'), findsOneWidget);
    expect(find.text('IMPORT'), findsOneWidget);
    expect(find.text('DIAGNOSTICS'), findsOneWidget);
    expect(find.text('COMING LATER'), findsNWidgets(3));

    final placeholders = tester.widgetList<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'COMING LATER'),
    );
    expect(placeholders.every((button) => button.onPressed == null), isTrue);

    await tester.tap(find.text('OPEN OPERATION SYNC'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSyncPage), findsOneWidget);
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
    expect(find.text('COMING LATER'), findsOneWidget);
  });

  for (final pageCase in const <({String name, Widget page})>[
    (name: 'PROFILE', page: ProfilePage()),
    (name: 'SETTINGS', page: SettingsPage()),
    (name: 'SYSTEM', page: SystemPage()),
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
}
