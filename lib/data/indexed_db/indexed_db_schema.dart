import 'indexed_db_store_names.dart';

abstract final class IndexedDbSchema {
  static const databaseName = 'operation_reboot_db';
  static const databaseVersion = 1;
  static const keyPath = 'id';
  static const objectStores = IndexedDbStoreNames.all;
}
