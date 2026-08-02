import 'operation_sync_issue.dart';

enum OperationSyncPhase {
  idle('idle'),
  reading('reading'),
  validating('validating'),
  previewReady('previewReady'),
  applying('applying'),
  verifying('verifying'),
  recoveryRequired('recoveryRequired'),
  completed('completed'),
  failed('failed');

  const OperationSyncPhase(this.stableId);
  final String stableId;
}

class OperationSyncCheckpoint {
  final String validatedPackageDigest;
  final Map<String, String> expectedSectionDigests;
  final List<String> expectedRecordDigests;
  final List<String> appliedSectionIds;
  final String verificationStatus;

  OperationSyncCheckpoint({
    required this.validatedPackageDigest,
    required Map<String, String> expectedSectionDigests,
    required Iterable<String> expectedRecordDigests,
    required Iterable<String> appliedSectionIds,
    required this.verificationStatus,
  }) : expectedSectionDigests = Map.unmodifiable(expectedSectionDigests),
       expectedRecordDigests = List.unmodifiable(expectedRecordDigests),
       appliedSectionIds = List.unmodifiable(appliedSectionIds);

  Map<String, Object?> toJson() => {
    'validatedPackageDigest': validatedPackageDigest,
    'expectedSectionDigests': expectedSectionDigests,
    'expectedRecordDigests': expectedRecordDigests,
    'appliedSectionIds': appliedSectionIds,
    'verificationStatus': verificationStatus,
  };

  factory OperationSyncCheckpoint.fromJson(Map<String, Object?> json) {
    _expectKeys(json, const {
      'validatedPackageDigest',
      'expectedSectionDigests',
      'expectedRecordDigests',
      'appliedSectionIds',
      'verificationStatus',
    });
    final sections = json['expectedSectionDigests'];
    if (sections is! Map) throw const FormatException('Invalid checkpoint.');
    final sectionDigests = <String, String>{};
    for (final entry in sections.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid section digest.');
      }
      sectionDigests[entry.key as String] = entry.value as String;
    }
    return OperationSyncCheckpoint(
      validatedPackageDigest: _string(json, 'validatedPackageDigest'),
      expectedSectionDigests: sectionDigests,
      expectedRecordDigests: _stringList(json, 'expectedRecordDigests'),
      appliedSectionIds: _stringList(json, 'appliedSectionIds'),
      verificationStatus: _string(json, 'verificationStatus'),
    );
  }
}

class OperationSyncState {
  static const canonicalId = 'current';
  static const currentRecordVersion = 1;
  static const _unset = Object();

  final String id;
  final int recordVersion;
  final int revision;
  final OperationSyncPhase phase;
  final String? operationId;
  final String? packageId;
  final String? packageDigest;
  final String? sourceType;
  final String? transferMode;
  final DateTime? startedAt;
  final DateTime updatedAt;
  final OperationSyncCheckpoint? checkpoint;
  final OperationSyncIssueCode? failureCode;
  final String? failureDetailCode;

  const OperationSyncState({
    this.id = canonicalId,
    this.recordVersion = currentRecordVersion,
    required this.revision,
    required this.phase,
    this.operationId,
    this.packageId,
    this.packageDigest,
    this.sourceType,
    this.transferMode,
    this.startedAt,
    required this.updatedAt,
    this.checkpoint,
    this.failureCode,
    this.failureDetailCode,
  });

  bool get requiresRecovery => switch (phase) {
    OperationSyncPhase.reading ||
    OperationSyncPhase.validating ||
    OperationSyncPhase.applying ||
    OperationSyncPhase.verifying ||
    OperationSyncPhase.recoveryRequired => true,
    _ => false,
  };

