import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../../daily_aggregate/repository/daily_aggregate_repository.dart';
import '../../status/models/persisted_status_record.dart';
import '../../status/repositories/status_repository.dart';
import '../models/body_history_models.dart';

class BodyHistorySourceResolver {
  final StatusRepository statusRepository;
  final DailyAggregateRepository dailyAggregateRepository;

  const BodyHistorySourceResolver({
    required this.statusRepository,
    required this.dailyAggregateRepository,
  });

  Future<List<BodyHistoryDataPoint>> resolve({
    required String startDate,
    required String endDate,
  }) async {
    final statusResult = await statusRepository.getRange(startDate, endDate);
    final aggregates = await dailyAggregateRepository.getRange(
      startDate,
      endDate,
    );
    final aggregateByDate = {
      for (final aggregate in aggregates) aggregate.operationDate: aggregate,
    };
    final resolved = <String, BodyHistoryDataPoint>{};
    for (final record in statusResult.records) {
      resolved[record.localDate] = BodyHistoryDataPoint(
        operationDate: record.localDate,
        weightKg: record.data.weight,
        bodyFatPercent: record.data.bodyFat,
        source: BodyHistorySource.status,
      );
    }
    for (final entry in aggregateByDate.entries) {
      if (resolved.containsKey(entry.key)) continue;
      final aggregate = entry.value;
      resolved[entry.key] = BodyHistoryDataPoint(
        operationDate: entry.key,
        weightKg: aggregate.weightKg,
        bodyFatPercent: aggregate.bodyFatPercent,
        source: aggregate.sourceType == DailyAggregateSourceType.legacyDns
            ? BodyHistorySource.aggregateLegacyDns
            : BodyHistorySource.aggregateRecords,
      );
    }
    final values = resolved.values.toList()
      ..sort(
        (first, second) => first.operationDate.compareTo(second.operationDate),
      );
    return List.unmodifiable(values);
  }

  static String localDateFromStatus(String sourceDate) =>
      PersistedStatusRecord.localDateFromSource(sourceDate);
}
