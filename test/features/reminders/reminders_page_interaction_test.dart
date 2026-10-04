import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/dashboard/services/dashboard_plan_information_service.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/reminders/models/reminder_occurrence.dart';
import 'package:or_app/features/reminders/pages/reminders_page.dart';
import 'package:or_app/features/reminders/services/reminder_occurrence_service.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late AppRepositoryContainer container;

  setUp(() {
    container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    AppRepositoryRegistry.install(container);
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets(
    'circle completes while row tap edits and scroll stays distinct',
    (tester) async {
      final today = _dateKey(DateTime.now());
      await container.reminders.saveDefinition(
        _definition(id: 'single', startDate: today),
      );
      await _pumpPage(tester);

      final occurrenceId = 'single@$today';
      final row = find.byKey(ValueKey('reminder-row-$occurrenceId'));
      expect(row, findsOneWidget);
      expect(find.text('完了'), findsNothing);

      await tester.tap(find.text('Single'));
      await tester.pumpAndSettle();
      expect(find.text('REMINDERを編集'), findsOneWidget);
      Navigator.of(tester.element(find.text('REMINDERを編集'))).pop();
      await tester.pumpAndSettle();

      await tester.drag(row, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(find.text('REMINDERを削除'), findsNothing);

      await tester.drag(row, const Offset(-20, 0));
      await tester.pumpAndSettle();
      expect(find.text('REMINDERを削除'), findsNothing);

      await tester.longPress(row);
      await tester.pumpAndSettle();
      expect(find.text('REMINDERを編集'), findsOneWidget);
      Navigator.of(tester.element(find.text('REMINDERを編集'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('reminder-toggle-$occurrenceId')));
      await tester.pumpAndSettle();
      expect(find.text('REMINDERを編集'), findsNothing);
      expect(find.text('Single'), findsNothing);
      expect(
        (await container.reminders.findStates()).single.status,
        ReminderOccurrenceStatus.completed,
      );

      await tester.tap(find.text('COMPLETED'));
      await tester.pumpAndSettle();
      expect(find.text('Single'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('reminder-toggle-$occurrenceId')));
      await tester.pumpAndSettle();
      expect(await container.reminders.findStates(), isEmpty);
    },
  );

  testWidgets(
    'single swipe requires confirmation and removes definition and states',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final todayKey = _dateKey(today);
      final definition = _definition(id: 'single', startDate: todayKey);
      await container.reminders.saveDefinition(definition);
      await container.reminders.saveState(
        ReminderOccurrenceState(
          id: 'single@${_dateKey(today.subtract(const Duration(days: 1)))}',
          definitionId: 'single',
          localDate: _dateKey(today.subtract(const Duration(days: 1))),
          status: ReminderOccurrenceStatus.completed,
          updatedAt: DateTime.now().toUtc(),
          completedAt: DateTime.now().toUtc(),
        ),
      );
      await _pumpPage(tester);

      final dismissible = find.byKey(ValueKey('reminder-single@$todayKey'));
      await _swipeLeft(tester, dismissible);
      expect(find.text('REMINDERを編集'), findsNothing);
      expect(find.text('このREMINDERを削除しますか？'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await tester.pumpAndSettle();
      expect(await container.reminders.findDefinitions(), hasLength(1));

      await _swipeLeft(tester, dismissible);
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      expect(await container.reminders.findDefinitions(), isEmpty);
      expect(await container.reminders.findStates(), isEmpty);
      expect(find.text('Single'), findsNothing);

      final projection = await ReminderOccurrenceService(
        container.reminders,
      ).inRange(DateTimeRange(start: today, end: today));
      expect(projection, isEmpty);
      final dashboard = await DashboardPlanInformationService(
        container.schedules,
        reminders: container.reminders,
      ).loadFor(todayKey);
      expect(dashboard.entries, isEmpty);
    },
  );

  testWidgets('vertical drag scrolls without editing or deleting', (
    tester,
  ) async {
    final today = _dateKey(DateTime.now());
    for (var index = 0; index < 20; index++) {
      await container.reminders.saveDefinition(
        _definition(
          id: 'scroll-$index',
          title: 'Scroll $index',
          startDate: today,
        ),
      );
    }
    await _pumpPage(tester);
    final list = find.byType(ListView).first;
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final before = tester.state<ScrollableState>(scrollable).position.pixels;

    await tester.drag(find.text('Scroll 0'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(before),
    );
    expect(find.text('REMINDERを編集'), findsNothing);
    expect(find.text('このREMINDERを削除しますか？'), findsNothing);
  });

  testWidgets(
    'recurring once-delete persists SKIPPED and keeps the next occurrence',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final todayKey = _dateKey(today);
      await container.reminders.saveDefinition(
        _definition(
          id: 'daily',
          title: 'Daily',
          startDate: todayKey,
          recurrence: ReminderRecurrence.daily,
        ),
      );
      await _pumpPage(tester);

      await _swipeLeft(
        tester,
        find.byKey(ValueKey('reminder-daily@$todayKey')),
      );
      await tester.tap(find.widgetWithText(TextButton, '今回のみ削除'));
      await tester.pumpAndSettle();

      final state = (await container.reminders.findStates()).single;
      expect(state.status, ReminderOccurrenceStatus.skipped);
      expect(find.text('Daily'), findsNothing);
      final service = ReminderOccurrenceService(container.reminders);
      expect(
        await service.inRange(DateTimeRange(start: today, end: today)),
        isEmpty,
      );
      expect(
        await service.completed(),
        isEmpty,
        reason: 'SKIPPED must never be projected as COMPLETED.',
      );
      final tomorrow = today.add(const Duration(days: 1));
      expect(
        (await service.inRange(
          DateTimeRange(start: tomorrow, end: tomorrow),
        )).single.localDate,
        _dateKey(tomorrow),
      );
      expect(await container.reminders.findDefinitions(), hasLength(1));

      final dashboard = await DashboardPlanInformationService(
        container.schedules,
        reminders: container.reminders,
      ).loadFor(todayKey);
      expect(dashboard.entries, isEmpty);
    },
  );

  testWidgets(
    'occurrence future-delete keeps past completion and stops at boundary',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final todayKey = _dateKey(today);
      final yesterdayKey = _dateKey(yesterday);
      await container.reminders.saveDefinition(
        _definition(
          id: 'daily',
          title: 'Daily',
          startDate: yesterdayKey,
          recurrence: ReminderRecurrence.daily,
        ),
      );
      await container.reminders.saveState(
        ReminderOccurrenceState(
          id: 'daily@$yesterdayKey',
          definitionId: 'daily',
          localDate: yesterdayKey,
          status: ReminderOccurrenceStatus.completed,
          updatedAt: DateTime.now().toUtc(),
          completedAt: DateTime.now().toUtc(),
        ),
      );
      await _pumpPage(tester);

      await _swipeLeft(
        tester,
        find.byKey(ValueKey('reminder-daily@$todayKey')),
      );
      await tester.tap(find.widgetWithText(TextButton, '今後すべて削除'));
      await tester.pumpAndSettle();

      final stored = (await container.reminders.findDefinitions()).single;
      expect(stored.recurrenceEnd, yesterdayKey);
      final service = ReminderOccurrenceService(container.reminders);
      final projected = await service.inRange(
        DateTimeRange(
          start: yesterday,
          end: today.add(const Duration(days: 2)),
        ),
      );
      expect(projected.map((value) => value.localDate), [yesterdayKey]);
      expect(projected.single.status, ReminderOccurrenceStatus.completed);
      expect((await service.completed()).single.localDate, yesterdayKey);
    },
  );

  testWidgets(
    'recurring definition tap edits and swipe stops future generation',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayKey = _dateKey(yesterday);
      await container.reminders.saveDefinition(
        _definition(
          id: 'daily',
          title: 'Daily',
          startDate: yesterdayKey,
          recurrence: ReminderRecurrence.daily,
        ),
      );
      await container.reminders.saveState(
        ReminderOccurrenceState(
          id: 'daily@$yesterdayKey',
          definitionId: 'daily',
          localDate: yesterdayKey,
          status: ReminderOccurrenceStatus.completed,
          updatedAt: DateTime.now().toUtc(),
          completedAt: DateTime.now().toUtc(),
        ),
      );
      await _pumpPage(tester);
      await tester.tap(find.text('RECURRING'));
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('recurring-row-daily'));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('REMINDERを編集'), findsOneWidget);
      expect(find.text('毎日'), findsWidgets);
      Navigator.of(tester.element(find.text('REMINDERを編集'))).pop();
      await tester.pumpAndSettle();

      await _swipeLeft(tester, find.byKey(const ValueKey('recurring-daily')));
      expect(find.text('過去と完了履歴は保持します。'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();

      expect(find.text('Daily'), findsNothing);
      final definitions = await container.reminders.findDefinitions();
      expect(definitions.single.recurrenceEnd, yesterdayKey);
      expect(await container.reminders.findStates(), hasLength(1));
      expect(
        (await ReminderOccurrenceService(
          container.reminders,
        ).completed()).single.localDate,
        yesterdayKey,
      );
    },
  );

  testWidgets(
    'Japanese recurrence controls and shared Material time picker remain wired',
    (tester) async {
      await _pumpPage(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('タイトル'), findsOneWidget);
      expect(find.text('メモ'), findsOneWidget);
      expect(find.text('繰り返し'), findsOneWidget);
      expect(find.text('繰り返しの設定'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Custom');
      await tester.tap(find.text('なし'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('曜日指定').last);
      await tester.pumpAndSettle();
      expect(find.text('繰り返しの設定'), findsOneWidget);
      expect(find.text('終了日を指定する'), findsOneWidget);
      for (final label in ['月', '火', '水', '木', '金', '土', '日']) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.widgetWithText(SwitchListTile, '時刻'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('時刻  '));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('月'));
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();
      final saved = (await container.reminders.findDefinitions()).single;
      expect(saved.recurrence, ReminderRecurrence.customWeekdays);
      expect(saved.weekdays, [DateTime.monday]);
    },
  );

  testWidgets('custom month days save numeric slots and month-end separately', (
    tester,
  ) async {
    await _pumpPage(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Month slots');
    await tester.tap(find.text('なし'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日付指定').last);
    await tester.pumpAndSettle();

    expect(find.text('月末'), findsOneWidget);
    await tester.tap(find.text('1'));
    await tester.tap(find.text('15'));
    await tester.tap(find.text('月末'));
    final save = find.widgetWithText(ElevatedButton, '保存');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final saved = (await container.reminders.findDefinitions()).single;
    expect(saved.recurrence, ReminderRecurrence.customMonthDays);
    expect(saved.monthDays, [1, 15]);
    expect(saved.monthEnd, isTrue);
  });

  testWidgets('full-screen editor guards dirty header and system exits', (
    tester,
  ) async {
    final today = _dateKey(DateTime.now());
    await _pumpPage(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('REMINDERを追加'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('変更内容が保存されていません。破棄しますか？'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Discarded');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('変更内容が保存されていません。破棄しますか？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '編集を続ける'));
    await tester.pumpAndSettle();
    expect(find.text('Discarded'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '破棄する'));
    await tester.pumpAndSettle();
    expect(await container.reminders.findDefinitions(), isEmpty);

    await container.reminders.saveDefinition(
      _definition(id: 'edit', title: 'Original', startDate: today),
    );
    await tester.pumpWidget(
      const MaterialApp(home: RemindersPage(key: ValueKey('editor-updated'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Changed');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '破棄する'));
    await tester.pumpAndSettle();
    expect(
      (await container.reminders.findDefinitions()).single.title,
      'Original',
    );

    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Saved');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(
      (await container.reminders.findDefinitions())
          .where((value) => value.active)
          .single
          .title,
      'Saved',
    );
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: RemindersPage()));
  await tester.pumpAndSettle();
}

Future<void> _swipeLeft(WidgetTester tester, Finder finder) async {
  await tester.drag(finder, const Offset(-500, 0));
  await tester.pumpAndSettle();
}

ReminderDefinition _definition({
  required String id,
  String title = 'Single',
  required String startDate,
  ReminderRecurrence recurrence = ReminderRecurrence.none,
}) {
  final now = DateTime.now().toUtc();
  return ReminderDefinition(
    id: id,
    title: title,
    startDate: startDate,
    allDay: true,
    recurrence: recurrence,
    active: true,
    createdAt: now,
    updatedAt: now,
  );
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
