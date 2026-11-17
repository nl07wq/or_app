import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/services/device_settings_controller.dart';
import 'base_camp_asset_metrics.dart';

/// One source frame plus its scale relative to the BREATHING source-to-screen
/// scale. Reduced raster dimensions are derived from the final drawing scale.
@immutable
class BaseCampSoldierPixelRequest {
  const BaseCampSoldierPixelRequest({
    required this.asset,
    required this.profileKey,
    this.screenScaleX = 1,
    this.screenScaleY = 1,
    this.sourceSize,
  });

  final String asset;
  final String profileKey;
  final double screenScaleX;
  final double screenScaleY;
  final Size? sourceSize;

  BaseCampSoldierPixelRequest withAsset(String nextAsset) =>
      BaseCampSoldierPixelRequest(
        asset: nextAsset,
        profileKey: profileKey,
        screenScaleX: screenScaleX,
        screenScaleY: screenScaleY,
        sourceSize:
            sourceSize ??
            Size(
              baseCampAssetMetrics[asset]!.width.toDouble(),
              baseCampAssetMetrics[asset]!.height.toDouble(),
            ),
      );

  Size reducedSize(SoldierPixelationLevel level) {
    final metric = baseCampAssetMetrics[asset];
    final widthPx = sourceSize?.width.toInt() ?? metric?.width;
    final heightPx = sourceSize?.height.toInt() ?? metric?.height;
    if (widthPx == null || heightPx == null) {
      throw StateError('Missing Soldier asset metric: $asset');
    }
    final width = (widthPx * screenScaleX / level.referenceBlockSize)
        .ceil()
        .clamp(1, widthPx);
    final height = (heightPx * screenScaleY / level.referenceBlockSize)
        .ceil()
        .clamp(1, heightPx);
    return Size(width.toDouble(), height.toDouble());
  }

  String cacheKey(SoldierPixelationLevel level) {
    final reduced = reducedSize(level);
    return '$asset@${reduced.width.toInt()}x${reduced.height.toInt()}';
  }
}

/// Single-level, atomic Soldier frame cache. Frames for a new display profile
/// become visible only after the complete breathing and regrip set succeeds.
class BaseCampSoldierPixelCache extends ChangeNotifier {
  BaseCampSoldierPixelCache._();

  static final instance = BaseCampSoldierPixelCache._();

  SoldierPixelationLevel _level = SoldierPixelationLevel.original;
  int _generation = 0;
  Map<String, ui.Image> _images = <String, ui.Image>{};
  String? _committedProfileKey;
  String? _preparingKey;
  Future<bool>? _preparation;
  Object? _lastFailure;
  int _processedImageCount = 0;

  @visibleForTesting
  int get processedImageCount => _processedImageCount;

  @visibleForTesting
  int get cachedImageCount => _images.length;

  bool get isPreparing => _preparation != null;
  Object? get lastFailure => _lastFailure;

  ui.Image? cachedImage(
    BaseCampSoldierPixelRequest request,
    SoldierPixelationLevel level,
  ) {
    if (_level != level || _committedProfileKey != request.profileKey) {
      return null;
    }
    return _images[request.cacheKey(level)];
  }

  void selectLevel(SoldierPixelationLevel level) {
    if (_level == level) return;
    _level = level;
    _generation++;
    _preparingKey = null;
    _preparation = null;
    _lastFailure = null;
    _committedProfileKey = null;
    _disposeAfterFrame(_images.values);
    _images = <String, ui.Image>{};
  }

  /// Stages a complete profile and commits it atomically. A failure leaves the
  /// released ORIGINAL frames visible and is exposed through [lastFailure].
  Future<bool> prepareRequests(
    Iterable<BaseCampSoldierPixelRequest> requests,
    SoldierPixelationLevel level,
  ) {
    final list = requests.toList(growable: false);
    if (level == SoldierPixelationLevel.original) {
      selectLevel(level);
      return Future<bool>.value(true);
    }
    if (list.isEmpty) return Future<bool>.value(false);
    final profileKey = list.first.profileKey;
    if (list.any((request) => request.profileKey != profileKey)) {
      throw ArgumentError('Soldier pixel requests must share one profile');
    }
    selectLevel(level);
    final preparationKey = '$level|$profileKey';
    if (_committedProfileKey == profileKey &&
        list.every((request) => _images.containsKey(request.cacheKey(level)))) {
      return Future<bool>.value(true);
    }
    if (_preparingKey == preparationKey && _preparation != null) {
      return _preparation!;
    }
    final generation = ++_generation;
    if (_committedProfileKey != profileKey) {
      _disposeAfterFrame(_images.values);
      _images = <String, ui.Image>{};
      _committedProfileKey = null;
    }
    _preparingKey = preparationKey;
    _lastFailure = null;
    notifyListeners();
    final operation = _prepare(list, level, profileKey, generation);
    _preparation = operation;
    return operation;
  }

