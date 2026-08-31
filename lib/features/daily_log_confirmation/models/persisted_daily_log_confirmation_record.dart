import '../../../core/models/daily_log_confirmation.dart';
import '../../import_export/services/backup_canonical_codec.dart';
import 'daily_log_confirmation_lifecycle.dart';

class DailyLogConfirmationMigrationSource {
  final String migrationId;
  final String sourceSystem;
  final String sourceKey;
  final int sourceIndex;

  const DailyLogConfirmationMigrationSource({
    required this.migrationId,
    required this.sourceSystem,
    required this.sourceKey,
    required this.sourceIndex,
  });

  Map<String, Object?> toJson() => {
    'migrationId': migrationId,
    'sourceSystem': sourceSystem,
    'sourceKey': sourceKey,
    'sourceIndex': sourceIndex,
  };

  factory DailyLogConfirmationMigrationSource.fromJson(
    Map<String, Object?> json,
  ) {
    final migrationId = json['migrationId'];
    final sourceSystem = json['sourceSystem'];
    final sourceKey = json['sourceKey'];
    final sourceIndex = json['sourceIndex'];
    if (migrationId is! String ||
        migrationId.isEmpty ||
        sourceSystem is! String ||
        sourceSystem.isEmpty ||
        sourceKey is! String ||
        sourceKey.isEmpty ||
        sourceIndex is! int ||
        sourceIndex < 0) {
      throw const FormatException(
        'Invalid Daily Log Confirmation migration source.',
      );
    }
    return DailyLogConfirmationMigrationSource(
      migrationId: migrationId,
      sourceSystem: sourceSystem,
      sourceKey: sourceKey,
      sourceIndex: sourceIndex,
    );
  }
}

class UnsupportedDailyLogSnapshotVersionException implements Exception {
  final Object? version;

  const UnsupportedDailyLogSnapshotVersionException(this.version);

  @override
  String toString() =>
      'Unsupported Daily Log Confirmation snapshotVersion: $version.';
}

class PersistedDailyLogConfirmationRecord {
  static const legacyRecordVersion = 1;
  static const currentRecordVersion = 2;
  static const currentSnapshotVersion = 1;

  static const _v2Fields = {
    'id',
    'recordVersion',
    'snapshotVersion',
    'localDate',
    'lifecycleStatus',
    'revision',
    'data',
    'snapshotDigest',
    'originalSnapshotDigest',
    'finalizedAt',
    'reopenedAt',
    'lastRefinalizedAt',
    'reopenReason',
    'sourceRecordVersions',
    'previousRevisions',
    'createdAt',
    'updatedAt',
    'migrationSource',
  };
  static const _v2ArchivedFields = {..._v2Fields, 'archivedRevisions'};

  final String id;
  final int recordVersion;
  final int snapshotVersion;
  final String localDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DailyLogConfirmationMigrationSource? migrationSource;
  final DailyLogConfirmation data;
  final DailyLogConfirmationLifecycleStatus? lifecycleStatus;
  final int? revision;
  final String? snapshotDigest;
  final String? originalSnapshotDigest;
  final DateTime? finalizedAt;
  final DateTime? reopenedAt;
  final DateTime? lastRefinalizedAt;
  final DailyLogConfirmationReopenReason? reopenReason;
  final DailyLogConfirmationSourceRecordVersions? sourceRecordVersions;
  final List<DailyLogConfirmationRevision> previousRevisions;
  final List<Map<String, Object?>> archivedRevisions;

  const PersistedDailyLogConfirmationRecord({
    required this.id,
    this.recordVersion = legacyRecordVersion,
    this.snapshotVersion = currentSnapshotVersion,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    this.migrationSource,
    required this.data,
  }) : lifecycleStatus = null,
       revision = null,
       snapshotDigest = null,
       originalSnapshotDigest = null,
       finalizedAt = null,
       reopenedAt = null,
       lastRefinalizedAt = null,
       reopenReason = null,
       sourceRecordVersions = null,
       previousRevisions = const [],
       archivedRevisions = const [];