  OperationSyncState copyWith({
    int? revision,
    OperationSyncPhase? phase,
    Object? operationId = _unset,
    Object? packageId = _unset,
    Object? packageDigest = _unset,
    Object? sourceType = _unset,
    Object? transferMode = _unset,
    Object? startedAt = _unset,
    DateTime? updatedAt,
    Object? checkpoint = _unset,
    Object? failureCode = _unset,
    Object? failureDetailCode = _unset,
  }) {
    return OperationSyncState(
      revision: revision ?? this.revision,
      phase: phase ?? this.phase,
      operationId: operationId == _unset
          ? this.operationId
          : operationId as String?,
      packageId: packageId == _unset ? this.packageId : packageId as String?,
      packageDigest: packageDigest == _unset
          ? this.packageDigest
          : packageDigest as String?,
      sourceType: sourceType == _unset
          ? this.sourceType
          : sourceType as String?,
      transferMode: transferMode == _unset
          ? this.transferMode
          : transferMode as String?,
      startedAt: startedAt == _unset ? this.startedAt : startedAt as DateTime?,
      updatedAt: updatedAt ?? this.updatedAt,
      checkpoint: checkpoint == _unset
          ? this.checkpoint
          : checkpoint as OperationSyncCheckpoint?,
      failureCode: failureCode == _unset
          ? this.failureCode
          : failureCode as OperationSyncIssueCode?,
      failureDetailCode: failureDetailCode == _unset
          ? this.failureDetailCode
          : failureDetailCode as String?,
    );
  }

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': recordVersion,
    'revision': revision,
    'phase': phase.stableId,
    'operationId': operationId,
    'packageId': packageId,
    'packageDigest': packageDigest,
    'sourceType': sourceType,
    'transferMode': transferMode,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'checkpoint': checkpoint?.toJson(),
    'failureCode': failureCode?.stableId,
    'failureDetailCode': failureDetailCode,
  };

  factory OperationSyncState.fromRecord(Map<String, Object?> record) {
    _expectKeys(record, const {
      'id',
      'recordVersion',
      'revision',
      'phase',
      'operationId',
      'packageId',
      'packageDigest',
      'sourceType',
      'transferMode',
      'startedAt',
      'updatedAt',
      'checkpoint',
      'failureCode',
      'failureDetailCode',
    });
    if (record['id'] != canonicalId ||
        record['recordVersion'] != currentRecordVersion ||
        record['revision'] is! int ||
        (record['revision'] as int) < 0) {
      throw const FormatException('Invalid Operation Sync State identity.');
    }
    final phase = _enumById(
      OperationSyncPhase.values,
      record['phase'],
      (value) => value.stableId,
    );
    final failure = record['failureCode'] == null
        ? null
        : _enumById(
            OperationSyncIssueCode.values,
            record['failureCode'],
            (value) => value.stableId,
          );
    final rawCheckpoint = record['checkpoint'];
    return OperationSyncState(
      revision: record['revision'] as int,
      phase: phase,
      operationId: _nullableString(record, 'operationId'),
      packageId: _nullableString(record, 'packageId'),
      packageDigest: _nullableString(record, 'packageDigest'),
      sourceType: _nullableString(record, 'sourceType'),
      transferMode: _nullableString(record, 'transferMode'),
      startedAt: _nullableDate(record, 'startedAt'),
      updatedAt: _date(record, 'updatedAt'),
      checkpoint: rawCheckpoint == null
          ? null
          : rawCheckpoint is Map
          ? OperationSyncCheckpoint.fromJson(
              Map<String, Object?>.from(rawCheckpoint),
            )
          : throw const FormatException('Invalid checkpoint.'),
      failureCode: failure,
      failureDetailCode: _nullableString(record, 'failureDetailCode'),
    );
  }
}

void _expectKeys(Map<String, Object?> json, Set<String> expected) {
  if (json.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(json.keys.toSet()).isNotEmpty) {
    throw const FormatException('Operation Sync record fields are invalid.');
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) throw FormatException('$key invalid.');
  return value;
}

List<String> _stringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String || item.isEmpty)) {
    throw FormatException('$key must be a string list.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

DateTime _date(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) throw FormatException('$key invalid.');
  return parsed;
}

DateTime? _nullableDate(Map<String, Object?> json, String key) {
  if (json[key] == null) return null;
  return _date(json, key);
}

T _enumById<T>(Iterable<T> values, Object? raw, String Function(T) id) {
  if (raw is! String) throw const FormatException('Stable ID is invalid.');
  return values.firstWhere(
    (value) => id(value) == raw,
    orElse: () => throw FormatException('Unknown stable ID: $raw.'),
  );
}
