import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/models/digestive_event.dart';
import 'package:or_app/core/repositories/daily_log_confirmation_repository.dart';
import 'package:or_app/core/services/app_clock.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/activity/activity_entry_page.dart';
import 'package:or_app/features/activity/models/activity_draft.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late DateTime today;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    today = DateTime(2026, 7, 28);
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

  testWidgets('new entry starts with an expanded display-only Event', (
    tester,
  ) async {
    await _pumpEntry(tester);

    expect(find.text('DIGESTIVE 1'), findsOneWidget);
    expect(find.text('DIGESTIVE EVENT 1'), findsNothing);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Shape'), findsOneWidget);
    expect(find.text('Relief'), findsOneWidget);
    expect(find.text('No record'), findsNothing);
    expect(find.text('ADD DIGESTIVE'), findsOneWidget);
    expect(find.text('排便を追加'), findsNothing);
    expect(find.text('SAVE DRAFT'), findsOneWidget);
    expect(find.text('SAVE ACTIVITY'), findsOneWidget);
    expect(find.text('入力途中の内容を一時保存'), findsOneWidget);
    expect(find.text('本日のActivity記録を確定'), findsOneWidget);

    await tester.ensureVisible(find.text('SAVE DRAFT'));
    await tester.tap(find.text('SAVE DRAFT'));
    await tester.pumpAndSettle();
    final draft = await AppRepositoryRegistry.container.activityDrafts
        .findByDate(today);
    expect(draft?.digestiveEvents, isEmpty);
  });

  testWidgets('incomplete Event is saved and restored as a Draft', (
    tester,
  ) async {
    await _pumpEntry(tester);
    await tester.enterText(find.byType(TextField).at(0), '4321');
    await tester.enterText(find.byType(TextField).at(1), '120');
    // Event IDs include the clock's microsecond value. Select by visible chip.
    await _tapChip(tester, '普通', first: true);

    await tester.ensureVisible(find.text('SAVE DRAFT'));
    await tester.tap(find.text('SAVE DRAFT'));
    await tester.pumpAndSettle();

    final draft = await AppRepositoryRegistry.container.activityDrafts
        .findByDate(today);
    expect(draft?.measuredStepsInput, '4321');
    expect(draft?.carryOverInput, '120');
    expect(draft?.digestiveEvents.single.amount, 2);
    expect(draft?.digestiveEvents.single.shape, isNull);
    expect(draft?.digestiveEvents.single.relief, isNull);
    expect(
      await AppRepositoryRegistry.container.activity.findByDate(today),
      isNull,
    );

    await _pumpEntry(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      '4321',
    );
    expect(find.text('DIGESTIVE 1'), findsOneWidget);
    final selectedAmount = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '普通').first,
    );
    expect(selectedAmount.selected, isTrue);
  });

  testWidgets('multiple Events retain values and resequence after delete', (
    tester,
  ) async {
    await _pumpEntry(tester);
    await _addEvent(tester);
    expect(find.text('DIGESTIVE 1'), findsOneWidget);
    expect(find.text('DIGESTIVE 2'), findsOneWidget);

    final delete = find.byTooltip('排便イベント1を削除');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('この排便イベントを削除しますか？'), findsOneWidget);
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(find.text('DIGESTIVE 1'), findsOneWidget);
    expect(find.text('DIGESTIVE 2'), findsNothing);
  });

  testWidgets('finalize validates Amount, Shape, and Relief in order', (
    tester,
  ) async {
    await _pumpEntry(tester);
    await tester.enterText(find.byType(TextField).at(0), '5000');
    await _tapChip(tester, '少量');
    await tester.ensureVisible(find.text('SAVE ACTIVITY'));
    await tester.tap(find.text('SAVE ACTIVITY'));
    await tester.pump();
    expect(find.text('DIGESTIVE 1のShapeを入力してください'), findsOneWidget);

    await _tapChip(tester, '硬便');
    await tester.ensureVisible(find.text('SAVE ACTIVITY'));
    await tester.tap(find.text('SAVE ACTIVITY'));
    await tester.pump();
    expect(find.text('DIGESTIVE 1のReliefを入力してください'), findsOneWidget);
  });

  testWidgets('partial Event with only Shape selected requires Amount', (
    tester,
  ) async {
    await _pumpEntry(tester);
    await tester.enterText(find.byType(TextField).at(0), '5000');
    await _tapChip(tester, '硬便');

    final saveButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('SAVE ACTIVITY'),
        matching: find.byType(ElevatedButton),
      ),
    );
    saveButton.onPressed!();
    await tester.pump();

    expect(find.text('DIGESTIVE 1のAmountを入力してください'), findsOneWidget);
  });

  testWidgets('finalize saves Events, deletes Draft, and enters formal mode', (
    tester,
  ) async {
    await _pumpEntry(tester);
    await tester.enterText(find.byType(TextField).at(0), '5000');
    await _tapChip(tester, '多量');
    await _tapChip(tester, '普通便');
    await _tapChip(tester, 'スッキリ');
    await tester.ensureVisible(find.text('SAVE ACTIVITY'));
    await tester.tap(find.text('SAVE ACTIVITY'));
    await tester.pumpAndSettle();

    final saved = await AppRepositoryRegistry.container.activity.findByDate(
      today,
    );
    expect(saved?.digestiveEvents, hasLength(1));
    expect(saved?.digestiveEvents?.single.amount, 3);
    expect(saved?.digestiveEvents?.single.shape, 2);
    expect(saved?.digestiveEvents?.single.relief, 2);
    expect(
      await AppRepositoryRegistry.container.activityDrafts.findByDate(today),
      isNull,
    );
    expect(find.text('SAVE ACTIVITY'), findsOneWidget);
    expect(find.text('SAVE DRAFT'), findsNothing);
  });

  testWidgets('zero Events can be finalized without a legacy bowel value', (
    tester,
  ) async {
    await _pumpEntry(tester);
    await tester.enterText(find.byType(TextField).at(0), '2500');
    await tester.ensureVisible(find.text('SAVE ACTIVITY'));
    await tester.tap(find.text('SAVE ACTIVITY'));
    await tester.pumpAndSettle();

    final saved = await AppRepositoryRegistry.container.activity.findByDate(
      today,
    );
    expect(saved?.digestiveEvents, isEmpty);
    expect(saved?.bowelMovement.hasMovement, isNull);
  });

  testWidgets('formal Digestive Event records remain editable', (tester) async {
    final eventTime = DateTime(2026, 7, 28, 8);
    await AppRepositoryRegistry.container.activity.save(
      ActivityData(
        date: today,
        measuredSteps: 4000,
        digestiveEvents: [
          DigestiveEvent(
            id: 'digestive:2026-07-28:existing',
            sequence: 1,
            amount: 1,
            shape: 1,
            relief: 0,
            recordedAt: eventTime,
          ),
        ],
      ),
    );

    await _pumpEntry(tester);
    expect(find.text('SAVE ACTIVITY'), findsOneWidget);
    expect(find.text('SAVE DRAFT'), findsNothing);
    await _tapChip(tester, '多量');
    await tester.ensureVisible(find.text('SAVE ACTIVITY'));
    await tester.tap(find.text('SAVE ACTIVITY'));
    await tester.pumpAndSettle();

    final saved = await AppRepositoryRegistry.container.activity.findByDate(
      today,
    );
    expect(saved?.digestiveEvents?.single.amount, 3);
    expect(saved?.digestiveEvents?.single.id, 'digestive:2026-07-28:existing');
    expect(saved?.digestiveEvents?.single.recordedAt, eventTime);
  });

  testWidgets('Shape and Relief preserve the approved Material Symbols', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpEntry(tester);

    expect(find.byIcon(Icons.hexagon), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.water_drop), findsOneWidget);
    expect(find.byIcon(Icons.sentiment_dissatisfied), findsOneWidget);
    expect(find.byIcon(Icons.sentiment_neutral), findsOneWidget);
    expect(find.byIcon(Icons.sentiment_satisfied), findsOneWidget);
    expect(find.bySemanticsLabel('硬便'), findsOneWidget);
    expect(find.bySemanticsLabel('普通便'), findsOneWidget);
    expect(find.bySemanticsLabel('軟便'), findsOneWidget);
    expect(find.bySemanticsLabel('残便感'), findsOneWidget);
    expect(find.text('残便感あり'), findsNothing);
    semantics.dispose();
  });

  testWidgets('formal Record wins without deleting a same-date Draft', (
    tester,
  ) async {
    final draft = ActivityDraft(
      localDate: '2026-07-28',
      measuredStepsInput: '1111',
      carryOverInput: '0',
      createdAt: DateTime.utc(2026, 7, 27),
      updatedAt: DateTime.utc(2026, 7, 27),
    );
    await AppRepositoryRegistry.container.activityDrafts.save(draft);
    await AppRepositoryRegistry.container.activity.save(
      ActivityData(date: today, measuredSteps: 5555),
    );

    await _pumpEntry(tester);

    expect(find.textContaining('正式Recordを優先して表示しています'), findsOneWidget);
    expect(find.text('SAVE ACTIVITY'), findsOneWidget);
    expect(find.text('SAVE DRAFT'), findsNothing);
    expect(
      await AppRepositoryRegistry.container.activityDrafts.findByDate(today),
      isNotNull,
    );
  });

  testWidgets('confirmed Daily Log takes priority and disables entry', (
    tester,
  ) async {
    await DailyLogConfirmationRepository.save(
      DailyLogConfirmation(
        date: today,
        confirmedAt: today.add(const Duration(hours: 23)),
        morning: null,
        food: null,
        activity: null,
        training: null,
      ),
    );

    await _pumpEntry(tester);

    expect(find.textContaining('この日のログは確定済みです'), findsOneWidget);
    expect(find.text('SAVE DRAFT'), findsNothing);
    expect(find.text('SAVE ACTIVITY'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('corrupt Draft shows an explicit retryable load error', (
    tester,
  ) async {
    database.seed('activity_drafts', 'activity-draft:2026-07-28', {
      'id': 'activity-draft:2026-07-28',
    });

    await _pumpEntry(tester);

    expect(find.text('Activity入力データを読み込めませんでした'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('320 pixel layout has no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpEntry(tester);

    final exception = tester.takeException();
    expect(exception, isNull);
  });
}

Future<void> _pumpEntry(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: ActivityEntryPage()));
  await tester.pumpAndSettle();
}

Future<void> _addEvent(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('add-digestive-event'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> _tapChip(
  WidgetTester tester,
  String label, {
  bool first = false,
}) async {
  final matches = find.widgetWithText(ChoiceChip, label);
  final chip = first ? matches.first : matches;
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pump();
}
