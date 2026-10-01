import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';
import 'package:or_app/features/schedule/repository/indexed_db_schedule_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  ScheduleRecord record({
    required String id,
    required String date,
    ScheduleType type = ScheduleType.personal,
  }) => ScheduleRecord(
    id: id,
    localDate: date,
    type: type,
    title: type.name,
    startTime: '07:00',
    endTime: '18:00',
    breakDuration: '01:00',
    createdAt: DateTime.utc(2026, 9, 30),
    updatedAt: DateTime.utc(2026, 9, 30),
  );

  test(
    'schedule persists independently by date and survives repository reload',
    () async {
      final database = FakeIndexedDbDatabase();
      final first = IndexedDbScheduleRepository(database);
      await first.save(record(id: 'a', date: '2026-10-01'));
      await first.save(record(id: 'b', date: '2026-10-02'));

      final reloaded = IndexedDbScheduleRepository(database);
      expect((await reloaded.findForDate('2026-10-01')).single.id, 'a');
      expect((await reloaded.findForDate('2026-10-02')).single.id, 'b');
      expect((await reloaded.findAll()).map((value) => value.id), ['a', 'b']);
    },
  );

  test('one WORK schedule per operation date is enforced by type', () async {
    final repository = IndexedDbScheduleRepository(FakeIndexedDbDatabase());
    await repository.save(
      record(id: 'work-a', date: '2026-10-01', type: ScheduleType.work),
    );
    expect(await repository.findWorkForDate('2026-10-01'), isNotNull);
    await expectLater(
      repository.save(
        record(id: 'work-b', date: '2026-10-01', type: ScheduleType.work),
      ),
      throwsA(isA<Object>()),
    );
  });

  test('delete affects only the selected plan record', () async {
    final repository = IndexedDbScheduleRepository(FakeIndexedDbDatabase());
    await repository.save(record(id: 'a', date: '2026-10-01'));
    await repository.save(record(id: 'b', date: '2026-10-01'));
    await repository.delete('a');
    expect(
      (await repository.findForDate('2026-10-01')).map((value) => value.id),
      ['b'],
    );
  });
}
