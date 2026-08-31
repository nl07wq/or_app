import 'dart:convert';

import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../repositories/app_repository_container.dart';
import '../../daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../models/backup_package.dart';
import '../models/backup_audit_package.dart';
import 'backup_canonical_codec.dart';
import 'backup_id_generator.dart';
import 'backup_store_registry.dart';
import 'backup_operation_state_integrity.dart';
import '../../system/models/profile_model.dart';
import 'backup_v14_transform.dart';

class BackupExportService {
  final IndexedDbDatabase _database;
  final AppInitializationController _controller;
  final BackupIdGenerator _idGenerator;
  final DateTime Function() _clock;

  BackupExportService({
    IndexedDbDatabase? database,
    AppInitializationController? controller,
    BackupIdGenerator? idGenerator,
    DateTime Function()? clock,
  }) : _database = database ?? AppRepositoryRegistry.container.database,
       _controller = controller ?? AppRepositoryRegistry.controller,
       _idGenerator = idGenerator ?? BackupIdGenerator(),
       _clock = clock ?? DateTime.now;

  Future<BackupPackage> create({String? appVersion, String? origin}) async =>
      (await createCurrentBundle(
        appVersion: appVersion,
        origin: origin,
      )).normal;

  Future<BackupPackage> createLegacyV13({
    String? appVersion,
    String? origin,
  }) async {
    final snapshot = await _snapshot();
    return buildPackage(
      exportId: _idGenerator.generate(),
      exportedAt: _clock().toUtc(),
      appVersion: appVersion,
      source: BackupSource(platform: 'web', origin: origin),
      data: snapshot,
      schemaVersion: BackupPackage.legacyFullSchemaVersion,
    );
  }

  Future<BackupV14Bundle> createV14Bundle({
    String? appVersion,
    String? origin,
  }) =>
      _createBundle(schemaVersion: 14, appVersion: appVersion, origin: origin);

  Future<BackupV14Bundle> createCurrentBundle({
    String? appVersion,
    String? origin,
  }) => _createBundle(
    schemaVersion: BackupPackage.currentSchemaVersion,
    appVersion: appVersion,
    origin: origin,
  );

  Future<BackupV14Bundle> _createBundle({
    required int schemaVersion,
    String? appVersion,
    String? origin,
  }) async {
    final snapshot = await _snapshot();
    final split = BackupV14Transform.split(
      snapshot,
      schemaVersion: schemaVersion,
    );
    final exportedAt = _clock().toUtc();
    final exportId = _idGenerator.generate();
    final archiveId = _idGenerator.generate();
    final source = BackupSource(platform: 'web', origin: origin);
    final normal = buildPackage(
      exportId: exportId,
      exportedAt: exportedAt,
      appVersion: appVersion,
      source: source,
      data: split.normal,
      schemaVersion: schemaVersion,
      auditArchiveId: archiveId,
    );
    final sectionDigests = {
      for (final entry in split.audit.entries)
        entry.key: BackupCanonicalCodec.digest(entry.value),
    };
    final auditPayload = <String, Object?>{
      'schema': BackupAuditPackage.schemaName,
      'schemaVersion': BackupAuditPackage.schemaVersion,
      'archiveId': archiveId,
      'normalExportId': exportId,
      'normalPackageDigest': normal.digests.package,
      'exportedAt': exportedAt.toIso8601String(),
      'source': source.toJson(),
      'archiveComplete': split.archiveComplete,
      'digests': sectionDigests,
      'data': split.audit,
    };
    final audit = BackupAuditPackage(
      archiveId: archiveId,
      normalExportId: exportId,
      normalPackageDigest: normal.digests.package,
      exportedAt: exportedAt,
      source: source,
      archiveComplete: split.archiveComplete,
      digests: BackupDigests(
        package: BackupCanonicalCodec.digest(auditPayload),
        sections: sectionDigests,
      ),
      data: split.audit,
    );
    return BackupV14Bundle(normal: normal, audit: audit);
  }