  PersistedDailyLogConfirmationRecord.v2({
    required this.id,
    this.snapshotVersion = currentSnapshotVersion,
    required this.localDate,
    required this.lifecycleStatus,
    required this.revision,
    required this.data,
    required this.snapshotDigest,
    required this.originalSnapshotDigest,
    required DateTime finalizedAt,
    required DateTime? reopenedAt,
    required DateTime? lastRefinalizedAt,
    required this.reopenReason,
    required this.sourceRecordVersions,
    required Iterable<DailyLogConfirmationRevision> previousRevisions,
    Iterable<Map<String, Object?>> archivedRevisions = const [],
    required DateTime createdAt,
    required DateTime updatedAt,
    this.migrationSource,
  }) : recordVersion = currentRecordVersion,
       finalizedAt = finalizedAt.toUtc(),
       reopenedAt = reopenedAt?.toUtc(),
       lastRefinalizedAt = lastRefinalizedAt?.toUtc(),
       previousRevisions = List.unmodifiable(previousRevisions),
       archivedRevisions = List.unmodifiable(
         archivedRevisions.map(Map<String, Object?>.unmodifiable),
       ),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    _validateV2(this);
  }

  factory PersistedDailyLogConfirmationRecord.initialFinalizedV2({
    required String id,
    required String localDate,
    required DailyLogConfirmation data,
    required DateTime timestamp,
    DailyLogConfirmationSourceRecordVersions sourceRecordVersions =
        const DailyLogConfirmationSourceRecordVersions.unknown(),
    DailyLogConfirmationMigrationSource? migrationSource,
  }) {
    final copied = copyData(data);
    final digest = digestSnapshot(copied);
    return PersistedDailyLogConfirmationRecord.v2(
      id: id,
      localDate: localDate,
      lifecycleStatus: DailyLogConfirmationLifecycleStatus.finalized,
      revision: 1,
      data: copied,
      snapshotDigest: digest,
      originalSnapshotDigest: digest,
      finalizedAt: copied.confirmedAt.toUtc(),
      reopenedAt: null,
      lastRefinalizedAt: null,
      reopenReason: null,
      sourceRecordVersions: sourceRecordVersions,
      previousRevisions: const [],
      archivedRevisions: const [],
      createdAt: timestamp,
      updatedAt: timestamp,
      migrationSource: migrationSource,
    );
  }

  factory PersistedDailyLogConfirmationRecord.reopenedFrom({
    required PersistedDailyLogConfirmationRecord existing,
    required DateTime reopenedAt,
  }) {
    final timestamp = reopenedAt.toUtc();
    if (existing.projectedLifecycleStatus !=
        DailyLogConfirmationLifecycleStatus.finalized) {
      throw const FormatException(
        'Only finalized Daily Log Confirmations can be reopened.',
      );
    }
    return PersistedDailyLogConfirmationRecord.v2(
      id: existing.id,
      snapshotVersion: existing.snapshotVersion,
      localDate: existing.localDate,
      lifecycleStatus: DailyLogConfirmationLifecycleStatus.reopened,
      revision: existing.projectedRevision,
      data: copyData(existing.data),
      snapshotDigest: existing.projectedSnapshotDigest,
      originalSnapshotDigest: existing.projectedOriginalSnapshotDigest,
      finalizedAt: existing.projectedFinalizedAt,
      reopenedAt: timestamp,
      lastRefinalizedAt: existing.isLegacyV1
          ? null
          : existing.lastRefinalizedAt,
      reopenReason: DailyLogConfirmationReopenReason.userCorrection,
      sourceRecordVersions: existing.projectedSourceRecordVersions,
      previousRevisions: existing.previousRevisions,
      archivedRevisions: existing.archivedRevisions,
      createdAt: existing.createdAt.toUtc(),
      updatedAt: timestamp,
      migrationSource: existing.migrationSource,
    );
  }

  factory PersistedDailyLogConfirmationRecord.refinalizedFrom({
    required PersistedDailyLogConfirmationRecord existing,
    required DailyLogConfirmation data,
    required DailyLogConfirmationSourceRecordVersions sourceRecordVersions,
    required DateTime refinalizedAt,
  }) {
    if (existing.recordVersion != currentRecordVersion ||
        existing.lifecycleStatus !=
            DailyLogConfirmationLifecycleStatus.reopened) {
      throw const FormatException(
        'Only reopened Daily Log Confirmation v2 can be re-finalized.',
      );
    }
    final timestamp = refinalizedAt.toUtc();
    final previousFinalizedAt = existing.revision == 1
        ? existing.finalizedAt!
        : existing.lastRefinalizedAt!;
    final previous = DailyLogConfirmationRevision(
      revision: existing.revision!,
      snapshot: copyData(existing.data),
      snapshotDigest: existing.snapshotDigest!,
      finalizedAt: previousFinalizedAt,
      reopenedAt: existing.reopenedAt!,
      sourceRecordVersions: existing.sourceRecordVersions!,
    );
    final snapshot = copyData(data);
    return PersistedDailyLogConfirmationRecord.v2(
      id: existing.id,
      snapshotVersion: existing.snapshotVersion,
      localDate: existing.localDate,
      lifecycleStatus: DailyLogConfirmationLifecycleStatus.finalized,
      revision: existing.revision! + 1,
      data: snapshot,
      snapshotDigest: digestSnapshot(snapshot),
      originalSnapshotDigest: existing.originalSnapshotDigest!,
      finalizedAt: existing.finalizedAt!,
      reopenedAt: null,
      lastRefinalizedAt: timestamp,
      reopenReason: null,
      sourceRecordVersions: sourceRecordVersions,
      previousRevisions: [...existing.previousRevisions, previous],
      archivedRevisions: existing.archivedRevisions,
      createdAt: existing.createdAt,
      updatedAt: timestamp,
      migrationSource: existing.migrationSource,
    );
  }

  Map<String, Object?> toRecord() {
    if (recordVersion == legacyRecordVersion) {
      return {
        'id': id,
        'recordVersion': recordVersion,
        'snapshotVersion': snapshotVersion,
        'localDate': localDate,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (migrationSource != null)
          'migrationSource': migrationSource!.toJson(),
        'data': data.toJson(),
      };
    }
    _validateV2(this);
    return {
      'id': id,
      'recordVersion': recordVersion,
      'snapshotVersion': snapshotVersion,
      'localDate': localDate,
      'lifecycleStatus': lifecycleStatus!.stableId,
      'revision': revision,
      'data': data.toJson(),
      'snapshotDigest': snapshotDigest,
      'originalSnapshotDigest': originalSnapshotDigest,
      'finalizedAt': finalizedAt!.toIso8601String(),
      'reopenedAt': reopenedAt?.toIso8601String(),
      'lastRefinalizedAt': lastRefinalizedAt?.toIso8601String(),
      'reopenReason': reopenReason?.stableId,
      'sourceRecordVersions': sourceRecordVersions!.toJson(),
      'previousRevisions': [
        for (final previous in previousRevisions) previous.toJson(),
      ],
      if (archivedRevisions.isNotEmpty) 'archivedRevisions': archivedRevisions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'migrationSource': migrationSource?.toJson(),
    };
  }

  factory PersistedDailyLogConfirmationRecord.fromRecord(
    Map<String, Object?> record,
  ) {
    final id = _requiredString(record, 'id');
    final recordVersion = record['recordVersion'];
    if (recordVersion is! int ||
        (recordVersion != legacyRecordVersion &&
            recordVersion != currentRecordVersion)) {
      throw FormatException(
        'Unsupported Daily Log Confirmation recordVersion: $recordVersion.',
      );
    }
    if (recordVersion == currentRecordVersion) {
      return _fromV2Record(record);
    }
    final snapshotVersion = record['snapshotVersion'];
    if (snapshotVersion is! int) {
      throw const FormatException(
        'Invalid Daily Log Confirmation snapshotVersion.',
      );
    }
    if (snapshotVersion != currentSnapshotVersion) {
      throw UnsupportedDailyLogSnapshotVersionException(snapshotVersion);
    }
    final localDate = _requiredString(record, 'localDate');
    validateLocalDate(localDate);
    if (id != canonicalId(localDate)) {
      throw const FormatException(
        'Invalid Daily Log Confirmation persistent ID.',
      );
    }
    final dataValue = record['data'];
    if (dataValue is! Map) {
      throw const FormatException('Invalid Daily Log Confirmation data.');
    }
    final data = DailyLogConfirmation.fromJson(
      Map<String, dynamic>.from(dataValue),
    );
    if (localDateFromDate(data.date) != localDate) {
      throw const FormatException(
        'Daily Log Confirmation localDate does not match Domain data.',
      );
    }
    final sourceValue = record['migrationSource'];
    if (sourceValue != null && sourceValue is! Map) {
      throw const FormatException(
        'Invalid Daily Log Confirmation migrationSource.',
      );
    }
    return PersistedDailyLogConfirmationRecord(
      id: id,
      recordVersion: recordVersion,
      snapshotVersion: snapshotVersion,
      localDate: localDate,
      createdAt: _requiredDate(record, 'createdAt'),
      updatedAt: _requiredDate(record, 'updatedAt'),
      migrationSource: sourceValue == null
          ? null
          : DailyLogConfirmationMigrationSource.fromJson(
              Map<String, Object?>.from(sourceValue as Map),
            ),
      data: data,
    );
  }

  static PersistedDailyLogConfirmationRecord _fromV2Record(
    Map<String, Object?> record,
  ) {
    _requireExactFields(
      record,
      record.containsKey('archivedRevisions') ? _v2ArchivedFields : _v2Fields,
    );
    final snapshotVersion = record['snapshotVersion'];
    if (snapshotVersion is! int) {
      throw const FormatException(
        'Invalid Daily Log Confirmation snapshotVersion.',
      );
    }
    if (snapshotVersion != currentSnapshotVersion) {
      throw UnsupportedDailyLogSnapshotVersionException(snapshotVersion);
    }
    final localDate = _requiredString(record, 'localDate');
    validateLocalDate(localDate);
    final id = _requiredString(record, 'id');
    if (id != canonicalId(localDate)) {
      throw const FormatException(
        'Invalid Daily Log Confirmation persistent ID.',
      );
    }
    final dataValue = record['data'];
    final sourceValue = record['sourceRecordVersions'];
    final previousValue = record['previousRevisions'];
    final archivedValue = record['archivedRevisions'] ?? const <Object?>[];
    if (dataValue is! Map || sourceValue is! Map || previousValue is! List) {
      throw const FormatException('Invalid Daily Log Confirmation v2 data.');
    }
    if (archivedValue is! List || archivedValue.any((value) => value is! Map)) {
      throw const FormatException(
        'Invalid Daily Log Confirmation archivedRevisions.',
      );
    }
    final migrationValue = record['migrationSource'];
    if (migrationValue != null && migrationValue is! Map) {
      throw const FormatException(
        'Invalid Daily Log Confirmation migrationSource.',
      );
    }
    final rawRevision = record['revision'];
    if (rawRevision is! int) {
      throw const FormatException('Invalid Daily Log Confirmation revision.');
    }
    final rawReopenReason = record['reopenReason'];
    final parsed = PersistedDailyLogConfirmationRecord.v2(
      id: id,
      snapshotVersion: snapshotVersion,
      localDate: localDate,
      lifecycleStatus: DailyLogConfirmationLifecycleStatus.fromStableId(
        record['lifecycleStatus'],
      ),
      revision: rawRevision,
      data: DailyLogConfirmation.fromJson(Map<String, dynamic>.from(dataValue)),
      snapshotDigest: _requiredString(record, 'snapshotDigest'),
      originalSnapshotDigest: _requiredString(record, 'originalSnapshotDigest'),
      finalizedAt: _requiredUtcDate(record, 'finalizedAt'),
      reopenedAt: _nullableUtcDate(record, 'reopenedAt'),
      lastRefinalizedAt: _nullableUtcDate(record, 'lastRefinalizedAt'),
      reopenReason: rawReopenReason == null
          ? null
          : DailyLogConfirmationReopenReason.fromStableId(rawReopenReason),
      sourceRecordVersions: DailyLogConfirmationSourceRecordVersions.fromJson(
        Map<String, Object?>.from(sourceValue),
      ),
      previousRevisions: [
        for (final value in previousValue)
          if (value is Map)
            DailyLogConfirmationRevision.fromJson(
              Map<String, Object?>.from(value),
            )
          else
            throw const FormatException(
              'Invalid Daily Log Confirmation previousRevisions.',
            ),
      ],
      archivedRevisions: [
        for (final value in archivedValue)
          Map<String, Object?>.from(value as Map),
      ],
      createdAt: _requiredUtcDate(record, 'createdAt'),
      updatedAt: _requiredUtcDate(record, 'updatedAt'),
      migrationSource: migrationValue == null
          ? null
          : DailyLogConfirmationMigrationSource.fromJson(
              Map<String, Object?>.from(migrationValue as Map),
            ),
    );
    return parsed;
  }

  static String canonicalId(String localDate) {
    validateLocalDate(localDate);
    return 'confirmation:$localDate';
  }

  static String localDateFromDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static void validateLocalDate(String localDate) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(localDate);
    if (match == null) {
      throw const FormatException('Invalid Daily Log Confirmation localDate.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid Daily Log Confirmation localDate.');
    }
  }

  static DailyLogConfirmation copyData(DailyLogConfirmation data) {
    return DailyLogConfirmation.fromJson(
      Map<String, dynamic>.from(_copyMap(data.toJson())),
    );
  }

  static String digestSnapshot(DailyLogConfirmation data) =>
      BackupCanonicalCodec.digest(data.toJson());

  bool get isLegacyV1 => recordVersion == legacyRecordVersion;

  DailyLogConfirmationLifecycleStatus get projectedLifecycleStatus => isLegacyV1
      ? DailyLogConfirmationLifecycleStatus.finalized
      : lifecycleStatus!;

  int get projectedRevision => isLegacyV1 ? 1 : revision!;

  String get projectedSnapshotDigest =>
      isLegacyV1 ? digestSnapshot(data) : snapshotDigest!;

  String get projectedOriginalSnapshotDigest =>
      isLegacyV1 ? projectedSnapshotDigest : originalSnapshotDigest!;

  DateTime get projectedFinalizedAt =>
      isLegacyV1 ? data.confirmedAt.toUtc() : finalizedAt!;

  DailyLogConfirmationSourceRecordVersions get projectedSourceRecordVersions =>
      isLegacyV1
      ? const DailyLogConfirmationSourceRecordVersions.unknown()
      : sourceRecordVersions!;

  static String _requiredString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid Daily Log Confirmation $key.');
    }
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('Invalid Daily Log Confirmation $key.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Invalid Daily Log Confirmation $key.');
    }
    return date;
  }

  static DateTime _requiredUtcDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('Invalid Daily Log Confirmation $key.');
    }
    final date = DateTime.tryParse(value);
    if (date == null || !date.isUtc || !value.endsWith('Z')) {
      throw FormatException('Invalid Daily Log Confirmation $key.');
    }
    return date;
  }

  static DateTime? _nullableUtcDate(Map<String, Object?> record, String key) {
    if (record[key] == null) return null;
    return _requiredUtcDate(record, key);
  }

  static void _requireExactFields(
    Map<String, Object?> record,
    Set<String> expected,
  ) {
    final actual = record.keys.toSet();
    if (actual.difference(expected).isNotEmpty ||
        expected.difference(actual).isNotEmpty) {
      throw const FormatException('Invalid Daily Log Confirmation v2 fields.');
    }
  }

  static void _validateV2(PersistedDailyLogConfirmationRecord record) {
    if (record.recordVersion != currentRecordVersion ||
        record.snapshotVersion != currentSnapshotVersion ||
        record.lifecycleStatus == null ||
        record.revision == null ||
        record.revision! < 1 ||
        record.snapshotDigest == null ||
        record.originalSnapshotDigest == null ||
        record.finalizedAt == null ||
        record.sourceRecordVersions == null) {
      throw const FormatException('Invalid Daily Log Confirmation v2.');
    }
    validateLocalDate(record.localDate);
    if (record.id != canonicalId(record.localDate) ||
        localDateFromDate(record.data.date) != record.localDate) {
      throw const FormatException(
        'Daily Log Confirmation v2 identity does not match its Snapshot.',
      );
    }
    _validateDigest(record.snapshotDigest!, 'snapshotDigest');
    _validateDigest(record.originalSnapshotDigest!, 'originalSnapshotDigest');
    if (digestSnapshot(record.data) != record.snapshotDigest) {
      throw const FormatException(
        'Daily Log Confirmation snapshotDigest does not match data.',
      );
    }
    if (record.updatedAt.isBefore(record.createdAt)) {
      throw const FormatException(
        'Daily Log Confirmation updatedAt is invalid.',
      );
    }
    switch (record.lifecycleStatus!) {
      case DailyLogConfirmationLifecycleStatus.finalized:
        if (record.reopenedAt != null || record.reopenReason != null) {
          throw const FormatException(
            'Finalized Daily Log Confirmation lifecycle fields are invalid.',
          );
        }
        break;
      case DailyLogConfirmationLifecycleStatus.reopened:
        if (record.reopenedAt == null ||
            record.reopenReason !=
                DailyLogConfirmationReopenReason.userCorrection ||
            record.reopenedAt!.isBefore(record.projectedFinalizedAt)) {
          throw const FormatException(
            'Reopened Daily Log Confirmation lifecycle fields are invalid.',
          );
        }
        break;
    }
    if (record.revision == 1) {
      if (record.lastRefinalizedAt != null ||
          record.previousRevisions.isNotEmpty ||
          record.originalSnapshotDigest != record.snapshotDigest) {
        throw const FormatException(
          'Initial Daily Log Confirmation revision is invalid.',
        );
      }
    } else {
      if (record.lastRefinalizedAt == null ||
          record.archivedRevisions.length + record.previousRevisions.length !=
              record.revision! - 1) {
        throw const FormatException(
          'Daily Log Confirmation revision history is incomplete.',
        );
      }
    }
    for (var index = 0; index < record.archivedRevisions.length; index++) {
      final previous = record.archivedRevisions[index];
      if (previous['revision'] != index + 1 ||
          previous['bodyDigest'] is! String ||
          !RegExp(
            r'^[0-9a-f]{8}$',
          ).hasMatch(previous['bodyDigest']! as String) ||
          previous['snapshotDigest'] is! String ||
          previous['finalizedAt'] is! String ||
          previous['reopenedAt'] is! String ||
          previous['sourceRecordVersions'] is! Map) {
        throw const FormatException(
          'Daily Log Confirmation archivedRevisions are invalid.',
        );
      }
    }
    for (var index = 0; index < record.previousRevisions.length; index++) {
      final previous = record.previousRevisions[index];
      if (previous.revision != record.archivedRevisions.length + index + 1 ||
          previous.revision >= record.revision! ||
          localDateFromDate(previous.snapshot.date) != record.localDate ||
          digestSnapshot(previous.snapshot) != previous.snapshotDigest) {
        throw const FormatException(
          'Daily Log Confirmation previousRevisions are invalid.',
        );
      }
    }
    final firstDigest = record.archivedRevisions.isNotEmpty
        ? record.archivedRevisions.first['snapshotDigest']
        : record.previousRevisions.isNotEmpty
        ? record.previousRevisions.first.snapshotDigest
        : null;
    if (firstDigest != null && firstDigest != record.originalSnapshotDigest) {
      throw const FormatException(
        'Daily Log Confirmation originalSnapshotDigest is invalid.',
      );
    }
  }

  static void _validateDigest(String value, String field) {
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(value)) {
      throw FormatException('Invalid Daily Log Confirmation $field.');
    }
  }

  static Map<String, Object?> _copyMap(Map source) {
    return {
      for (final entry in source.entries)
        entry.key.toString(): _copyValue(entry.value),
    };
  }

  static Object? _copyValue(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is Iterable) return [for (final item in value) _copyValue(item)];
    return value;
  }
}
