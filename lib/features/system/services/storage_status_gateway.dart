import 'storage_status_gateway_stub.dart'
    if (dart.library.html) 'storage_status_gateway_web.dart';

enum StorageEstimateState { available, unsupported, failed }

enum StoragePersistence { persistent, bestEffort, unknown }

class StorageStatusSnapshot {
  const StorageStatusSnapshot({
    required this.estimateState,
    this.usageBytes,
    this.quotaBytes,
    required this.persistence,
  });

  final StorageEstimateState estimateState;
  final double? usageBytes;
  final double? quotaBytes;
  final StoragePersistence persistence;
}

abstract interface class StorageStatusGateway {
  Future<StorageStatusSnapshot> load();

  factory StorageStatusGateway.platform() => createStorageStatusGateway();
}
