import 'storage_status_gateway.dart';

StorageStatusGateway createStorageStatusGateway() =>
    const UnsupportedStorageStatusGateway();

class UnsupportedStorageStatusGateway implements StorageStatusGateway {
  const UnsupportedStorageStatusGateway();

  @override
  Future<StorageStatusSnapshot> load() async => const StorageStatusSnapshot(
    estimateState: StorageEstimateState.unsupported,
    persistence: StoragePersistence.unknown,
  );
}