  Future<Map<String, List<Map<String, Object?>>>> _snapshot() async {
    if (_controller.value.mode != PersistenceMode.indexedDbReadWrite &&
        _controller.value.mode != PersistenceMode.legacyReadOnly) {
      throw const BackupException(
        'export_unavailable',
        'Backup export requires readable IndexedDB data.',
      );
    }
    final data = await _database.runTransaction(
      storeNames: BackupStoreRegistry.stores.values,
      mode: IndexedDbTransactionMode.readOnly,
      action: (transaction) async {
        final snapshot = <String, List<Map<String, Object?>>>{};
        for (final section in BackupSections.allCurrent) {
          final records = await transaction.findAll(
            BackupStoreRegistry.stores[section]!,
          );
          if (section == BackupSections.profile) {
            if (records.length > 1) {
              throw const BackupException(
                'invalid_record',
                'Profile store must contain at most one record.',
              );
            }
            snapshot[section] = [
              records.isEmpty
                  ? const ProfileModel().toBackupRecord()
                  : ProfileModel.fromRecord(records.single).toBackupRecord(),
            ];
            continue;
          }
          snapshot[section] = BackupStoreRegistry.validateAndSort(
            section,
            records,
          );
        }
        return snapshot;
      },
    );
    BackupOperationStateIntegrity.validate(data);
    return data;
  }

  static BackupPackage buildPackage({
    required String exportId,
    required DateTime exportedAt,
    String? appVersion,
    required BackupSource source,
    required Map<String, List<Map<String, Object?>>> data,
    int schemaVersion = BackupPackage.currentSchemaVersion,
    String? auditArchiveId,
  }) {
    final normalized = <String, List<Map<String, Object?>>>{};
    final counts = <String, int>{};
    final sectionDigests = <String, String>{};
    final sections = BackupSections.forSchema(schemaVersion);
    for (final section in sections) {
      final records = BackupStoreRegistry.validateAndSort(
        section,
        data[section] ?? const [],
      );
      if (schemaVersion <= BackupPackage.legacyFullSchemaVersion &&
          records.any(
            (record) =>
                record.containsKey('archivedRevisions') ||
                (section == BackupSections.reportSyncHistory &&
                    record['recordVersion'] == 4),
          )) {
        throw const BackupException(
          'legacy_full_unavailable',
          'Legacy Full Backup is unavailable without archived detail.',
        );
      }
      if (section == BackupSections.confirmations && schemaVersion < 10) {
        final containsV2 = records.any(
          (record) =>
              record['recordVersion'] !=
              PersistedDailyLogConfirmationRecord.legacyRecordVersion,
        );
        if (containsV2) {
          throw const BackupException(
            'invalid_record',
            'Backup schemas 2 through 9 require Confirmation v1 records.',
          );
        }
      }
      normalized[section] = records;
      counts[section] = records.length;
      sectionDigests[section] = BackupCanonicalCodec.digest(records);
    }
    if (schemaVersion >= 3) {
      BackupOperationStateIntegrity.validate(normalized);
    }
    final packagePayload = <String, Object?>{
      'schema': BackupPackage.schemaName,
      'schemaVersion': schemaVersion,
      'exportId': exportId,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'appVersion': ?appVersion,
      'databaseVersion': IndexedDbSchema.databaseVersion,
      'source': source.toJson(),
      'auditArchiveId': ?auditArchiveId,
      'recordCounts': counts,
      'digests': sectionDigests,
      'data': normalized,
    };
    final packageDigest = BackupCanonicalCodec.digest(packagePayload);
    return BackupPackage(
      exportId: exportId,
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      appVersion: appVersion,
      databaseVersion: IndexedDbSchema.databaseVersion,
      source: source,
      recordCounts: BackupRecordCounts(counts),
      digests: BackupDigests(package: packageDigest, sections: sectionDigests),
      data: normalized,
      auditArchiveId: auditArchiveId,
    );
  }

  static String encode(BackupPackage package) =>
      BackupCanonicalCodec.encode(package.toJson());

  static String prettyEncode(BackupPackage package) =>
      const JsonEncoder.withIndent(
        '  ',
      ).convert(BackupCanonicalCodec.canonicalize(package.toJson()));

  static String prettyEncodeAudit(BackupAuditPackage package) =>
      const JsonEncoder.withIndent(
        '  ',
      ).convert(BackupCanonicalCodec.canonicalize(package.toJson()));
}
