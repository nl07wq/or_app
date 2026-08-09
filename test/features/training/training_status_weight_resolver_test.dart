import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/status/repositories/status_repository.dart';
import 'package:or_app/features/training/services/training_status_weight_resolver.dart';

void main() {
  test('uses only the canonical STATUS for the requested local date', () async {
    final repository = _StatusRepository({
      '2026-07-29': _status('2026-07-29', 75),
      '2026-07-30': _status('2026-07-30', 96.8),
    });
    final resolver = TrainingStatusWeightResolver(repository: repository);

    expect(await resolver.resolve('2026-07-30'), 96.8);
    expect(repository.requestedDates, ['2026-07-30']);
  });

  test('does not substitute latest or adjacent STATUS weight', () async {
    final repository = _StatusRepository({
      '2026-07-29': _status('2026-07-29', 75),
      '2026-07-31': _status('2026-07-31', 80),
    });
    final resolver = TrainingStatusWeightResolver(repository: repository);

    expect(await resolver.resolve('2026-07-30'), isNull);
    expect(repository.latestCalls, 0);
  });

  test('rejects invalid formal weight without fallback', () async {
    for (final weight in [0.0, -1.0, double.nan, double.infinity]) {
      final resolver = TrainingStatusWeightResolver(
        repository: _StatusRepository({
          '2026-07-30': _status('2026-07-30', weight),
        }),
      );
      expect(await resolver.resolve('2026-07-30'), isNull);
    }
  });
}

class _StatusRepository implements StatusRepository {
  final Map<String, MorningData> records;
  final List<String> requestedDates = [];
  int latestCalls = 0;

  _StatusRepository(this.records);

  @override
  Future<MorningData?> findByLocalDate(String localDate) async {
    requestedDates.add(localDate);
    return records[localDate];
  }

  @override
  Future<MorningData?> findLatest() async {
    latestCalls++;
    return records.values.lastOrNull;
  }

  @override
  Future<StatusReadResult> getRange(String startDate, String endDate) async =>
      StatusReadResult(records: const []);

  @override
  Future<void> save(MorningData data) async {}

  @override
  Future<void> deleteByLocalDate(String localDate) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<StatusReadResult> findAllCanonical() async =>
      StatusReadResult(records: const []);

  @override
  Future<StatusReadResult> findAllIncludingRevisions() async =>
      StatusReadResult(records: const []);
}

MorningData _status(String localDate, double weight) => MorningData(
  date: '${localDate}T07:00:00',
  weight: weight,
  bodyFat: 20,
  sleepHours: 7,
  sleepScore: 80,
  footPain: 0,
  workType: WorkType.work,
  workStart: '09:00',
  workEnd: '18:00',
  workBreak: '01:00',
  workHours: 8,
  memo: '',
);
