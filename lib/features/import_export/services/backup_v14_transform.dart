import '../models/backup_audit_package.dart';
import '../models/backup_package.dart';
import 'backup_canonical_codec.dart';
import 'backup_store_registry.dart';

abstract final class BackupV14Transform {
  static const _revisionSections = {
    BackupSections.confirmations,
    BackupSections.morningBriefRecords,
    BackupSections.dailyDebriefRecords,
    BackupSections.trainingAnalysisReportRecords,
    BackupSections.periodicReportRecords,
  };

  static ({
    Map<String, List<Map<String, Object?>>> normal,
    Map<String, List<Map<String, Object?>>> audit,
    bool archiveComplete,
  })
  split(
    Map<String, List<Map<String, Object?>>> source, {
    int schemaVersion = BackupPackage.currentSchemaVersion,
  }) {
    final normal = <String, List<Map<String, Object?>>>{};
    final revisionBodies = <Map<String, Object?>>[];
    var archiveComplete = true;
    for (final section in BackupSections.forSchema(schemaVersion)) {
      final records = source[section] ?? const [];
      normal[section] = [
        for (final record in records)
          if (_revisionSections.contains(section))
            _splitRevisionRecord(
              section,
              record,
              revisionBodies,
              onIncomplete: () => archiveComplete = false,
            )
          else if (section == BackupSections.reportSyncHistory)
            _splitReportSyncRecord(record)
          else
            _copyMap(record),
      ];
    }
    final mealSnapshots = <Map<String, Object?>>[];
    for (final record in source[BackupSections.reportSyncHistory] ?? const []) {
      final snapshots = record['importedMealSnapshots'];
      if (snapshots is List && snapshots.isNotEmpty) {
        mealSnapshots.add({
          'exchangeId': record['exchangeId'],
          'snapshots': _copyValue(snapshots),
        });
      } else if (record['detailsArchived'] == true &&
          (record['importedMealCount'] as int? ?? 0) > 0) {
        archiveComplete = false;
      }
    }
    return (
      normal: normal,
      audit: {
        BackupAuditSections.revisionBodies: revisionBodies,
        BackupAuditSections.reportSyncMealSnapshots: mealSnapshots,
        BackupAuditSections.operationSyncHistory: [
          for (final record
              in source[BackupSections.operationSyncHistory] ?? const [])
            _copyMap(record),
        ],
      },
      archiveComplete: archiveComplete,
    );
  }

  static Map<String, List<Map<String, Object?>>> hydrate(
    BackupPackage normal,
    BackupAuditPackage audit,
  ) {
    validatePair(normal, audit);
    final result = <String, List<Map<String, Object?>>>{
      for (final entry in normal.data.entries)
        entry.key: [for (final record in entry.value) _copyMap(record)],
    };
    final bodiesByIdentity = <String, Map<String, Object?>>{
      for (final entry
          in audit.data[BackupAuditSections.revisionBodies] ?? const [])
        _revisionIdentity(
          entry['section'] as String,
          entry['recordId'] as String,
          entry['revision'] as int,
        ): Map<String, Object?>.from(
          entry['body'] as Map,
        ),
    };
    for (final section in _revisionSections) {
      result[section] = [
        for (final record in result[section] ?? const [])
          _hydrateRevisionRecord(section, record, bodiesByIdentity),
      ];
    }
    final snapshotsByExchange = <String, List<Object?>>{
      for (final entry
          in audit.data[BackupAuditSections.reportSyncMealSnapshots] ??
              const [])
        entry['exchangeId'] as String: List<Object?>.from(
          entry['snapshots'] as List,
        ),
    };
    result[BackupSections.reportSyncHistory] = [
      for (final record in result[BackupSections.reportSyncHistory] ?? const [])
        _hydrateReportSyncRecord(record, snapshotsByExchange),
    ];
    result[BackupSections.operationSyncHistory] = [
      for (final record
          in audit.data[BackupAuditSections.operationSyncHistory] ?? const [])
        _copyMap(record),
    ];
    return result;
  }

  static void validatePair(BackupPackage normal, BackupAuditPackage audit) {
    if ((normal.schemaVersion != 14 && normal.schemaVersion != 15) ||
        normal.auditArchiveId != audit.archiveId ||
        normal.exportId != audit.normalExportId ||
        normal.digests.package != audit.normalPackageDigest) {
      throw const BackupException(
        'audit_archive_mismatch',
        'Audit Archive does not match the selected Normal Backup.',
      );
    }
  }

  static BackupPackage hydratePackage(
    BackupPackage normal,
    BackupAuditPackage audit,
  ) {
    final hydrated = hydrate(normal, audit);
    final normalized = <String, List<Map<String, Object?>>>{};
    final counts = <String, int>{};
    final digests = <String, String>{};
    final fullSections = normal.schemaVersion >= 15
        ? BackupSections.allCurrent
        : BackupSections.all;
    for (final section in fullSections) {
      final records = BackupStoreRegistry.validateAndSort(
        section,
        hydrated[section] ?? const [],
      );
      normalized[section] = records;
      counts[section] = records.length;
      digests[section] = BackupCanonicalCodec.digest(records);
    }
    return BackupPackage(
      schemaVersion: normal.schemaVersion,
      exportId: normal.exportId,
      exportedAt: normal.exportedAt,
      appVersion: normal.appVersion,
      databaseVersion: normal.databaseVersion,
      source: normal.source,
      recordCounts: BackupRecordCounts(counts),
      digests: BackupDigests(
        package: normal.digests.package,
        sections: digests,
      ),
      data: normalized,
      includedSections: fullSections.toSet(),
      auditArchiveId: audit.archiveId,
    );
  }

