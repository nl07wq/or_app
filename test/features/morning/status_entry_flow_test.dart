import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/core/widgets/operation_card.dart';
import 'package:or_app/features/command_center/pages/command_center_page.dart';
import 'package:or_app/features/morning/morning_fact_page.dart';
import 'package:or_app/features/morning/morning_page.dart';
import 'package:or_app/features/morning/services/morning_submit_service.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/report_sync/pages/report_sync_exchange_page.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;

  setUp(() {
    database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-08-15');
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('STATUS ENTRY is enabled only before the current-day save', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MorningPage(key: ValueKey('registered-status-page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MANUAL ENTRY'), findsNothing);
    expect(find.text('STATUS ENTRY'), findsWidgets);
    expect(_entryButton(tester).onPressed, isNotNull);
    expect(find.textContaining('本日のSTATUSは登録済みです。'), findsNothing);

    await AppRepositoryRegistry.container.status.save(_status('2026-08-15'));
    await tester.pumpWidget(const MaterialApp(home: MorningPage()));
    await tester.pumpAndSettle();

    expect(_entryButton(tester).onPressed, isNull);
    expect(find.textContaining('本日のSTATUSは登録済みです。'), findsOneWidget);
    expect(find.textContaining('編集する場合はRECORDから行ってください。'), findsOneWidget);
  });

  test(
    'same-day second new STATUS save is rejected without replacement',
    () async {
      final original = _status('2026-08-15');
      await AppRepositoryRegistry.container.status.save(original);

      final error = await MorningSubmitService.submit(
        workType: WorkType.holiday,
        sleepType: SleepType.sleep,
        weightText: '75',
        bodyFatText: '25',
        sleepText: '8:00',
        sleepScoreText: '90',
        footPainText: '3',
        workStart: '',
        workEnd: '',
        workBreak: '',
        memo: 'second',
        operationLocalDate: '2026-08-15',
      );

      expect(error, '本日のSTATUSは登録済みです。編集する場合はRECORDから行ってください。');
      final readBack = await AppRepositoryRegistry.container.status
          .findByLocalDate('2026-08-15');
      expect(readBack!.weight, original.weight);
      expect(readBack.memo, original.memo);
    },
  );

  testWidgets(
    'current STATUS delete reenables entry while historical delete does not',
    (tester) async {
      await AppRepositoryRegistry.container.status.save(_status('2026-08-15'));
      await AppRepositoryRegistry.container.status.save(_status('2026-08-14'));
      await tester.pumpWidget(const MaterialApp(home: MorningPage()));
      await tester.pumpAndSettle();
      expect(_entryButton(tester).onPressed, isNull);

      await tester.tap(find.text('RECORD').last);
      await tester.pumpAndSettle();
      await _deleteStatus(tester, '2026-08-14');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_entryButton(tester).onPressed, isNull);

      await tester.tap(find.text('RECORD').last);
      await tester.pumpAndSettle();
      await _deleteStatus(tester, '2026-08-15');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_entryButton(tester).onPressed, isNotNull);

      final error = await MorningSubmitService.submit(
        workType: WorkType.holiday,
        sleepType: SleepType.sleep,
        weightText: '75',
        bodyFatText: '25',
        sleepText: '8:00',
        sleepScoreText: '90',
        footPainText: '3',
        workStart: '',
        workEnd: '',
        workBreak: '',
        memo: 'recreated',
        operationLocalDate: '2026-08-15',
      );
      expect(error, isNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: MorningPage(key: ValueKey('reloaded-status-page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(_entryButton(tester).onPressed, isNull);
    },
  );

  testWidgets(
    'first STATUS save offers DAILY BRIEF and NO follows normal flow',
    (tester) async {
      await _pumpEntry(tester);
      await tester.ensureVisible(find.text('SAVE STATUS'));
      await tester.tap(find.text('SAVE STATUS'));
      await tester.pumpAndSettle();

      expect(find.text('DAILY BRIEFを作成できます。\n今すぐ作成しますか？'), findsOneWidget);
      expect(
        await AppRepositoryRegistry.container.status.findByLocalDate(
          '2026-08-15',
        ),
        isNotNull,
      );

      await tester.tap(find.text('NO'));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD TEST'), findsOneWidget);
    },
  );

  testWidgets(
    'first STATUS save YES opens the existing DAILY BRIEF create page',
    (tester) async {
      await _pumpEntry(tester);
      await tester.ensureVisible(find.text('SAVE STATUS'));
      await tester.tap(find.text('SAVE STATUS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('YES'));
      await tester.pumpAndSettle();

      expect(find.byType(ReportSyncExchangePage), findsOneWidget);
    },
  );

  testWidgets(
    'STATUS brief success returns to latest brief top in COMMAND CENTER',
    (tester) async {
      await _pumpEntry(
        tester,
        dailyBriefCreationPageBuilder: (onApplied) => Scaffold(
          appBar: AppBar(title: const Text('DAILY BRIEF CREATE TEST')),
          body: TextButton(
            onPressed: () {
              onApplied();
              Navigator.pop(tester.element(find.text('COMPLETE BRIEF')));
            },
            child: const Text('COMPLETE BRIEF'),
          ),
        ),
      );
      await tester.ensureVisible(find.text('SAVE STATUS'));
      await tester.tap(find.text('SAVE STATUS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('YES'));
      await tester.pumpAndSettle();
      await AppRepositoryRegistry.container.morningBriefs.create(
        _morningBrief('2026-08-15'),
      );
      await tester.tap(find.text('COMPLETE BRIEF'));
      await tester.pumpAndSettle();

      expect(find.byType(CommandCenterPage), findsOneWidget);
      expect(find.text('COMMAND CENTER'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('morning-brief-content')),
        findsOneWidget,
      );
      expect(find.textContaining('LATEST BRIEF'), findsOneWidget);
      expect(find.text('DASHBOARD TEST'), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('morning-brief-content')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.pixels, 0);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD TEST'), findsOneWidget);
    },
  );

  testWidgets('RECORD edit saves without the DAILY BRIEF prompt', (
    tester,
  ) async {
    final status = _status('2026-08-15');
    await AppRepositoryRegistry.container.status.save(status);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MorningFactPage(data: status, returnAfterSave: true),
                ),
              ),
              child: const Text('OPEN EDIT'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN EDIT'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('UPDATE STATUS'));
    await tester.tap(find.text('UPDATE STATUS'));
    await tester.pumpAndSettle();

    expect(find.textContaining('DAILY BRIEFを作成できます。'), findsNothing);
    expect(
      await AppRepositoryRegistry.container.status.findByLocalDate(
        '2026-08-15',
      ),
      isNotNull,
    );
  });
}

OperationButton _entryButton(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('status-entry-button')));

Future<void> _pumpEntry(
  WidgetTester tester, {
  DailyBriefCreationPageBuilder? dailyBriefCreationPageBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      routes: {
        AppRoutes.dashboard: (context) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('DASHBOARD TEST'),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/status-entry'),
                  child: const Text('OPEN STATUS TEST'),
                ),
              ],
            ),
          ),
        ),
        '/status-entry': (_) => MorningFactPage(
          dailyBriefCreationPageBuilder: dailyBriefCreationPageBuilder,
        ),
      },
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN STATUS TEST'));
  await tester.pumpAndSettle();
}

