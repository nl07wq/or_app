class BackupSource {
  final String platform;
  final String? origin;
  final String? deviceLabel;

  const BackupSource({required this.platform, this.origin, this.deviceLabel});

  Map<String, Object?> toJson() => {
    'platform': platform,
    if (origin != null) 'origin': origin,
    'deviceLabel': deviceLabel,
  };
}

class BackupRecordCounts {
  final Map<String, int> values;

  BackupRecordCounts(Map<String, int> values)
    : values = Map.unmodifiable(values);

  int operator [](String section) => values[section] ?? 0;

  Map<String, Object?> toJson() => Map<String, Object?>.from(values);
}

class BackupDigests {
  final String package;
  final Map<String, String> sections;

  BackupDigests({required this.package, required Map<String, String> sections})
    : sections = Map.unmodifiable(sections);

  Map<String, Object?> toJson() => {'package': package, ...sections};
}

class BackupPackage {
  static const schemaName = 'operation-reboot-backup';
  static const currentSchemaVersion = 15;
  static const legacyFullSchemaVersion = 13;
  static const previousSchemaVersion = 2;

  final String schema;
  final int schemaVersion;
  final String exportId;
  final DateTime exportedAt;
  final String? appVersion;
  final int databaseVersion;
  final BackupSource source;
  final BackupRecordCounts recordCounts;
  final BackupDigests digests;
  final Map<String, List<Map<String, Object?>>> data;
  final Set<String> includedSections;
  final String? auditArchiveId;

  BackupPackage({
    this.schema = schemaName,
    this.schemaVersion = currentSchemaVersion,
    required this.exportId,
    required this.exportedAt,
    this.appVersion,
    required this.databaseVersion,
    required this.source,
    required this.recordCounts,
    required this.digests,
    required Map<String, List<Map<String, Object?>>> data,
    Set<String>? includedSections,
    this.auditArchiveId,
  }) : data = Map<String, List<Map<String, Object?>>>.unmodifiable({
         for (final entry in data.entries)
           entry.key: List<Map<String, Object?>>.unmodifiable(
             entry.value.map(
               (record) => Map<String, Object?>.unmodifiable(record),
             ),
           ),
       }),
       includedSections = Set.unmodifiable(includedSections ?? data.keys);

  bool get isLegacyConverted => schemaVersion == 1;
  bool get permitsReplaceAll =>
      schemaVersion >= previousSchemaVersion &&
      schemaVersion <= currentSchemaVersion;

  Map<String, Object?> toJson() => {
    'schema': schema,
    'schemaVersion': schemaVersion,
    'exportId': exportId,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    if (appVersion != null) 'appVersion': appVersion,
    'databaseVersion': databaseVersion,
    'source': source.toJson(),
    if (auditArchiveId != null) 'auditArchiveId': auditArchiveId,
    'recordCounts': recordCounts.toJson(),
    'digests': digests.toJson(),
    'data': data,
  };
}

abstract final class BackupSections {
  static const status = 'status';
  static const activity = 'activity';
  static const food = 'food';
  static const training = 'training';
  static const confirmations = 'dailyLogConfirmations';
  static const customExercises = 'customTrainingExercises';
  static const operationState = 'operationState';
  static const foodCatalog = 'foodCatalogRecords';
  static const foodRecipes = 'foodRecipeRecords';
  static const foodMealMasters = 'foodMealMasterRecords';
  static const operationSyncHistory = 'operationSyncHistory';
  static const morningBriefRecords = 'morningBriefRecords';
  static const dailyDebriefRecords = 'dailyDebriefRecords';
  static const reportSyncHistory = 'reportSyncHistory';
  static const trainingAnalysisReportRecords = 'trainingAnalysisReportRecords';
  static const periodicReportRecords = 'periodicReportRecords';
  static const legacyDailySummaryRecords = 'legacyDailySummaryRecords';
  static const profile = 'profile';
  static const dailyAggregateRecords = 'dailyAggregateRecords';

  static const schema2 = [
    status,
    activity,
    food,
    training,
    confirmations,
    customExercises,
  ];

