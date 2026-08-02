import '../models/dns_archive_models.dart';

class LegacyDailySummaryConflict implements Exception {
  final String localDate;
  const LegacyDailySummaryConflict(this.localDate);
  @override
  String toString() => 'Legacy Daily Summary conflict for $localDate.';
}

abstract interface class LegacyDailySummaryRepository {
  Future<LegacyDailySummaryRecord> create(LegacyDailySummaryRecord record);
  Future<LegacyDailySummaryRecord?> readByLocalDate(String localDate);
  Future<List<LegacyDailySummaryRecord>> list();
  Future<List<LegacyDailySummaryRecord>> readDateRange(
    String start,
    String end,
  );
}
