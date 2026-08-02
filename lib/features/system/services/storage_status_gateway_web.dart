import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'storage_status_gateway.dart';

StorageStatusGateway createStorageStatusGateway() => WebStorageStatusGateway();

@JS('navigator')
external JSObject get _navigator;

class WebStorageStatusGateway implements StorageStatusGateway {
  @override
  Future<StorageStatusSnapshot> load() async {
    if (!_navigator.has('storage')) {
      return const StorageStatusSnapshot(
        estimateState: StorageEstimateState.unsupported,
        persistence: StoragePersistence.unknown,
      );
    }
    final storage = _navigator['storage'] as JSObject;
    var estimateState = StorageEstimateState.unsupported;
    double? usage;
    double? quota;
    if (storage.has('estimate')) {
      try {
        final estimate = await storage
            .callMethod<JSPromise<JSAny?>>('estimate'.toJS)
            .toDart;
        final object = estimate as JSObject;
        usage = _number(object['usage']);
        quota = _number(object['quota']);
        estimateState = StorageEstimateState.available;
      } catch (_) {
        estimateState = StorageEstimateState.failed;
      }
    }
    var persistence = StoragePersistence.unknown;
    if (storage.has('persisted')) {
      try {
        final value = await storage
            .callMethod<JSPromise<JSAny?>>('persisted'.toJS)
            .toDart;
        if (value?.isA<JSBoolean>() == true) {
          persistence = (value as JSBoolean).toDart
              ? StoragePersistence.persistent
              : StoragePersistence.bestEffort;
        }
      } catch (_) {
        persistence = StoragePersistence.unknown;
      }
    }
    return StorageStatusSnapshot(
      estimateState: estimateState,
      usageBytes: usage,
      quotaBytes: quota,
      persistence: persistence,
    );
  }

  static double? _number(JSAny? value) =>
      value?.isA<JSNumber>() == true ? (value as JSNumber).toDartDouble : null;
}