  static Map<String, Object?> _splitRevisionRecord(
    String section,
    Map<String, Object?> source,
    List<Map<String, Object?>> bodies, {
    required void Function() onIncomplete,
  }) {
    final record = _copyMap(source);
    final existingArchived = record['archivedRevisions'];
    final previous = record['previousRevisions'];
    if (existingArchived is List && existingArchived.isNotEmpty) {
      onIncomplete();
    }
    if (previous is! List || previous.length <= 1) return record;
    final recordId = _recordId(section, record);
    final archived = <Object?>[
      if (existingArchived is List) ..._copyList(existingArchived),
    ];
    for (final value in previous.take(previous.length - 1)) {
      final body = Map<String, Object?>.from(value as Map);
      final revision = body['revision'] as int;
      archived.add(_revisionMetadata(section, body));
      bodies.add({
        'section': section,
        'recordId': recordId,
        'revision': revision,
        'bodyDigest': BackupCanonicalCodec.digest(body),
        'body': body,
      });
    }
    record['archivedRevisions'] = archived;
    record['previousRevisions'] = [_copyValue(previous.last)];
    return record;
  }

  static Map<String, Object?> _hydrateRevisionRecord(
    String section,
    Map<String, Object?> source,
    Map<String, Map<String, Object?>> bodies,
  ) {
    final record = _copyMap(source);
    final archived = record.remove('archivedRevisions');
    if (archived is! List || archived.isEmpty) return record;
    final recordId = _recordId(section, record);
    final restored = <Object?>[];
    for (final metadata in archived) {
      final revision = (metadata as Map)['revision'] as int;
      final body = bodies[_revisionIdentity(section, recordId, revision)];
      if (body == null ||
          BackupCanonicalCodec.digest(body) != metadata['bodyDigest']) {
        throw const BackupException(
          'audit_revision_missing',
          'Audit Archive is missing a required Revision body.',
        );
      }
      restored.add(_copyMap(body));
    }
    restored.addAll(_copyList(record['previousRevisions'] as List));
    record['previousRevisions'] = restored;
    return record;
  }

  static Map<String, Object?> _revisionMetadata(
    String section,
    Map<String, Object?> body,
  ) {
    final metadata = <String, Object?>{
      'revision': body['revision'],
      'bodyDigest': BackupCanonicalCodec.digest(body),
    };
    const candidates = [
      'snapshotDigest',
      'responseDigest',
      'sourceDigest',
      'exchangeId',
      'createdAt',
      'importedAt',
      'finalizedAt',
      'reopenedAt',
      'sourceRecordVersions',
    ];
    for (final key in candidates) {
      if (body.containsKey(key)) metadata[key] = _copyValue(body[key]);
    }
    if (section == BackupSections.morningBriefRecords) {
      final nested = body['record'];
      if (nested is Map) {
        for (final key in const [
          'responseDigest',
          'sourceDigest',
          'exchangeId',
          'updatedAt',
        ]) {
          if (nested.containsKey(key)) metadata[key] = _copyValue(nested[key]);
        }
      }
    }
    return metadata;
  }

  static Map<String, Object?> _splitReportSyncRecord(
    Map<String, Object?> source,
  ) {
    final record = _copyMap(source);
    final snapshots = record['importedMealSnapshots'];
    final hasDetails = snapshots is List && snapshots.isNotEmpty;
    final alreadyArchived = record['detailsArchived'] == true;
    if (record['recordVersion'] is int &&
        (record['recordVersion'] as int) >= 3 &&
        (hasDetails || alreadyArchived)) {
      record['recordVersion'] = 4;
      record['importedMealSnapshots'] = <Object?>[];
      record['detailsArchived'] = true;
    }
    return record;
  }

  static Map<String, Object?> _hydrateReportSyncRecord(
    Map<String, Object?> source,
    Map<String, List<Object?>> snapshots,
  ) {
    final record = _copyMap(source);
    if (record['recordVersion'] == 4 && record['detailsArchived'] == true) {
      final values = snapshots[record['exchangeId']];
      if (values == null) {
        throw const BackupException(
          'audit_report_sync_missing',
          'Audit Archive is missing Report Sync detail.',
        );
      }
      record['recordVersion'] = 3;
      record['importedMealSnapshots'] = _copyList(values);
      record.remove('detailsArchived');
    }
    return record;
  }

  static String _recordId(String section, Map<String, Object?> record) =>
      switch (section) {
        BackupSections.confirmations => record['id'] as String,
        BackupSections.morningBriefRecords ||
        BackupSections.dailyDebriefRecords => record['localDate'] as String,
        BackupSections.trainingAnalysisReportRecords =>
          record['targetRecordId'] as String,
        BackupSections.periodicReportRecords => record['id'] as String,
        _ => throw StateError('Unsupported revision section: $section'),
      };

  static String _revisionIdentity(String section, String id, int revision) =>
      '$section\u0000$id\u0000$revision';

  static Map<String, Object?> _copyMap(Map source) => {
    for (final entry in source.entries)
      entry.key.toString(): _copyValue(entry.value),
  };

  static List<Object?> _copyList(Iterable values) => [
    for (final value in values) _copyValue(value),
  ];

  static Object? _copyValue(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is Iterable) return _copyList(value);
    return value;
  }
}
