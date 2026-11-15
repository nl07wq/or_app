import 'dart:math' as math;

import 'package:flutter/material.dart';

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
      'cachePending': status.pending,
      'cacheLive': status.live,
      'cacheKeepAlive': status.keepAlive,
      'cacheReused': status.pending || status.live || status.keepAlive,
    };
  } catch (_) {
    return const <String, Object?>{'cacheStatusAvailable': false};
  }
}
