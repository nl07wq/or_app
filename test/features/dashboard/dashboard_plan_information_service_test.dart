import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/dashboard/services/dashboard_plan_information_service.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';
import 'package:or_app/features/schedule/repository/schedule_repository.dart';

void main() {
  test('projects only today schedules and eligible reminders', () async {
    final result = await DashboardPlanInformationService(
      _FakeScheduleRepository([
        _record('today-timed', '2026-10-01', start: '07:00'),
        _record('today-all-day', '2026-10-01', allDay: true),
        _record('past-schedule', '2026-09-30'),
        _record('future-schedule', '2026-10-02'),
        _record(
          'today-reminder',
          '2026-10-01',
          kind: ScheduleEntryKind.reminder,
          start: '22:25',
        ),
        _record(
          'past-timed-reminder',
          '2026-09-29',
          kind: ScheduleEntryKind.reminder,
          start: '08:00',
        ),
        _record(
          'past-untimed-reminder',
          '2026-09-30',
          kind: ScheduleEntryKind.reminder,
          allDay: true,
        ),
        _record(
          'past-completed',
          '2026-09-28',
          kind: ScheduleEntryKind.reminder,
          completed: true,
        ),
        _record(
          'today-completed',
          '2026-10-01',
          kind: ScheduleEntryKind.reminder,
          completed: true,
        ),
        _record(
          'future-reminder',
          '2026-10-02',
          kind: ScheduleEntryKind.reminder,
        ),
      ]),
    ).loadFor('2026-10-01');

    expect(result.entries.map((entry) => entry.record.id), [
      'today-timed',
      'today-all-day',
      'today-reminder',
      'past-timed-reminder',
      'past-untimed-reminder',
    ]);
    expect(result.entries.skip(3).every((entry) => entry.isOverdue), isTrue);
  });

  test(
    'uses deterministic overdue, timed, then all-day and untimed order',
    () async {
      final result = await DashboardPlanInformationService(
        _FakeScheduleRepository([
          _record(
            'overdue-late',
            '2026-09-30',
            kind: ScheduleEntryKind.reminder,
            start: '22:25',
          ),
          _record(
            'overdue-oldest',
            '2026-09-29',
            kind: ScheduleEntryKind.reminder,
          ),
          _record('timed-late', '2026-10-01', start: '18:00'),
          _record(
            'timed-early-reminder',
            '2026-10-01',
            kind: ScheduleEntryKind.reminder,
            start: '07:00',
          ),
          _record('all-day', '2026-10-01', allDay: true),
          _record(
            'untimed-reminder',
            '2026-10-01',
            kind: ScheduleEntryKind.reminder,
          ),
        ]),
      ).loadFor('2026-10-01');

      expect(result.entries.map((entry) => entry.record.id), [
        'timed-late',
        'all-day',
        'timed-early-reminder',
        'untimed-reminder',
        'overdue-oldest',
        'overdue-late',
      ]);
    },
  );

  test(
    're-evaluates yesterday plan records when operation date advances',
    () async {
      final service = DashboardPlanInformationService(
        _FakeScheduleRepository([
          _record('schedule', '2026-10-01', start: '07:00'),
          _record(
            'open-reminder',
            '2026-10-01',
            kind: ScheduleEntryKind.reminder,
          ),
          _record(
            'complete-reminder',
            '2026-10-01',
            kind: ScheduleEntryKind.reminder,
            completed: true,
          ),
        ]),
      );

      final today = await service.loadFor('2026-10-01');
      final nextDay = await service.loadFor('2026-10-02');

      expect(today.entries.map((entry) => entry.record.id), [
        'schedule',
        'open-reminder',
      ]);
      expect(nextDay.entries.map((entry) => entry.record.id), [
        'open-reminder',
      ]);
      expect(nextDay.entries.single.isOverdue, isTrue);
    },
  );

  test('removes a reminder as soon as Calendar marks it completed', () async {
    final records = [
      _record('reminder', '2026-10-01', kind: ScheduleEntryKind.reminder),
    ];
    final service = DashboardPlanInformationService(
      _FakeScheduleRepository(records),
    );

    expect((await service.loadFor('2026-10-01')).entries, hasLength(1));
    records[0] = _record(
      'reminder',
      '2026-10-01',
      kind: ScheduleEntryKind.reminder,
      completed: true,
    );
    expect((await service.loadFor('2026-10-01')).entries, isEmpty);
  });

  testWidgets('caps Dashboard rows and keeps each row Calendar-addressable', (
    tester,
  ) async {
    final information = DashboardPlanInformation(
      operationDate: '2026-10-01',
      entries: [
        _entry(
          'overdue',
          '2026-09-30',
          DashboardPlanInformationGroup.overdueReminder,
        ),
        _entry(
          'morning',
          '2026-10-01',
          DashboardPlanInformationGroup.todaySchedule,
        ),
        _entry(
          'evening',
          '2026-10-01',
          DashboardPlanInformationGroup.todaySchedule,
        ),
        _entry(
          'all-day',
          '2026-10-01',
          DashboardPlanInformationGroup.todaySchedule,
        ),
      ],
    );

    for (final width in <double>[320, 390, 900]) {
      String? openedDate;
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScheduleCard(
              information: information,
              loading: false,
              onOpenDate: (value) => openedDate = value,
            ),
          ),
        ),
      );

      expect(find.text('morning'), findsOneWidget);
      expect(find.text('evening'), findsOneWidget);
      expect(find.text('all-day'), findsNothing);
      expect(find.text('他1件'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final cardCenter = tester
          .getCenter(find.byKey(const ValueKey('dashboard-schedule')))
          .dx;
      final headerRow = tester.widget<Row>(
        find
            .ancestor(of: find.text('SCHEDULE'), matching: find.byType(Row))
            .first,
      );
      expect(headerRow.mainAxisAlignment, MainAxisAlignment.start);
      expect(tester.getCenter(find.text('SCHEDULE')).dx, lessThan(cardCenter));
      for (final id in ['overdue', 'morning', 'evening']) {
        final entry = find.byKey(ValueKey('dashboard-schedule-entry-hud-$id'));
        expect(tester.getCenter(entry).dx, closeTo(cardCenter, .1));
        expect(tester.widget<Container>(entry).decoration, isNull);
      }
      final hud = tester.widget<Container>(
        find.byKey(const ValueKey('dashboard-schedule-hud')),
      );
      expect((hud.decoration! as BoxDecoration).border, isNull);
      for (final id in ['overdue', 'morning', 'evening']) {
        expect(
          find.byKey(ValueKey('dashboard-schedule-anchor-$id')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Icon>(
                find.byKey(ValueKey('dashboard-schedule-anchor-$id')),
              )
              .size,
          18,
        );
        expect(
          tester
              .widget<Icon>(
                find.byKey(ValueKey('dashboard-schedule-anchor-$id')),
              )
              .icon,
          Icons.circle_outlined,
        );
        expect(
          find.byKey(ValueKey('dashboard-schedule-rail-$id')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('dashboard-schedule-anchor-connector-$id')),
          findsNothing,
        );
      }
      expect(
        tester.getCenter(find.text('morning')).dx,
        greaterThan(
          tester
              .getCenter(
                find.byKey(const ValueKey('dashboard-schedule-anchor-morning')),
              )
              .dx,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('dashboard-schedule-entry-morning')),
      );
      expect(openedDate, '2026-10-01');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('uses a Japanese empty state without a date identity', (
    tester,
  ) async {
    String? openedDate;
    Future<void> pump(String operationDate) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScheduleCard(
            information: DashboardPlanInformation(
              operationDate: operationDate,
              entries: const [],
            ),
            loading: false,
            onOpenDate: (value) => openedDate = value,
          ),
        ),
      ),
    );

    await pump('2026-10-04');
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('予定はありません'), findsOneWidget);
    expect(find.text('日曜日'), findsNothing);
    expect(find.text('4'), findsNothing);
    final empty = tester.widget<Text>(find.text('予定はありません'));
    expect(
      empty.style?.fontSize,
      Theme.of(
        tester.element(find.text('予定はありません')),
      ).textTheme.bodyMedium?.fontSize,
    );
    expect(empty.style?.fontWeight, FontWeight.w400);
    expect(
      tester.getCenter(find.text('予定はありません')).dx,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('dashboard-schedule'))).dx,
        .1,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('dashboard-schedule')));
    expect(openedDate, '2026-10-04');
  });
}

