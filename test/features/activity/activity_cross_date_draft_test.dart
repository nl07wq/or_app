import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/repositories/daily_log_confirmation_repository.dart';
import 'package:or_app/core/services/app_clock.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/activity/activity_page.dart';
import 'package:or_app/features/activity/models/activity_draft.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  final today = DateTime(2026, 7, 28);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppClock.setSystemNowForTesting(() => today);
    database = FakeIndexedDbDatabase();
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(() {
    AppClock.resetForTesting();
    AppRepositoryRegistry.resetForTesting();
  });

  testWidgets('no past Draft shows no recovery notice', (tester) async {
    await _saveDraft('2026-07-28', steps: '2800');

    await _pumpPage(tester);

    expect(find.text('前日の未確定データがあります'), findsNothing);
    expect(find.text('未確定のActivity Draftがあります'), findsNothing);
  });

  testWidgets('past Drafts are listed newest first without the current Draft', (
    tester,
  ) async {
    await _saveDraft('2026-07-24', steps: '2400');
    await _saveDraft('2026-07-26', steps: '2600');
    await _saveDraft('2026-07-25', steps: '2500');
    await _saveDraft('2026-07-28', steps: '2800');

    await _pumpPage(tester);

    expect(find.text('未確定のActivity Draftがあります'), findsOneWidget);
    expect(find.text('未確定のActivity Draftが3件あります'), findsOneWidget);
    final dates = [
      tester.getTopLeft(find.text('2026-07-26')).dy,
      tester.getTopLeft(find.text('2026-07-25')).dy,
      tester.getTopLeft(find.text('2026-07-24')).dy,
    ];
    expect(dates[0], lessThan(dates[1]));
    expect(dates[1], lessThan(dates[2]));
    expect(find.text('2026-07-28'), findsNothing);
  });

  testWidgets('resume opens the target date and preserves every other Draft', (
    tester,
  ) async {
    await _saveDraft('2026-07-26', steps: '4321', carryOver: '123');
    await _saveDraft('2026-07-28', steps: '9999');

    await _pumpPage(tester);
    await tester.tap(find.bySemanticsLabel('2026-07-26の入力を再開'));
    await tester.pumpAndSettle();

    expect(find.text('PAST ACTIVITY'), findsOneWidget);
    expect(find.text('2026-07-26 のActivity入力'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      '4321',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
      '123',
    );
    expect(find.text('SAVE ACTIVITY'), findsOneWidget);
    expect(find.text('この日のActivity記録を確定'), findsOneWidget);
    expect(
      await AppRepositoryRegistry.container.activityDrafts.findByDate(today),
      isNotNull,
    );
  });

  testWidgets(
    'past finalization uses its own date and preserves other Drafts',
    (tester) async {
      await _saveDraft('2026-07-26', steps: '2600');
      await _saveDraft('2026-07-25', steps: '2500');
      await _saveDraft('2026-07-28', steps: '2800');

      await _pumpPage(tester);
      await tester.tap(find.bySemanticsLabel('2026-07-26のActivity記録を確定'));
      await tester.pumpAndSettle();

      expect(
        (await AppRepositoryRegistry.container.activity.findByDate(
          DateTime(2026, 7, 26),
        ))?.measuredSteps,
        2600,
      );
      expect(
        await AppRepositoryRegistry.container.activity.findByDate(today),
        isNull,
      );
      expect(
        await AppRepositoryRegistry.container.activityDrafts.findByDate(
          DateTime(2026, 7, 26),
        ),
        isNull,
      );
      expect(
        await AppRepositoryRegistry.container.activityDrafts.findByDate(
          DateTime(2026, 7, 25),
        ),
        isNotNull,
      );
      expect(
        await AppRepositoryRegistry.container.activityDrafts.findByDate(today),
        isNotNull,
      );
    },
  );

  testWidgets('incomplete past Event is rejected with a dated Japanese error', (
    tester,
  ) async {
    await _saveDraft(
      '2026-07-26',
      steps: '2600',
      events: [
        ActivityDraftDigestiveEvent(
          id: 'digestive:2026-07-26:1',
          sequence: 1,
          amount: 1,
          recordedAt: DateTime(2026, 7, 26, 8),
        ),
      ],
    );

    await _pumpPage(tester);
    await tester.tap(find.bySemanticsLabel('2026-07-26のActivity記録を確定'));
    await tester.pumpAndSettle();

    expect(find.text('2026-07-26の排便イベント1の形状を入力してください'), findsOneWidget);
    expect(
      await AppRepositoryRegistry.container.activity.findByDate(
        DateTime(2026, 7, 26),
      ),
      isNull,
    );
    expect(
      await AppRepositoryRegistry.container.activityDrafts.findByDate(
        DateTime(2026, 7, 26),
      ),
      isNotNull,
    );
  });

  testWidgets('discard confirms and deletes only the selected Draft', (
    tester,
  ) async {
    await _saveDraft('2026-07-26', steps: '2600');
    await _saveDraft('2026-07-25', steps: '2500');
    await _saveDraft('2026-07-28', steps: '2800');

    await _pumpPage(tester);
    await tester.tap(find.bySemanticsLabel('2026-07-26の未確定データを破棄'));
    await tester.pumpAndSettle();

    expect(find.text('2026-07-26の未確定Activityデータを破棄しますか？'), findsOneWidget);
    expect(find.text('この操作は元に戻せません'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '破棄').last);
    await tester.pumpAndSettle();

    expect(
      await AppRepositoryRegistry.container.activityDrafts.findByDate(
        DateTime(2026, 7, 26),
      ),
      isNull,
    );
    expect(
      await AppRepositoryRegistry.container.activityDrafts.findByDate(
        DateTime(2026, 7, 25),
      ),
      isNotNull,
    );
    expect(
      await AppRepositoryRegistry.container.activityDrafts.findByDate(today),
      isNotNull,
    );
  });

  testWidgets('later suppresses redisplay only for the current page instance', (
    tester,
  ) async {
    await _saveDraft('2026-07-26', steps: '2600');

    await _pumpPage(tester);
    expect(find.text('前日入力を再開'), findsOneWidget);
    expect(find.text('前日分を確定'), findsOneWidget);
    await tester.tap(find.text('あとで'));
    await tester.pumpAndSettle();
    expect(find.text('前日の未確定データがあります'), findsNothing);
    await tester.pump();
    expect(find.text('前日の未確定データがあります'), findsNothing);

    await tester.pumpWidget(MaterialApp(home: ActivityPage(key: UniqueKey())));
    await tester.pumpAndSettle();
    expect(find.text('前日の未確定データがあります'), findsOneWidget);
  });

  testWidgets(
    'single past Draft finalization closes the notice and reports success',
    (tester) async {
      await _saveDraft('2026-07-26', steps: '2600');

      await _pumpPage(tester);
      await tester.tap(find.bySemanticsLabel('2026-07-26のActivity記録を確定'));
      await tester.pumpAndSettle();

      expect(find.text('前日の未確定データがあります'), findsNothing);
      expect(find.text('2026-07-26のActivity記録を確定しました'), findsOneWidget);
      expect(
        await AppRepositoryRegistry.container.activity.findByDate(
          DateTime(2026, 7, 26),
        ),
        isNotNull,
      );
    },
  );

  testWidgets(
    'formal conflict wins and never deletes or overwrites its Draft',
    (tester) async {
      final date = DateTime(2026, 7, 26);
      await _saveDraft('2026-07-26', steps: '2600');
      await AppRepositoryRegistry.container.activity.save(
        ActivityData(date: date, measuredSteps: 7777),
      );

      await _pumpPage(tester);

      expect(find.text('正式Activity Recordがあります'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('2026-07-26のActivity記録を確定'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Draftから上書きできません'), findsOneWidget);
      expect(
        (await AppRepositoryRegistry.container.activity.findByDate(
          date,
        ))?.measuredSteps,
        7777,
      );
      expect(
        await AppRepositoryRegistry.container.activityDrafts.findByDate(date),
        isNotNull,
      );

      await tester.tap(find.text('正式Recordを表示'));
      await tester.pumpAndSettle();
      expect(find.textContaining('正式Recordを優先して表示しています'), findsOneWidget);
      expect(find.text('SAVE ACTIVITY'), findsOneWidget);
    },
  );

  testWidgets('confirmed Daily Log rejects finalization and keeps the Draft', (
    tester,
  ) async {
    final date = DateTime(2026, 7, 26);
    await _saveDraft('2026-07-26', steps: '2600');
    await DailyLogConfirmationRepository.save(
      DailyLogConfirmation(
        date: date,
        confirmedAt: date.add(const Duration(hours: 23)),
        morning: null,
        food: null,
        activity: null,
        training: null,
      ),
    );

    await _pumpPage(tester);

    expect(find.textContaining('Daily Log確定済みです'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('2026-07-26のActivity記録を確定'));
    await tester.pumpAndSettle();
    expect(find.textContaining('訂正処理を開始してください'), findsWidgets);
    expect(
      await AppRepositoryRegistry.container.activityDrafts.findByDate(date),
      isNotNull,
    );

    await tester.tap(find.bySemanticsLabel('2026-07-26の入力を再開'));
    await tester.pumpAndSettle();
    expect(find.textContaining('この日のログは確定済みです'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('multiple Draft recovery remains overflow-free at 320 pixels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _saveDraft('2026-07-26', steps: '2600');
    await _saveDraft('2026-07-25', steps: '2500');
    await _saveDraft('2026-07-24', steps: '2400');

    await _pumpPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('未確定のActivity Draftがあります'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: ActivityPage()));
  await tester.pumpAndSettle();
}

Future<void> _saveDraft(
  String localDate, {
  required String steps,
  String carryOver = '0',
  List<ActivityDraftDigestiveEvent> events = const [],
}) {
  final timestamp = DateTime.utc(2026, 7, 20, 12);
  return AppRepositoryRegistry.container.activityDrafts.save(
    ActivityDraft(
      localDate: localDate,
      measuredStepsInput: steps,
      carryOverInput: carryOver,
      digestiveEvents: events,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  );
}
