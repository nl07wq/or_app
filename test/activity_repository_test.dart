import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalActivityRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const LocalActivityRepository();
  });

  test('saves and loads a daily Activity record', () async {
    final data = ActivityData(date: DateTime(2026, 7, 21), steps: 8420);

    await repository.save(data);

    final loaded = await repository.findByDate(DateTime(2026, 7, 21));
    expect(loaded?.steps, 8420);
  });

  test('saving a matching local date updates instead of duplicating', () async {
    await repository.save(ActivityData(date: DateTime(2026, 7, 21, 9), steps: 500));
    await repository.save(ActivityData(date: DateTime(2026, 7, 21, 18), steps: 1200));

    final records = await repository.getAll();
    expect(records, hasLength(1));
    expect(records.single.steps, 1200);
  });

  test('returns records newest first', () async {
    await repository.save(ActivityData(date: DateTime(2026, 7, 20), steps: 100));
    await repository.save(ActivityData(date: DateTime(2026, 7, 22), steps: 200));

    final records = await repository.getAll();
    expect(records.map((record) => record.steps), [200, 100]);
  });

  test('deleting a record removes only the selected date', () async {
    await repository.save(ActivityData(date: DateTime(2026, 7, 20), steps: 100));
    await repository.save(ActivityData(date: DateTime(2026, 7, 21), steps: 200));

    await repository.deleteByDate(DateTime(2026, 7, 20));

    final records = await repository.getAll();
    expect(records, hasLength(1));
    expect(records.single.steps, 200);
  });
}
