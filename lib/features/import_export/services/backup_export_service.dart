import 'dart:convert';

import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../repositories/app_repository_container.dart';
import '../models/backup_package.dart';
import 'backup_canonical_codec.dart';
import 'backup_id_generator.dart';
import 'backup_store_registry.dart';

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

  Future<BackupPackage> create({String? appVersion, String? origin}) async {
    if (_controller.value.mode != PersistenceMode.indexedDbReadWrite) {
      throw const BackupException(
        'export_unavailable',
        'Backup export requires IndexedDB read/write mode.',
      );
    }
    final data = await _database.runTransaction(
      storeNames: BackupStoreRegistry.stores.values,
      mode: IndexedDbTransactionMode.readOnly,
      action: (transaction) async {
        final snapshot = <String, List<Map<String, Object?>>>{};
        for (final section in BackupSections.all) {
          final records = await transaction.findAll(
            BackupStoreRegistry.stores[section]!,
          );
          snapshot[section] = BackupStoreRegistry.validateAndSort(
            section,
            records,
          );
        }
        return snapshot;
      },
    );
    return buildPackage(
      exportId: _idGenerator.generate(),
      exportedAt: _clock().toUtc(),
      appVersion: appVersion,
      source: BackupSource(platform: 'web', origin: origin),
      data: data,
    );
  }

  static BackupPackage buildPackage({
    required String exportId,
    required DateTime exportedAt,
    String? appVersion,
    required BackupSource source,
    required Map<String, List<Map<String, Object?>>> data,
  }) {
    final normalized = <String, List<Map<String, Object?>>>{};
    final counts = <String, int>{};
    final sectionDigests = <String, String>{};
    for (final section in BackupSections.all) {
      final records = BackupStoreRegistry.validateAndSort(
        section,
        data[section] ?? const [],
      );
      normalized[section] = records;
      counts[section] = records.length;
      sectionDigests[section] = BackupCanonicalCodec.digest(records);
    }
    final packagePayload = <String, Object?>{
      'schema': BackupPackage.schemaName,
      'schemaVersion': BackupPackage.currentSchemaVersion,
      'exportId': exportId,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'appVersion': ?appVersion,
      'databaseVersion': IndexedDbSchema.databaseVersion,
      'source': source.toJson(),
      'recordCounts': counts,
      'digests': sectionDigests,
      'data': normalized,
    };
    final packageDigest = BackupCanonicalCodec.digest(packagePayload);
    return BackupPackage(
      exportId: exportId,
      exportedAt: exportedAt,
      appVersion: appVersion,
      databaseVersion: IndexedDbSchema.databaseVersion,
      source: source,
      recordCounts: BackupRecordCounts(counts),
      digests: BackupDigests(package: packageDigest, sections: sectionDigests),
      data: normalized,
    );
  }

  static String encode(BackupPackage package) =>
      BackupCanonicalCodec.encode(package.toJson());

  static String prettyEncode(BackupPackage package) =>
      const JsonEncoder.withIndent(
        '  ',
      ).convert(BackupCanonicalCodec.canonicalize(package.toJson()));
}
