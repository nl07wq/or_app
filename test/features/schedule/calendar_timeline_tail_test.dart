import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';
import 'package:or_app/features/schedule/pages/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppRepositoryRegistry.install(
      AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase()),
    );
  });
  tearDown(AppRepositoryRegistry.resetForTesting);

  Future<void> pumpTimeline(
    WidgetTester tester,
    int count, {
    bool multilineLast = false,
  }) async {
    final date = DateUtils.dateOnly(DateTime.now());
    for (var index = 0; index < count; index++) {
      await AppRepositoryRegistry.container.schedules.save(
        ScheduleRecord(
          id: 'tail-$count-$index',
          localDate:
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          type: ScheduleType.values[index % ScheduleType.values.length],
          title: multilineLast && index == count - 1
              ? '週次ZOOM連絡事項を確認してチームへ共有するための長い最終予定タイトル'
              : '予定 ${index + 1}',
          startTime: '${(7 + index).toString().padLeft(2, '0')}:00',
          endTime: '${(8 + index).toString().padLeft(2, '0')}:00',
          createdAt: DateTime.utc(2026, 10, 21),
          updatedAt: DateTime.utc(2026, 10, 21),
        ),
      );
    }
    await tester.pumpWidget(MaterialApp(home: CalendarPage(initialDate: date)));
    await tester.pumpAndSettle();
    await tester.pump();
  }

  for (final count in [1, 2, 5]) {
    testWidgets('short final rail is description-relative for $count item(s)', (
      tester,
    ) async {
      await pumpTimeline(tester, count, multilineLast: count == 5);
      final lastId = 'tail-$count-${count - 1}';
      final stack = tester.getRect(
        find.byKey(const ValueKey('calendar-daily-timeline-stack')),
      );
      final marker = tester
          .getRect(find.byKey(ValueKey('calendar-timeline-anchor-$lastId')))
          .shift(-stack.topLeft);
      final description = tester
          .getRect(
            find.byKey(ValueKey('calendar-timeline-description-$lastId')),
          )
          .shift(-stack.topLeft);
      expect(
        calendarTimelineTailEnd(
          size: stack.size,
          marker: marker,
          description: description,
        ),
        closeTo(description.bottom + 20, 2),
      );
      await expectLater(
        find.byKey(const ValueKey('calendar-daily-timeline-stack')),
        matchesGoldenFile('goldens/calendar_timeline_tail_$count.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