  Future<bool> _prepare(
    List<BaseCampSoldierPixelRequest> requests,
    SoldierPixelationLevel level,
    String profileKey,
    int generation,
  ) async {
    final staged = <String, ui.Image>{};
    try {
      for (final request in requests) {
        if (generation != _generation || level != _level) {
          _disposeNow(staged.values);
          return false;
        }
        staged[request.cacheKey(level)] = await _process(request, level);
      }
      if (generation != _generation || level != _level) {
        _disposeNow(staged.values);
        return false;
      }
      final obsolete = _images.values;
      _images = staged;
      _committedProfileKey = profileKey;
      _processedImageCount += staged.length;
      _lastFailure = null;
      _disposeAfterFrame(obsolete);
      return true;
    } catch (error) {
      _disposeNow(staged.values);
      if (generation == _generation && level == _level) {
        _lastFailure = error;
        _committedProfileKey = null;
        _disposeAfterFrame(_images.values);
        _images = <String, ui.Image>{};
      }
      return false;
    } finally {
      if (generation == _generation) {
        _preparingKey = null;
        _preparation = null;
        notifyListeners();
      }
    }
  }

  Future<ui.Image> _process(
    BaseCampSoldierPixelRequest request,
    SoldierPixelationLevel level,
  ) async {
    final data = await rootBundle.load(request.asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final source = frame.image;
    ui.Image? reduced;
    try {
      final reducedSize = request.reducedSize(level);
      reduced = await _resizeNearest(
        source,
        reducedSize.width.toInt(),
        reducedSize.height.toInt(),
      );
      return await _resizeNearest(reduced, source.width, source.height);
    } finally {
      reduced?.dispose();
      source.dispose();
    }
  }

  Future<ui.Image> _resizeNearest(ui.Image source, int width, int height) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final sourceRect = Rect.fromLTWH(
      0,
      0,
      source.width.toDouble(),
      source.height.toDouble(),
    );
    final targetRect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    canvas.drawImageRect(
      source,
      sourceRect,
      targetRect,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
    return recorder.endRecording().toImage(width, height);
  }

  void _disposeAfterFrame(Iterable<ui.Image> images) {
    final obsolete = images.toList(growable: false);
    if (obsolete.isEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _disposeNow(obsolete);
    });
  }

  void _disposeNow(Iterable<ui.Image> images) {
    for (final image in images) {
      image.dispose();
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _generation++;
    _preparingKey = null;
    _preparation = null;
    _disposeNow(_images.values);
    _images = <String, ui.Image>{};
    _committedProfileKey = null;
    _lastFailure = null;
    _level = SoldierPixelationLevel.original;
    _processedImageCount = 0;
    notifyListeners();
  }
}

/// Shared renderer for BREATHING and TRIGGER REGRIP. A processed frame is used
/// only when its complete screen-space profile has been committed.
class BaseCampSoldierAssetImage extends StatelessWidget {
  const BaseCampSoldierAssetImage({
    super.key,
    required this.request,
    required this.fit,
  });

  final BaseCampSoldierPixelRequest request;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DeviceSettings>(
    valueListenable: DeviceSettingsController.instance,
    builder: (context, settings, _) {
      final level = settings.soldierPixelationLevel;
      if (level == SoldierPixelationLevel.original) {
        BaseCampSoldierPixelCache.instance.selectLevel(level);
        return _original();
      }
      return ListenableBuilder(
        listenable: BaseCampSoldierPixelCache.instance,
        builder: (context, _) {
          final image = BaseCampSoldierPixelCache.instance.cachedImage(
            request,
            level,
          );
          return image == null ? _original() : _render(image, level);
        },
      );
    },
  );

  Widget _original() => Image.asset(
    request.asset,
    fit: fit,
    filterQuality: FilterQuality.none,
    frameBuilder: (context, child, frame, synchronous) {
      if (frame != null || synchronous) recordBaseCampAssetReady(request.asset);
      return child;
    },
  );

  Widget _render(ui.Image image, SoldierPixelationLevel level) {
    recordBaseCampAssetReady(request.asset);
    return RawImage(
      key: ValueKey<String>('soldier-pixelated-${level.name}-${request.asset}'),
      image: image,
      fit: fit,
      filterQuality: FilterQuality.none,
    );
  }
}
