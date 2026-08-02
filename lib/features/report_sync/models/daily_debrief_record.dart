import 'report_sync_record_utils.dart';

class DailyDebriefRecord {
  static const currentRecordVersion = 1;
  static const fields = {
    'localDate',
    'recordVersion',
    'requestId',
    'requestDigest',
    'responseDigest',
    'confirmationDigest',
    'generatedAt',
    'importedAt',
    'dailySummary',
    'commanderIntentEvaluation',
    'successes',
    'issues',
    'nutritionEvaluation',
    'activityEvaluation',
    'trainingEvaluation',
    'recoveryEvaluation',
    'carryover',
    'tomorrowConsiderations',
    'createdAt',
    'updatedAt',
  };
  final String localDate;
  final int recordVersion;
  final String requestId;
  final String requestDigest;
  final String responseDigest;
  final String confirmationDigest;
  final DateTime generatedAt;
  final DateTime importedAt;
  final String dailySummary;
  final String commanderIntentEvaluation;
  final List<String> successes;
  final List<String> issues;
  final String nutritionEvaluation;
  final String activityEvaluation;
  final String trainingEvaluation;
  final String recoveryEvaluation;
  final List<String> carryover;
  final List<String> tomorrowConsiderations;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyDebriefRecord({
    required this.localDate,
    this.recordVersion = currentRecordVersion,
    required this.requestId,
    required this.requestDigest,
    required this.responseDigest,
    required this.confirmationDigest,
    required this.generatedAt,
    required this.importedAt,
    required this.dailySummary,
    required this.commanderIntentEvaluation,
    required Iterable<String> successes,
    required Iterable<String> issues,
    required this.nutritionEvaluation,
    required this.activityEvaluation,
    required this.trainingEvaluation,
    required this.recoveryEvaluation,
    required Iterable<String> carryover,
    required Iterable<String> tomorrowConsiderations,
    required this.createdAt,
    required this.updatedAt,
  }) : successes = List.unmodifiable(successes),
       issues = List.unmodifiable(issues),
       carryover = List.unmodifiable(carryover),
       tomorrowConsiderations = List.unmodifiable(tomorrowConsiderations) {
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('updatedAt precedes createdAt.');
    }
  }

  Map<String, Object?> toRecord() => {
    'localDate': localDate,
    'recordVersion': recordVersion,
    'requestId': requestId,
    'requestDigest': requestDigest,
    'responseDigest': responseDigest,
    'confirmationDigest': confirmationDigest,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'importedAt': importedAt.toUtc().toIso8601String(),
    'dailySummary': dailySummary,
    'commanderIntentEvaluation': commanderIntentEvaluation,
    'successes': successes,
    'issues': issues,
    'nutritionEvaluation': nutritionEvaluation,
    'activityEvaluation': activityEvaluation,
    'trainingEvaluation': trainingEvaluation,
    'recoveryEvaluation': recoveryEvaluation,
    'carryover': carryover,
    'tomorrowConsiderations': tomorrowConsiderations,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory DailyDebriefRecord.fromRecord(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    if (json['recordVersion'] != currentRecordVersion) {
      throw const FormatException('Unsupported Daily Debrief version.');
    }
    return DailyDebriefRecord(
      localDate: ReportSyncRecordUtils.localDate(json, 'localDate'),
      requestId: ReportSyncRecordUtils.string(json, 'requestId'),
      requestDigest: ReportSyncRecordUtils.digest(json, 'requestDigest'),
      responseDigest: ReportSyncRecordUtils.digest(json, 'responseDigest'),
      confirmationDigest: ReportSyncRecordUtils.digest(
        json,
        'confirmationDigest',
      ),
      generatedAt: ReportSyncRecordUtils.date(json, 'generatedAt'),
      importedAt: ReportSyncRecordUtils.date(json, 'importedAt'),
      dailySummary: ReportSyncRecordUtils.string(json, 'dailySummary'),
      commanderIntentEvaluation: ReportSyncRecordUtils.string(
        json,
        'commanderIntentEvaluation',
      ),
      successes: ReportSyncRecordUtils.strings(json, 'successes'),
      issues: ReportSyncRecordUtils.strings(json, 'issues'),
      nutritionEvaluation: ReportSyncRecordUtils.string(
        json,
        'nutritionEvaluation',
      ),
      activityEvaluation: ReportSyncRecordUtils.string(
        json,
        'activityEvaluation',
      ),
      trainingEvaluation: ReportSyncRecordUtils.string(
        json,
        'trainingEvaluation',
      ),
      recoveryEvaluation: ReportSyncRecordUtils.string(
        json,
        'recoveryEvaluation',
      ),
      carryover: ReportSyncRecordUtils.strings(json, 'carryover'),
      tomorrowConsiderations: ReportSyncRecordUtils.strings(
        json,
        'tomorrowConsiderations',
      ),
      createdAt: ReportSyncRecordUtils.date(json, 'createdAt'),
      updatedAt: ReportSyncRecordUtils.date(json, 'updatedAt'),
    );
  }
}
