import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const baseCampAssetAcquisitionConcurrency = 4;

final _baseCampAssetAcquisitionPool = _BaseCampAssetAcquisitionPool(
  baseCampAssetAcquisitionConcurrency,
);

@immutable
class BaseCampAssetAcquisitionResult {
  const BaseCampAssetAcquisitionResult({
    required this.assetCount,
    required this.loadedCount,
    required this.failedCount,
    required this.durationMs,
    required this.maxQueueWaitMs,
    required this.maxLoadMs,
  });

  final int assetCount;
  final int loadedCount;
  final int failedCount;
  final int durationMs;
  final int maxQueueWaitMs;
  final int maxLoadMs;
}

/// Acquires compressed asset bytes ahead of image decoding without allowing
/// the 24 WATER and 25 WALKER requests to fan out without a bound. The image
/// providers still own decoding and ImageCache insertion; this stage only
/// removes the accidental request/decode/request/decode serialization seen on
/// delayed Safari reopens.
Future<BaseCampAssetAcquisitionResult> baseCampAcquireAssetBytes(
  Iterable<String> assets, {
  @visibleForTesting Future<ByteData> Function(String asset)? loader,
}) => baseCampStartAssetAcquisition(assets, loader: loader).result;

@immutable
class BaseCampAssetAcquisitionBatch {
  const BaseCampAssetAcquisitionBatch(this.result, this._ready);

  final Future<BaseCampAssetAcquisitionResult> result;
  final Map<String, Future<void>> _ready;

  Future<void> waitFor(String asset) => _ready[asset] ?? Future<void>.value();
}

/// Starts bounded acquisition and exposes per-asset readiness. Decode lanes
/// can consume an early frame while later compressed assets are still queued,
/// avoiding a whole-batch barrier without increasing either concurrency cap.
BaseCampAssetAcquisitionBatch baseCampStartAssetAcquisition(
  Iterable<String> assets, {
  @visibleForTesting Future<ByteData> Function(String asset)? loader,
}) {
  final unique = assets.toSet().toList(growable: false);
  final ready = <String, Completer<void>>{
    for (final asset in unique) asset: Completer<void>(),
  };
  final result = _runAssetAcquisition(unique, ready, loader: loader);
  return BaseCampAssetAcquisitionBatch(result, <String, Future<void>>{
    for (final entry in ready.entries) entry.key: entry.value.future,
  });
}

Future<BaseCampAssetAcquisitionResult> _runAssetAcquisition(
  List<String> unique,
  Map<String, Completer<void>> ready, {
  Future<ByteData> Function(String asset)? loader,
}) async {
  final watch = Stopwatch()..start();
  var loaded = 0;
  var failed = 0;
  var maxQueueWaitMs = 0;
  var maxLoadMs = 0;
  final load = loader ?? rootBundle.load;
  final batch = Object();
  await Future.wait(
    unique.map((asset) async {
      final queueWatch = Stopwatch()..start();
      try {
        await _baseCampAssetAcquisitionPool.run(() async {
          maxQueueWaitMs = math.max(
            maxQueueWaitMs,
            queueWatch.elapsedMilliseconds,
          );
          final loadWatch = Stopwatch()..start();
          try {
            await load(asset);
          } finally {
            maxLoadMs = math.max(maxLoadMs, loadWatch.elapsedMilliseconds);
          }
        }, batch: batch);
        loaded++;
      } catch (_) {
        // The normal ImageProvider path remains the authoritative load and
        // reports its own error. A speculative acquisition miss must not turn
        // a recoverable asset request into a startup failure.
        failed++;
      } finally {
        ready[asset]!.complete();
      }
    }),
  );
  return BaseCampAssetAcquisitionResult(
    assetCount: unique.length,
    loadedCount: loaded,
    failedCount: failed,
    durationMs: watch.elapsedMilliseconds,
    maxQueueWaitMs: maxQueueWaitMs,
    maxLoadMs: maxLoadMs,
  );
}

