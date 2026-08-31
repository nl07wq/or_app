import 'dart:convert';

import '../../../core/models/morning_data.dart';
import '../../../core/models/training_session.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../../status/models/persisted_status_record.dart';
import '../../training/models/persisted_training_record.dart';
import '../../training/repository/training_record_id_generator.dart';
import '../models/backup_package.dart';
import 'backup_canonical_codec.dart';
import 'backup_store_registry.dart';
import 'backup_operation_state_integrity.dart';

class BackupPackageCodec {
  static const maxFileBytes = 50 * 1024 * 1024;
  static const _schema1MigrationId = 'backup_schema_1_to_schema_2';

  const BackupPackageCodec();

  BackupPackage decodeUtf8(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const BackupException('empty_file', 'Backup file is empty.');
    }
    if (bytes.length > maxFileBytes) {
      throw const BackupException(
        'file_too_large',
        'Backup file exceeds 50 MB.',
      );
    }
    try {
      final content = utf8.decode(bytes, allowMalformed: false);
      return decode(
        content.startsWith('\uFEFF') ? content.substring(1) : content,
      );
    } on FormatException catch (error) {
      throw BackupException('invalid_utf8', error.message);
    }
  }

  BackupPackage decode(String input) {
    final Object? decoded;
    try {
      decoded = jsonDecode(input);
    } on FormatException catch (error) {
      throw BackupException('invalid_json', error.message);
    }
    if (decoded is! Map) {
      throw const BackupException(
        'invalid_root',
        'Backup root must be a JSON object.',
      );
    }
    final json = Map<String, Object?>.from(decoded);
    if (json['schemaVersion'] == '1.0') return _decodeSchema1(json);
    final version = json['schemaVersion'];
    if (version is int &&
        version >= 2 &&
        version <= BackupPackage.currentSchemaVersion) {
      return _decodeCurrent(json, version);
    }
    throw const BackupException(
      'unsupported_schema',
      'Backup schema is not supported.',
    );
  }

  BackupPackage _decodeCurrent(Map<String, Object?> json, int schemaVersion) {
    if (json['schema'] != BackupPackage.schemaName ||
        json['schemaVersion'] != schemaVersion) {
      throw const BackupException(
        'unsupported_schema',
        'Backup schema is not supported.',
      );
    }
    final exportId = _string(json, 'exportId');
    final exportedAt = _date(json, 'exportedAt');
    final databaseVersion = json['databaseVersion'];
    if (databaseVersion is! int ||
        !IndexedDbSchema.supportsBackupDatabaseVersion(databaseVersion)) {
      throw const BackupException(
        'unsupported_database_version',
        'Backup databaseVersion is not supported.',
      );
    }
    final sourceJson = _map(json, 'source');
    final source = BackupSource(
      platform: _string(sourceJson, 'platform'),
      origin: sourceJson['origin'] as String?,
      deviceLabel: sourceJson['deviceLabel'] as String?,
    );
    final countJson = _map(json, 'recordCounts');
    final digestJson = _map(json, 'digests');
    final dataJson = _map(json, 'data');
    final auditArchiveId = schemaVersion == 14
        ? _string(json, 'auditArchiveId')
        : null;
    final data = <String, List<Map<String, Object?>>>{};
    final counts = <String, int>{};
    final sectionDigests = <String, String>{};
    for (final section in BackupSections.forSchema(schemaVersion)) {
      final rawRecords = dataJson[section];
      if (rawRecords is! List) {
        throw BackupException(
          'missing_section',
          'Backup section $section is required.',
        );
      }
      final records = BackupStoreRegistry.validateAndSort(
        section,
        rawRecords.map((value) {
          if (value is! Map) {
            throw BackupException(
              'invalid_record',
              '$section contains a non-object record.',
            );
          }
          final record = Map<String, Object?>.from(value);
          if (schemaVersion <= BackupPackage.legacyFullSchemaVersion &&
              (record.containsKey('archivedRevisions') ||
                  (section == BackupSections.reportSyncHistory &&
                      record['recordVersion'] == 4))) {
            throw const BackupException(
              'invalid_legacy_revision_contract',
              'Legacy Backup requires complete historical bodies.',
            );
          }
          if (section == BackupSections.confirmations &&
              schemaVersion < 10 &&
              record['recordVersion'] !=
                  PersistedDailyLogConfirmationRecord.legacyRecordVersion) {
            throw const BackupException(
              'invalid_record',
              'Backup schemas 2 through 9 require Confirmation v1 records.',
            );
          }
          return record;
        }),
      );
      final expectedCount = countJson[section];
      if (expectedCount is! int || expectedCount != records.length) {
        throw BackupException(
          'record_count_mismatch',
          '$section record count does not match.',
        );
      }
      final expectedDigest = digestJson[section];
      final actualDigest = BackupCanonicalCodec.digest(records);
      if (expectedDigest is! String || expectedDigest != actualDigest) {
        throw BackupException(
          'section_digest_mismatch',
          '$section digest does not match.',
        );
      }
      data[section] = records;
      counts[section] = records.length;
      sectionDigests[section] = actualDigest;
    }
    final packageDigest = digestJson['package'];
    if (packageDigest is! String) {
      throw const BackupException(
        'package_digest_missing',
        'Package digest is required.',
      );
    }
    final digestPayload = <String, Object?>{
      'schema': BackupPackage.schemaName,
      'schemaVersion': schemaVersion,
      'exportId': exportId,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      if (json['appVersion'] case final String version) 'appVersion': version,
      'databaseVersion': databaseVersion,
      'source': source.toJson(),
      'auditArchiveId': ?auditArchiveId,
      'recordCounts': counts,
      'digests': sectionDigests,
      'data': data,
    };
    if (BackupCanonicalCodec.digest(digestPayload) != packageDigest) {
      throw const BackupException(
        'package_digest_mismatch',
        'Package digest does not match.',
      );
    }
    if (schemaVersion >= 3) {
      BackupOperationStateIntegrity.validate(data);
    }
    return BackupPackage(
      exportId: exportId,
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      appVersion: json['appVersion'] as String?,
      databaseVersion: databaseVersion,
      source: source,
      recordCounts: BackupRecordCounts(counts),
      digests: BackupDigests(package: packageDigest, sections: sectionDigests),
      data: data,
      auditArchiveId: auditArchiveId,
    );
  }

  BackupPackage _decodeSchema1(Map<String, Object?> json) {
    final exportedAt = _date(json, 'exportedAt').toUtc();
    final statusValues = _optionalRecordList(json, 'morningFact');
    final trainingValues = _optionalRecordList(json, 'training');
    final status = _convertStatus(statusValues, exportedAt);
    final training = _convertTraining(trainingValues, exportedAt);
    final data = <String, List<Map<String, Object?>>>{
      BackupSections.status: status,
      BackupSections.training: training,
    };
    final counts = {
      BackupSections.status: status.length,
      BackupSections.training: training.length,
    };
    final digests = {
      BackupSections.status: BackupCanonicalCodec.digest(status),
      BackupSections.training: BackupCanonicalCodec.digest(training),
    };
    final exportId = 'legacy-${BackupCanonicalCodec.digest(json)}';
    return BackupPackage(
      schema: 'legacy-operation-reboot-export',
      schemaVersion: 1,
      exportId: exportId,
      exportedAt: exportedAt,
      databaseVersion: IndexedDbSchema.databaseVersion,
      source: const BackupSource(platform: 'legacy'),
      recordCounts: BackupRecordCounts(counts),
      digests: BackupDigests(
        package: BackupCanonicalCodec.digest(json),
        sections: digests,
      ),
      data: data,
      includedSections: const {BackupSections.status, BackupSections.training},
    );
  }

  List<Map<String, Object?>> _convertStatus(
    List<Map<String, Object?>> values,
    DateTime timestamp,
  ) {
    final parsed = <({int index, MorningData data})>[];
    for (var index = 0; index < values.length; index++) {
      parsed.add((
        index: index,
        data: MorningData.fromJson(Map<String, dynamic>.from(values[index])),
      ));
    }
    final groups = <String, List<({int index, MorningData data})>>{};
    for (final value in parsed) {
      final localDate = PersistedStatusRecord.localDateFromSource(
        value.data.date,
      );
      groups.putIfAbsent(localDate, () => []).add(value);
    }
    final records = <Map<String, Object?>>[];
    for (final entry in groups.entries) {
      final candidates = entry.value;
      var canonical = candidates.first;
      for (final candidate in candidates.skip(1)) {
        final candidateDate = DateTime.parse(candidate.data.date);
        final canonicalDate = DateTime.parse(canonical.data.date);
        if (candidateDate.isAfter(canonicalDate) ||
            (candidateDate == canonicalDate &&
                candidate.index > canonical.index)) {
          canonical = candidate;
        }
      }
      var revision = 0;
      for (final candidate in candidates) {
        final isCanonical = identical(candidate, canonical);
        if (!isCanonical) revision++;
        records.add(
          PersistedStatusRecord(
            id: isCanonical
                ? PersistedStatusRecord.canonicalId(entry.key)
                : PersistedStatusRecord.legacyRevisionId(entry.key, revision),
            localDate: entry.key,
            createdAt: timestamp,
            updatedAt: timestamp,
            canonicalDate: isCanonical ? entry.key : null,
            recordKind: isCanonical
                ? StatusRecordKind.canonical
                : StatusRecordKind.legacyRevision,
            migrationSource: StatusMigrationSource(
              migrationId: _schema1MigrationId,
              sourceSystem: 'export_schema_1',
              sourceKey: 'morningFact',
              sourceIndex: candidate.index,
            ),
            data: candidate.data,
          ).toRecord(),
        );
      }
    }
    return BackupStoreRegistry.validateAndSort(BackupSections.status, records);
  }

  List<Map<String, Object?>> _convertTraining(
    List<Map<String, Object?>> values,
    DateTime timestamp,
  ) {
    final generator = const TrainingLegacyIdGenerator();
    final duplicates = <String, int>{};
    final records = <Map<String, Object?>>[];
    for (var index = 0; index < values.length; index++) {
      final value = Map<String, dynamic>.from(values[index]);
      final session = TrainingSession.fromJson(value);
      final canonical = TrainingLegacyIdGenerator.canonicalJson(value);
      final ordinal = duplicates.update(
        canonical,
        (count) => count + 1,
        ifAbsent: () => 0,
      );
      final id = generator.generate(
        sessionJson: value,
        sourceIndex: index,
        duplicateOrdinal: ordinal,
      );
      records.add(
        PersistedTrainingRecord(
          id: id,
          localDate: PersistedTrainingRecord.localDateFromSession(session),
          createdAt: timestamp,
          updatedAt: timestamp,
          migrationSource: TrainingMigrationSource(
            migrationId: _schema1MigrationId,
            sourceSystem: 'export_schema_1',
            sourceKey: 'training',
            sourceIndex: index,
            duplicateOrdinal: ordinal,
          ),
          data: session,
        ).toRecord(),
      );
    }
    return BackupStoreRegistry.validateAndSort(
      BackupSections.training,
      records,
    );
  }

  static List<Map<String, Object?>> _optionalRecordList(
    Map<String, Object?> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return const [];
    if (value is! List) {
      throw BackupException('invalid_schema_1', '$key must be an array.');
    }
    return [
      for (final record in value)
        if (record is Map)
          Map<String, Object?>.from(record)
        else
          throw BackupException(
            'invalid_schema_1',
            '$key contains a non-object record.',
          ),
    ];
  }

  static Map<String, Object?> _map(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! Map) {
      throw BackupException('invalid_structure', '$key must be an object.');
    }
    return Map<String, Object?>.from(value);
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw BackupException('invalid_structure', '$key must be a string.');
    }
    return value;
  }

  static DateTime _date(Map<String, Object?> json, String key) {
    final value = _string(json, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw BackupException('invalid_timestamp', '$key is invalid.');
    }
    return parsed;
  }
}
