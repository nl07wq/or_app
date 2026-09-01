import 'dart:async';
import 'dart:convert';

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
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/operation_date/services/japanese_holiday_reference_service.dart';
import 'package:or_app/features/system/pages/about_page.dart';
import 'package:or_app/features/system/pages/device_transfer_page.dart';
import 'package:or_app/features/system/pages/operation_sync_page.dart';
import 'package:or_app/features/system/pages/profile_page.dart';
import 'package:or_app/features/system/pages/system_page.dart';
import 'package:or_app/features/system/services/app_data_initialization_service.dart';
import 'package:or_app/features/system/services/app_metadata.dart';
import 'package:or_app/features/system/services/storage_status_gateway.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRepositoryRegistry.install(
      AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase()),
    );
    appInitializationController.markReady();
    dailyLogConfirmationNotifier.value = DailyLogConfirmationStatus.unconfirmed(
      DateTime(2026, 8, 2),
    );
    morningFactNotifier.value = null;
    foodSummaryNotifier.value = null;
    trainingSummaryNotifier.value = null;
    activitySummaryNotifier.value = const ActivitySummary.empty();
  });

  testWidgets('SYSTEM updates HOLIDAY DATA and shows reference metadata', (
    tester,
  ) async {
    final service = JapaneseHolidayReferenceService(
      assetLoader: () async => jsonEncode({
        'schemaVersion': 1,
        'source': 'cabinet_office_japan',
        'dataUpdatedAt': '2026-08-16T00:00:00Z',
        'coverageFrom': '2026-01-01',
        'coverageTo': '2027-12-31',
        'holidays': ['2026-08-11'],
      }),
      clock: () => DateTime.utc(2026, 8, 16, 12, 30),
    );
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: SystemPage(
          holidayService: service,
          storageGateway: const _FakeStorageGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('HOLIDAY DATA'), 300);

    expect(find.text('HOLIDAY DATA'), findsOneWidget);
    expect(find.text('SOURCE'), findsOneWidget);
    expect(find.text('CABINET OFFICE JAPAN'), findsOneWidget);
    expect(find.text('DATA UPDATED'), findsOneWidget);
    expect(find.text('LOCAL UPDATED'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.byKey(const ValueKey('update-holiday-data')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  tearDown(AppRepositoryRegistry.resetForTesting);

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

  testWidgets('PROFILE edits data while ABOUT owns version information', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();
    expect(find.text('User Name'), findsOneWidget);
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Nationality'), findsOneWidget);
    expect(find.text('Version'), findsNothing);
    expect(find.text('Operation Reboot Version'), findsNothing);
    expect(find.byKey(const ValueKey('save-profile')), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    expect(find.text('App Version'), findsOneWidget);
    expect(find.text('Operation Reboot Version'), findsOneWidget);
    expect(find.text('Database Version'), findsOneWidget);
    expect(find.text('Backup Schema Version'), findsOneWidget);
    expect(find.text('Build Number'), findsOneWidget);
    expect(find.text('Last Updated'), findsOneWidget);
    expect(find.text('Release Commit'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Theme'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'SYSTEM shows storage and data health and opens DEVICE TRANSFER',
    (tester) async {
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
            storageGateway: const _FakeStorageGateway(),
          ),
          routes: {AppRoutes.deviceTransfer: (_) => const DeviceTransferPage()},
        ),
      );

      expect(find.text('DEVICE TRANSFER'), findsWidgets);
      expect(find.text('EXPORT'), findsNothing);
      expect(find.text('IMPORT'), findsNothing);
      expect(find.text('DIAGNOSTICS'), findsNothing);
      expect(find.text('機種変更などのデータ転送や、長期保存データの一括取り込みを行います。'), findsOneWidget);
      expect(
        find.textContaining('Transfer data between devices'),
        findsNothing,
      );
      expect(find.text('STORAGE'), findsOneWidget);
      await tester.pump();
      expect(find.text('保存方式'), findsOneWidget);
      expect(find.text('IndexedDB'), findsOneWidget);
      expect(find.text('推定使用量'), findsOneWidget);
      expect(find.text('1.0 KB'), findsOneWidget);
      expect(find.text('推定上限容量'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(find.text('保存状態'), findsOneWidget);
      expect(find.text('永続保存'), findsOneWidget);
      for (final oldLabel in [
        'Storage Type',
        'Estimated Usage',
        'Estimated Quota',
        'Persistence',
      ]) {
        expect(find.text(oldLabel), findsNothing);
      }
      final usage = find.ancestor(
        of: find.text('推定使用量'),
        matching: find.byType(ListTile),
      );
      final quota = find.ancestor(
        of: find.text('推定上限容量'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: usage, matching: find.text('1.0 KB')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: quota, matching: find.text('2.0 KB')),
        findsOneWidget,
      );
      expect(find.textContaining('空き容量'), findsNothing);
      expect(find.text('DATA HEALTH'), findsOneWidget);
      await tester.pump();
      expect(find.text('データ整合性'), findsOneWidget);
      expect(find.text('読み取り可能'), findsOneWidget);
      expect(find.text('復旧状態'), findsOneWidget);
      expect(find.text('復旧は必要ありません'), findsOneWidget);
      expect(find.text('システム状態'), findsOneWidget);
      expect(find.text('正常'), findsOneWidget);
      for (final internalValue in [
        'Integrity',
        'READABLE',
        'Recovery Status',
        'NO RECOVERY REQUIRED',
        'Health Status',
        'HEALTHY',
      ]) {
        expect(find.text(internalValue), findsNothing);
      }

      await tester.tap(find.text('OPEN DEVICE TRANSFER'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceTransferPage), findsOneWidget);
    },
  );

  testWidgets('SYSTEM localizes every Data Health state and unknown values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const cases = [
      (
        snapshot: SystemDataHealthSnapshot(
          integrity: 'READABLE',
          recoveryStatus: 'NO RECOVERY REQUIRED',
          healthStatus: 'HEALTHY',
        ),
        values: ['読み取り可能', '復旧は必要ありません', '正常'],
      ),
      (
        snapshot: SystemDataHealthSnapshot(
          integrity: 'CHECK REQUIRED',
          recoveryStatus: 'RECOVERY REQUIRED',
          healthStatus: 'ATTENTION',
        ),
        values: ['確認が必要です', '復旧が必要です', '確認が必要です'],
      ),
      (
        snapshot: SystemDataHealthSnapshot(
          integrity: 'UNAVAILABLE',
          recoveryStatus: 'UNKNOWN',
          healthStatus: 'CHECK REQUIRED',
        ),
        values: ['利用できません', '確認できません', '確認が必要です'],
      ),
      (
        snapshot: SystemDataHealthSnapshot(
          integrity: 'UNEXPECTED',
          recoveryStatus: 'UNEXPECTED',
          healthStatus: 'UNEXPECTED',
        ),
        values: ['確認できません', '確認できません', '確認できません'],
      ),
    ];
    for (final testCase in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: SystemPage(
            key: ValueKey(testCase.snapshot),
            dataHealthLoader: () async => testCase.snapshot,
            storageGateway: const _FakeStorageGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final value in testCase.values.toSet()) {
        expect(find.text(value), findsWidgets);
      }
      expect(find.text('UNEXPECTED'), findsNothing);
    }

    final pending = Completer<SystemDataHealthSnapshot>();
    await tester.pumpWidget(
      MaterialApp(
        home: SystemPage(
          key: const ValueKey('pending-data-health'),
          dataHealthLoader: () => pending.future,
          storageGateway: const _FakeStorageGateway(),
        ),
      ),
    );
    expect(find.text('確認中です'), findsNWidgets(3));
    pending.complete(cases.first.snapshot);
    await tester.pump();
  });

  testWidgets('ABOUT shows each formal metadata field exactly once', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    for (final label in [
      'App Version',
      'Operation Reboot Version',
      'Database Version',
      'Backup Schema Version',
      'Build Number',
      'Last Updated',
      'Release Commit',
      'Copyright',
      'License',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('5.2'), findsOneWidget);
    expect(find.text(AppMetadata.databaseVersion), findsOneWidget);
    expect(find.text(AppMetadata.backupSchemaVersion), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('NOT AVAILABLE'), findsNWidgets(2));
    expect(find.text('未設定'), findsNWidgets(2));
    expect(find.text('Version'), findsNothing);
  });

  testWidgets('ABOUT displays supplied release metadata', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutPage(
          releaseMetadata: ReleaseMetadata(
            lastUpdated: '2026-09-02 12:34 JST',
            releaseCommit: 'abcdef1',
          ),
        ),
      ),
    );

    expect(find.text('2026-09-02 12:34 JST'), findsOneWidget);
    expect(find.text('abcdef1'), findsOneWidget);
  });

  testWidgets('ABOUT release metadata remains readable at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutPage(
          releaseMetadata: ReleaseMetadata(
            lastUpdated: '2026-09-02 12:34 JST',
            releaseCommit: 'abcdef1',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Last Updated'), findsOneWidget);
    expect(find.text('Release Commit'), findsOneWidget);
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
          storageGateway: const _FakeStorageGateway(),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('initialize-app-data')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('initialize-app-data')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('initialize-app-data')));
    await tester.pumpAndSettle();

    expect(find.textContaining('バックアップを作成してください'), findsOneWidget);
    final input = find.byKey(const ValueKey('initialize-confirmation-input'));
    final confirm = find.byKey(const ValueKey('confirm-initialize-app-data'));
    FilledButton confirmButton() => tester.widget<FilledButton>(confirm);
    Future<void> enterConfirmation(String value) async {
      await tester.enterText(input, value);
      await tester.pump();
    }

    expect(confirmButton().onPressed, isNull);
    expect(database.transactionCount, 0);
    for (final invalid in [
      '',
      'INIT',
      'INITIALIZ',
      'initialize',
      'InitialIze',
      'INTILIZE',
      ' INITIALIZE',
      'INITIALIZE ',
      'INITIALIZE\n',
      'ＩＮＩＴＩＡＬＩＺＥ',
    ]) {
      await enterConfirmation(invalid);
      expect(confirmButton().onPressed, isNull, reason: invalid);
    }

    await enterConfirmation('INITIALIZE');
    expect(confirmButton().onPressed, isNotNull);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'INITIALIZE',
        selection: TextSelection.collapsed(offset: 10),
        composing: TextRange(start: 0, end: 10),
      ),
    );
    await tester.pump();
    expect(confirmButton().onPressed, isNull);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'INITIALIZE',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );
    await tester.pump();
    expect(confirmButton().onPressed, isNotNull);
    await enterConfirmation('INITIALIZ');
    expect(confirmButton().onPressed, isNull);
    await enterConfirmation('INITIALIZE');
    expect(confirmButton().onPressed, isNotNull);
    await enterConfirmation('INITIALIZE ');
    expect(confirmButton().onPressed, isNull);
    expect(database.transactionCount, 0);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('initialize-app-data')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('initialize-app-data')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(confirmButton().onPressed, isNull);
    await enterConfirmation('INITIALIZE');
    expect(confirmButton().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('confirm-initialize-app-data')));
    await tester.pumpAndSettle();

    expect(database.transactionCount, 1);
    expect(find.text('アプリデータを初期化しました'), findsOneWidget);
    expect(await database.findAll(IndexedDbStoreNames.statusRecords), isEmpty);
    expect(
      database.rawRecord(IndexedDbStoreNames.operationState, 'current'),
      isNotNull,
    );
  });

  testWidgets('INITIALIZE prevents duplicate execution and reports failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _ControlledInitializationService();
    await tester.pumpWidget(
      MaterialApp(
        home: SystemPage(
          initializationService: service,
          dataHealthLoader: () async => const SystemDataHealthSnapshot(
            integrity: 'READABLE',
            recoveryStatus: 'NO RECOVERY REQUIRED',
            healthStatus: 'HEALTHY',
          ),
          storageGateway: const _FakeStorageGateway(),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('initialize-app-data')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('initialize-app-data')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('initialize-app-data')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('initialize-confirmation-input')),
      'INITIALIZE',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-initialize-app-data')));
    await tester.pump();
    await tester.pump();

    expect(service.callCount, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('initialize-app-data')),
          )
          .onPressed,
      isNull,
    );
    service.completeFailure();
    await tester.pumpAndSettle();
    expect(service.callCount, 1);
    expect(find.text('アプリデータを初期化できませんでした'), findsOneWidget);
    expect(find.text('アプリデータを初期化しました'), findsNothing);
  });

  testWidgets('OPERATION SYNC exposes the formal transfer surface', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OperationSyncPage()));

    expect(
      find.text('Transfer data between devices with a verified package.'),
      findsOneWidget,
    );
    expect(find.text('AVAILABLE'), findsNothing);
    expect(find.text('ARCHIVE'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('export-transfer-package')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('EXPORT TRANSFER PACKAGE'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('OPERATION SYNC RECORD'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('OPERATION SYNC RECORD'), findsOneWidget);
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
      tester.view.physicalSize = Size(width, 700);
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
              storageGateway: const _FakeStorageGateway(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('initialize-app-data')),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('initialize-app-data')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('initialize-app-data')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('initialize-confirmation-input')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('confirm-initialize-app-data')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('キャンセル'));
        await tester.pumpAndSettle();
      }
    });
  }
}

class _FakeStorageGateway implements StorageStatusGateway {
  const _FakeStorageGateway();

  @override
  Future<StorageStatusSnapshot> load() async => const StorageStatusSnapshot(
    estimateState: StorageEstimateState.available,
    usageBytes: 1024,
    quotaBytes: 2048,
    persistence: StoragePersistence.persistent,
  );
}

class _ControlledInitializationService extends AppDataInitializationService {
  _ControlledInitializationService() : super(FakeIndexedDbDatabase());

  final _completion = Completer<AppDataInitializationResult>();
  int callCount = 0;

  @override
  Future<AppDataInitializationResult> initialize() {
    callCount++;
    return _completion.future;
  }

  void completeFailure() {
    _completion.completeError(StateError('Injected initialization failure.'));
  }
}