class _BaseCampAssetAcquisitionPool {
  _BaseCampAssetAcquisitionPool(this.limit) : assert(limit > 0);

  final int limit;
  int _active = 0;
  final Map<Object, Queue<Future<void> Function()>> _waiting =
      <Object, Queue<Future<void> Function()>>{};
  final Queue<Object> _batchOrder = Queue<Object>();

  Future<T> run<T>(Future<T> Function() action, {required Object batch}) {
    final result = Completer<T>();
    final queue = _waiting.putIfAbsent(batch, () {
      _batchOrder.addLast(batch);
      return Queue<Future<void> Function()>();
    });
    queue.addLast(() async {
      try {
        result.complete(await action());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    _schedule();
    return result.future;
  }

  void _schedule() {
    while (_active < limit && _batchOrder.isNotEmpty) {
      final batch = _batchOrder.removeFirst();
      final queue = _waiting[batch]!;
      final task = queue.removeFirst();
      if (queue.isEmpty) {
        _waiting.remove(batch);
      } else {
        _batchOrder.addLast(batch);
      }
      _active++;
      unawaited(
        task().whenComplete(() {
          _active--;
          _schedule();
        }),
      );
    }
  }
}

const baseCampStatusEntryAsset =
    'assets/images/themes/base_camp/entry/status.jpg';
const baseCampActivityEntryAsset =
    'assets/images/themes/base_camp/entry/activity.jpg';
const baseCampFoodEntryAsset = 'assets/images/themes/base_camp/entry/food.jpg';
const baseCampTrainingEntryAsset =
    'assets/images/themes/base_camp/entry/training.jpg';
const baseCampCommandCenterEntryAsset =
    'assets/images/themes/base_camp/entry/command_center.jpg';

String? baseCampFacilityEntryAssetForId(String facilityId) =>
    switch (facilityId) {
      'status' => baseCampStatusEntryAsset,
      'activity' => baseCampActivityEntryAsset,
      'food' => baseCampFoodEntryAsset,
      'training' => baseCampTrainingEntryAsset,
      'command-center' => baseCampCommandCenterEntryAsset,
      _ => null,
    };

int baseCampFacilityEntryCacheWidth(MediaQueryData mediaQuery) => math
    .max(512, mediaQuery.size.width * mediaQuery.devicePixelRatio)
    .round()
    .clamp(512, 1536);

ImageProvider<Object> baseCampFacilityEntryImageProvider({
  required String asset,
  required int cacheWidth,
}) => ResizeImage.resizeIfNeeded(cacheWidth, null, AssetImage(asset));

/// [precacheImage] reports decode failures through a callback instead of its
/// returned Future. Convert that signal back into an error so readiness gates
/// never treat an undecodable image as successfully prepared.
Future<void> baseCampPrecacheImage(
  ImageProvider<Object> provider,
  BuildContext context,
) async {
  Object? failure;
  StackTrace? failureStack;
  await precacheImage(
    provider,
    context,
    onError: (error, stackTrace) {
      failure = error;
      failureStack = stackTrace;
    },
  );
  final error = failure;
  if (error != null) {
    Error.throwWithStackTrace(error, failureStack ?? StackTrace.current);
  }
}

Future<Map<String, Object?>> baseCampImageCacheFields(
  ImageProvider<Object> provider,
  BuildContext context,
) async {
  try {
    final key = await provider.obtainKey(
      createLocalImageConfiguration(context),
    );
    final status = PaintingBinding.instance.imageCache.statusForKey(key);
    return <String, Object?>{
      'cacheStatusAvailable': true,
      'cacheStatus': status.pending || status.live || status.keepAlive
          ? 'reused'
          : 'miss',
      'cachePending': status.pending,
      'cacheLive': status.live,
      'cacheKeepAlive': status.keepAlive,
      'cacheReused': status.pending || status.live || status.keepAlive,
    };
  } catch (_) {
    return const <String, Object?>{'cacheStatusAvailable': false};
  }
}
