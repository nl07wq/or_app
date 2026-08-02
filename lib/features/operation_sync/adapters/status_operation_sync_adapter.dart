import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../import_export/models/backup_package.dart';
import '../services/operation_sync_module_adapter.dart';

class StatusOperationSyncAdapter
    extends IndexedDbOperationTransferModuleAdapter {
  StatusOperationSyncAdapter(IndexedDbDatabase database)
    : super(
        database: database,
        policies: [
          OperationSyncRecordPolicy(
            recordType: 'statusRecord',
            storeName: IndexedDbStoreNames.statusRecords,
            backupSection: BackupSections.status,
            recordVersions: const {1},
            dateBound: true,
            matches: (record) => record['recordVersion'] == 1,
            uniqueFields: const ['canonicalDate'],
          ),
        ],
      );

  @override
  String get module => 'status';

  @override
  String get schemaVersion => '1.0';
}