DashboardPlanInformationEntry _entry(
  String id,
  String date,
  DashboardPlanInformationGroup group,
) => DashboardPlanInformationEntry(
  record: _record(
    id,
    date,
    kind:
        group == DashboardPlanInformationGroup.todayReminder ||
            group == DashboardPlanInformationGroup.overdueReminder
        ? ScheduleEntryKind.reminder
        : ScheduleEntryKind.schedule,
  ),
  group: group,
);

ScheduleRecord _record(
  String id,
  String localDate, {
  ScheduleEntryKind kind = ScheduleEntryKind.schedule,
  ScheduleType type = ScheduleType.work,
  bool allDay = false,
  String? start,
  bool completed = false,
}) => ScheduleRecord(
  id: id,
  localDate: localDate,
  type: type,
  title: id,
  kind: kind,
  allDay: allDay,
  startTime: start,
  completed: completed,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _FakeScheduleRepository implements ScheduleRepository {
  _FakeScheduleRepository(this._records);

  final List<ScheduleRecord> _records;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<ScheduleRecord>> findAll() async => _records;

  @override
  Future<List<ScheduleRecord>> findForDate(String localDate) async =>
      _records.where((record) => record.localDate == localDate).toList();

  @override
  Future<List<ScheduleRecord>> findForMonth(DateTime month) async => _records
      .where(
        (record) => record.localDate.startsWith(
          '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}',
        ),
      )
      .toList();

  @override
  Future<ScheduleRecord?> findWorkForDate(String localDate) async {
    final values = await findForDate(localDate);
    final work = values
        .where((record) => record.type == ScheduleType.work)
        .toList();
    return work.isEmpty ? null : work.first;
  }

  @override
  Future<void> save(ScheduleRecord record) async {}
}
