import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../import_export/models/backup_package.dart';
import '../services/operation_sync_module_adapter.dart';

class ConfirmationOperationSyncAdapter
    extends IndexedDbOperationTransferModuleAdapter {
  ConfirmationOperationSyncAdapter(IndexedDbDatabase database)
    : super(
        database: database,
        policies: [
          OperationSyncRecordPolicy(
            recordType: 'dailyConfirmation',
            storeName: IndexedDbStoreNames.dailyLogConfirmations,
            backupSection: BackupSections.confirmations,
            recordVersions: const {1},
            dateBound: true,
            matches: (record) => record['recordVersion'] == 1,
            uniqueFields: const ['localDate'],
          ),
        ],
      );

  @override
  String get module => 'confirmation';

  @override
  String get schemaVersion => '1.0';
}
