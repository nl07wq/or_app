import 'dart:async';
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
  });

  final int assetCount;
  final int loadedCount;
  final int failedCount;
  final int durationMs;
}

/// Acquires compressed asset bytes ahead of image decoding without allowing
/// the 24 WATER and 25 WALKER requests to fan out without a bound. The image
/// providers still own decoding and ImageCache insertion; this stage only
/// removes the accidental request/decode/request/decode serialization seen on
/// delayed Safari reopens.
Future<BaseCampAssetAcquisitionResult> baseCampAcquireAssetBytes(
  Iterable<String> assets, {
  @visibleForTesting Future<ByteData> Function(String asset)? loader,
}) async {
  final unique = assets.toSet().toList(growable: false);
  final watch = Stopwatch()..start();
  var loaded = 0;
  var failed = 0;
  final load = loader ?? rootBundle.load;
  await Future.wait(
    unique.map((asset) async {
      try {
        await _baseCampAssetAcquisitionPool.run(() => load(asset));
        loaded++;
      } catch (_) {
        // The normal ImageProvider path remains the authoritative load and
        // reports its own error. A speculative acquisition miss must not turn
        // a recoverable asset request into a startup failure.
        failed++;
      }
    }),
  );
  return BaseCampAssetAcquisitionResult(
    assetCount: unique.length,
    loadedCount: loaded,
    failedCount: failed,
    durationMs: watch.elapsedMilliseconds,
  );
}

class _BaseCampAssetAcquisitionPool {
  _BaseCampAssetAcquisitionPool(this.limit) : assert(limit > 0);

  final int limit;
  int _active = 0;
  final List<Completer<void>> _waiting = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() action) async {
    if (_active >= limit) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _active++;
    try {
      return await action();
    } finally {
      _active--;
      if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
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
