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
  static const currentSchemaVersion = 2;

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
  bool get permitsReplaceAll => schemaVersion == currentSchemaVersion;

  Map<String, Object?> toJson() => {
    'schema': schema,
    'schemaVersion': schemaVersion,
    'exportId': exportId,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    if (appVersion != null) 'appVersion': appVersion,
    'databaseVersion': databaseVersion,
    'source': source.toJson(),
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

  static const all = [
    status,
    activity,
    food,
    training,
    confirmations,
    customExercises,
  ];
}

enum BackupImportMode { merge, replaceAll }

class BackupSectionPlan {
  final int existing;
  final int add;
  final int skip;
  final int replace;
  final List<String> conflicts;

  BackupSectionPlan({
    this.existing = 0,
    this.add = 0,
    this.skip = 0,
    this.replace = 0,
    Iterable<String> conflicts = const [],
  }) : conflicts = List.unmodifiable(conflicts);
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
}

class BackupImportResult {
  final bool success;
  final String? errorCode;
  final String? message;

  const BackupImportResult.success()
    : success = true,
      errorCode = null,
      message = null;

  const BackupImportResult.failure({
    required this.errorCode,
    required this.message,
  }) : success = false;
}

class BackupException implements Exception {
  final String code;
  final String message;

  const BackupException(this.code, this.message);

  @override
  String toString() => '$code: $message';
}
