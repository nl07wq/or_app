import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../import_export/models/backup_package.dart';
import '../services/operation_sync_module_adapter.dart';

class ActivityOperationSyncAdapter
    extends IndexedDbOperationTransferModuleAdapter {
  ActivityOperationSyncAdapter(IndexedDbDatabase database)
    : super(
        database: database,
        policies: [
          OperationSyncRecordPolicy(
            recordType: 'activityRecord',
            storeName: IndexedDbStoreNames.activityRecords,
            backupSection: BackupSections.activity,
            recordVersions: const {1},
            dateBound: true,
            matches: (record) => record['recordVersion'] == 1,
            uniqueFields: const ['canonicalDate'],
          ),
        ],
      );

  @override
  String get module => 'activity';

  @override
  String get schemaVersion => '1.0';
}
