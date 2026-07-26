import '../../../core/models/morning_data.dart';
import '../models/persisted_status_record.dart';

class StatusReadIssue {
  final String? recordId;
  final String code;
  final String message;

  const StatusReadIssue({
    required this.recordId,
    required this.code,
    required this.message,
  });
}

class StatusReadResult {
  final List<PersistedStatusRecord> records;
  final List<StatusReadIssue> issues;

  StatusReadResult({
    required Iterable<PersistedStatusRecord> records,
    Iterable<StatusReadIssue> issues = const [],
  }) : records = List.unmodifiable(records),
       issues = List.unmodifiable(issues);

  List<MorningData> get values =>
      List.unmodifiable(records.map((record) => record.data));

  bool get hasIssues => issues.isNotEmpty;
}

abstract interface class StatusRepository {
  Future<void> save(MorningData data);

  Future<MorningData?> findByLocalDate(String localDate);

  Future<MorningData?> findLatest();

  Future<StatusReadResult> findAllCanonical();

  Future<StatusReadResult> findAllIncludingRevisions();

  Future<void> deleteByLocalDate(String localDate);

  Future<void> clear();
}