  static const schema3 = [...schema2, operationState];
  static const schema4 = [...schema3, foodCatalog, foodRecipes];
  static const schema5 = [...schema4, operationSyncHistory];
  static const schema6 = [
    ...schema5,
    morningBriefRecords,
    dailyDebriefRecords,
    reportSyncHistory,
  ];
  static const schema7 = [...schema6, legacyDailySummaryRecords];
  static const schema8 = [...schema7, profile];
  static const schema9 = schema8;
  static const schema10 = schema9;
  static const schema11 = [...schema10, dailyAggregateRecords];
  static const schema12 = [...schema11, trainingAnalysisReportRecords];
  static const schema13 = [...schema12, periodicReportRecords];
  static const schema14 = [
    ...schema4,
    morningBriefRecords,
    dailyDebriefRecords,
    reportSyncHistory,
    legacyDailySummaryRecords,
    profile,
    dailyAggregateRecords,
    trainingAnalysisReportRecords,
    periodicReportRecords,
  ];
  static const schema15 = [...schema14, foodMealMasters];
  static const all = schema13;
  static const allCurrent = [...schema13, foodMealMasters];

  static List<String> forSchema(int schemaVersion) => switch (schemaVersion) {
    2 => schema2,
    3 => schema3,
    4 => schema4,
    5 => schema5,
    6 => schema6,
    7 => schema7,
    8 => schema8,
    9 => schema9,
    10 => schema10,
    11 => schema11,
    12 => schema12,
    13 => schema13,
    14 => schema14,
    15 => schema15,
    _ => throw BackupException(
      'unsupported_schema',
      'Backup schema is not supported.',
    ),
  };
}

enum BackupImportMode { merge, replaceAll }

/// The final integrity outcome of one Restore execution.
///
/// This deliberately contains operation metadata only.  Backup payloads and
/// record bodies remain local and are never copied into an audit result.
enum BackupImportAuditStatus { success, failed, rolledBack }

enum BackupRollbackStatus { notRequired, succeeded, failed }

class BackupImportAudit {
  const BackupImportAudit({
    required this.mode,
    required this.schemaVersion,
    required this.sectionsPlanned,
    required this.sectionsCompleted,
    required this.importedRecords,
    required this.added,
    required this.skipped,
    required this.conflicts,
    required this.failed,
    required this.status,
    required this.rollback,
    this.failureSection,
    this.failureReason,
    this.conflictIdentities = const [],
  });

  final BackupImportMode mode;
  final int schemaVersion;
  final int sectionsPlanned;
  final int sectionsCompleted;
  final int importedRecords;
  final int added;
  final int skipped;
  final int conflicts;
  final int failed;
  final BackupImportAuditStatus status;
  final BackupRollbackStatus rollback;
  final String? failureSection;
  final String? failureReason;
  final List<String> conflictIdentities;

  /// A compact status line suitable for an operation log or a user-visible
  /// restore result.  It intentionally never includes record payloads.
  String get summary =>
      '${mode.name}: sections $sectionsCompleted/$sectionsPlanned, '
      'add $added, skip $skipped, conflict $conflicts, failed $failed, '
      'rollback ${rollback.name}';
}

class BackupSectionPlan {
  final int existing;
  final int add;
  final int skip;
  final int replace;
  final List<String> conflicts;
  final Set<String> conflictingRecordIds;

  BackupSectionPlan({
    this.existing = 0,
    this.add = 0,
    this.skip = 0,
    this.replace = 0,
    Iterable<String> conflicts = const [],
    Iterable<String> conflictingRecordIds = const [],
  }) : conflicts = List.unmodifiable(conflicts),
       conflictingRecordIds = Set.unmodifiable(conflictingRecordIds);
}

class BackupImportPlan {
  final BackupPackage package;
  final BackupImportMode mode;
  final Map<String, BackupSectionPlan> sections;

  BackupImportPlan({
    required this.package,
    required this.mode,
    required Map<String, BackupSectionPlan> sections,
  }) : sections = Map.unmodifiable(sections);

  bool get hasConflicts =>
      sections.values.any((section) => section.conflicts.isNotEmpty);

  bool get hasBlockingConflicts =>
      mode == BackupImportMode.replaceAll && hasConflicts;
}

class BackupImportResult {
  final bool success;
  final String? errorCode;
  final String? message;
  final bool operationStateRestored;
  final bool recoveryRequired;
  final BackupImportAudit? audit;

  const BackupImportResult.success({
    this.operationStateRestored = false,
    this.recoveryRequired = false,
    this.audit,
  }) : success = true,
       errorCode = null,
       message = null;

  const BackupImportResult.failure({
    required this.errorCode,
    required this.message,
    this.audit,
  }) : success = false,
       operationStateRestored = false,
       recoveryRequired = false;
}

class BackupException implements Exception {
  final String code;
  final String message;

  const BackupException(this.code, this.message);

  @override
  String toString() => '$code: $message';
}