Future<void> _deleteStatus(WidgetTester tester, String localDate) async {
  final card = find.ancestor(
    of: find.text(localDate),
    matching: find.byType(OperationCard),
  );
  await tester.tap(
    find.descendant(of: card, matching: find.byTooltip('Delete')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('削除'));
  await tester.pumpAndSettle();
}

MorningData _status(String localDate) => MorningData(
  date: '${localDate}T00:00:00.000',
  weight: 70,
  bodyFat: 20,
  sleepHours: 7,
  sleepScore: 80,
  footPain: 2,
  workType: WorkType.holiday,
  workStart: '',
  workEnd: '',
  workBreak: '',
  workHours: 0,
  memo: '',
);

MorningBriefRecord _morningBrief(String localDate) {
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final timestamp = DateTime.utc(2026, 8, 15, 9);
  return MorningBriefRecord(
    localDate: localDate,
    requestId: 'status-origin-request',
    requestDigest: digest,
    responseDigest: digest,
    generatedAt: timestamp,
    importedAt: timestamp,
    situationAnalysis: 'LATEST BRIEF',
    operationStatus: MorningBriefOperationStatus.green,
    commanderIntent: 'Latest intent',
    argoComment: 'Latest comment',
    strategicResourceDecision: 'Latest resources',
    actions: const [],
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
