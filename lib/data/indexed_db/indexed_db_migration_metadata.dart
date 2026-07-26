enum IndexedDbMigrationStatus {
  notStarted,
  validating,
  writing,
  prepared,
  verifying,
  completed,
  failed,
}

class IndexedDbMigrationMetadata {
  static const Object _unset = Object();

  final String id;
  final IndexedDbMigrationStatus status;
  final String source;
  final int targetDatabaseVersion;
  final int attempt;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? ownerId;
  final DateTime? leaseExpiresAt;
  final Map<String, int> sourceCounts;
  final Map<String, int> validCounts;
  final Map<String, int> quarantinedCounts;
  final Map<String, List<String>> expectedRecordIds;
  final String? sourceDigest;
  final String? errorCode;
  final String? errorMessage;

  IndexedDbMigrationMetadata({
    required this.id,
    required this.status,
    required this.source,
    required this.targetDatabaseVersion,
    required this.attempt,
    required this.startedAt,
    required this.updatedAt,
    this.completedAt,
    this.ownerId,
    this.leaseExpiresAt,
    Map<String, int> sourceCounts = const {},
    Map<String, int> validCounts = const {},
    Map<String, int> quarantinedCounts = const {},
    Map<String, List<String>> expectedRecordIds = const {},
    this.sourceDigest,
    this.errorCode,
    this.errorMessage,
  }) : sourceCounts = Map<String, int>.unmodifiable(sourceCounts),
       validCounts = Map<String, int>.unmodifiable(validCounts),
       quarantinedCounts = Map<String, int>.unmodifiable(quarantinedCounts),
       expectedRecordIds = Map<String, List<String>>.unmodifiable({
         for (final entry in expectedRecordIds.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       });

  IndexedDbMigrationMetadata copyWith({
    IndexedDbMigrationStatus? status,
    int? attempt,
    DateTime? startedAt,
    DateTime? updatedAt,
    Object? completedAt = _unset,
    Object? ownerId = _unset,
    Object? leaseExpiresAt = _unset,
    Map<String, int>? sourceCounts,
    Map<String, int>? validCounts,
    Map<String, int>? quarantinedCounts,
    Map<String, List<String>>? expectedRecordIds,
    Object? sourceDigest = _unset,
    Object? errorCode = _unset,
    Object? errorMessage = _unset,
  }) {
    return IndexedDbMigrationMetadata(
      id: id,
      status: status ?? this.status,
      source: source,
      targetDatabaseVersion: targetDatabaseVersion,
      attempt: attempt ?? this.attempt,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt == _unset
          ? this.completedAt
          : completedAt as DateTime?,
      ownerId: ownerId == _unset ? this.ownerId : ownerId as String?,
      leaseExpiresAt: leaseExpiresAt == _unset
          ? this.leaseExpiresAt
          : leaseExpiresAt as DateTime?,
      sourceCounts: sourceCounts ?? this.sourceCounts,
      validCounts: validCounts ?? this.validCounts,
      quarantinedCounts: quarantinedCounts ?? this.quarantinedCounts,
      expectedRecordIds: expectedRecordIds ?? this.expectedRecordIds,
      sourceDigest: sourceDigest == _unset
          ? this.sourceDigest
          : sourceDigest as String?,
      errorCode: errorCode == _unset ? this.errorCode : errorCode as String?,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  Map<String, Object?> toRecord() {
    return {
      'id': id,
      'status': status.name,
      'source': source,
      'targetDatabaseVersion': targetDatabaseVersion,
      'attempt': attempt,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (completedAt != null)
        'completedAt': completedAt!.toUtc().toIso8601String(),
      if (ownerId != null) 'ownerId': ownerId,
      if (leaseExpiresAt != null)
        'leaseExpiresAt': leaseExpiresAt!.toUtc().toIso8601String(),
      'sourceCounts': sourceCounts,
      'validCounts': validCounts,
      'quarantinedCounts': quarantinedCounts,
      'expectedRecordIds': expectedRecordIds,
      if (sourceDigest != null) 'sourceDigest': sourceDigest,
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  factory IndexedDbMigrationMetadata.fromRecord(Map<String, Object?> record) {
    return IndexedDbMigrationMetadata(
      id: _requiredString(record, 'id'),
      status: IndexedDbMigrationStatus.values.firstWhere(
        (status) => status.name == record['status'],
        orElse: () =>
            throw const FormatException('Invalid migration metadata status.'),
      ),
      source: _requiredString(record, 'source'),
      targetDatabaseVersion: _requiredInt(record, 'targetDatabaseVersion'),
      attempt: _requiredInt(record, 'attempt'),
      startedAt: _requiredDate(record, 'startedAt'),
      updatedAt: _requiredDate(record, 'updatedAt'),
      completedAt: _optionalDate(record, 'completedAt'),
      ownerId: _optionalString(record, 'ownerId'),
      leaseExpiresAt: _optionalDate(record, 'leaseExpiresAt'),
      sourceCounts: _intMap(record, 'sourceCounts'),
      validCounts: _intMap(record, 'validCounts'),
      quarantinedCounts: _intMap(record, 'quarantinedCounts'),
      expectedRecordIds: _stringListMap(record, 'expectedRecordIds'),
      sourceDigest: _optionalString(record, 'sourceDigest'),
      errorCode: _optionalString(record, 'errorCode'),
      errorMessage: _optionalString(record, 'errorMessage'),
    );
  }

  static String _requiredString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid migration metadata $key.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid migration metadata $key.');
    }
    return value;
  }

  static int _requiredInt(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! int) {
      throw FormatException('Invalid migration metadata $key.');
    }
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> record, String key) {
    final date = _optionalDate(record, key);
    if (date == null) {
      throw FormatException('Invalid migration metadata $key.');
    }
    return date;
  }

  static DateTime? _optionalDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid migration metadata $key.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Invalid migration metadata $key.');
    }
    return date;
  }

  static Map<String, int> _intMap(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value == null) return const {};
    if (value is! Map) {
      throw FormatException('Invalid migration metadata $key.');
    }
    final result = <String, int>{};
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! int) {
        throw FormatException('Invalid migration metadata $key.');
      }
      result[entry.key as String] = entry.value as int;
    }
    return result;
  }

  static Map<String, List<String>> _stringListMap(
    Map<String, Object?> record,
    String key,
  ) {
    final value = record[key];
    if (value == null) return const {};
    if (value is! Map) {
      throw FormatException('Invalid migration metadata $key.');
    }
    final result = <String, List<String>>{};
    for (final entry in value.entries) {
      if (entry.key is! String ||
          entry.value is! List ||
          !(entry.value as List).every((item) => item is String)) {
        throw FormatException('Invalid migration metadata $key.');
      }
      result[entry.key as String] = List<String>.from(entry.value as List);
    }
    return result;
  }
}
