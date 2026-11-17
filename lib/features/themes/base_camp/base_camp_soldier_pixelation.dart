import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/services/device_settings_controller.dart';
import 'base_camp_asset_metrics.dart';

/// Single-level, lazy Soldier frame cache. Only assets requested by the active
/// level are processed; animation ticks reuse the resulting [ui.Image].
class BaseCampSoldierPixelCache {
  BaseCampSoldierPixelCache._();

  static final instance = BaseCampSoldierPixelCache._();

  SoldierPixelationLevel _level = SoldierPixelationLevel.original;
  int _generation = 0;
  final Map<String, Future<ui.Image>> _pending = <String, Future<ui.Image>>{};
  final Map<String, ui.Image> _images = <String, ui.Image>{};
  int _processedImageCount = 0;

  @visibleForTesting
  int get processedImageCount => _processedImageCount;

  @visibleForTesting
  int get cachedImageCount => _images.length;

  ui.Image? cachedImage(String asset, SoldierPixelationLevel level) =>
      _level == level ? _images[asset] : null;

  void selectLevel(SoldierPixelationLevel level) {
    if (_level == level) return;
    _level = level;
    _generation++;
    _pending.clear();
    final obsolete = _images.values.toList(growable: false);
    _images.clear();
    if (obsolete.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final image in obsolete) {
          image.dispose();
        }
      });
    }
  }

  Future<ui.Image> imageFor(String asset, SoldierPixelationLevel level) {
    assert(level != SoldierPixelationLevel.original);
    selectLevel(level);
    return _pending.putIfAbsent(
      asset,
      () => _process(asset, level, _generation),
    );
  }

  /// Warms only the active level, sequentially, after the released Soldier
  /// assets are ready. A failed frame retains the original asset fallback.
  Future<void> prepareAssets(
    Iterable<String> assets,
    SoldierPixelationLevel level,
  ) async {
    if (level == SoldierPixelationLevel.original) {
      selectLevel(level);
      return;
    }
    selectLevel(level);
    for (final asset in assets) {
      if (_level != level) return;
      try {
        await imageFor(asset, level);
      } catch (_) {
        // The renderer intentionally keeps the released original visible.
      }
    }
  }

  Future<ui.Image> _process(
    String asset,
    SoldierPixelationLevel level,
    int generation,
  ) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final source = frame.image;
    ui.Image? reduced;
    try {
      final reducedWidth = (source.width * level.scale).round().clamp(
        1,
        source.width,
      );
      final reducedHeight = (source.height * level.scale).round().clamp(
        1,
        source.height,
      );
      reduced = await _resizeNearest(source, reducedWidth, reducedHeight);
      final result = await _resizeNearest(reduced, source.width, source.height);
      if (generation != _generation || level != _level) {
        result.dispose();
        throw StateError('Discarded obsolete Soldier pixelation result');
      }
      _images[asset] = result;
      _processedImageCount++;
      return result;
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

  @visibleForTesting
  void resetForTesting() {
    _generation++;
    _pending.clear();
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _level = SoldierPixelationLevel.original;
    _processedImageCount = 0;
  }
}

/// Asset renderer shared by BREATHING and TRIGGER REGRIP. Original mode keeps
/// the released [Image.asset] path; selected developer levels lazily replace it
/// with one cached, full-canvas pixelated image without blocking startup.
class BaseCampSoldierAssetImage extends StatelessWidget {
  const BaseCampSoldierAssetImage({
    super.key,
    required this.asset,
    required this.fit,
  });

  final String asset;
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
      return _PixelatedSoldierAsset(
        key: ValueKey<String>('soldier-pixel-${level.name}-$asset'),
        asset: asset,
        fit: fit,
        level: level,
      );
    },
  );

  Widget _original() => Image.asset(
    asset,
    fit: fit,
    filterQuality: FilterQuality.none,
    frameBuilder: (context, child, frame, synchronous) {
      if (frame != null || synchronous) recordBaseCampAssetReady(asset);
      return child;
    },
  );
}

class _PixelatedSoldierAsset extends StatefulWidget {
  const _PixelatedSoldierAsset({
    super.key,
    required this.asset,
    required this.fit,
    required this.level,
  });

  final String asset;
  final BoxFit fit;
  final SoldierPixelationLevel level;

  @override
  State<_PixelatedSoldierAsset> createState() => _PixelatedSoldierAssetState();
}

class _PixelatedSoldierAssetState extends State<_PixelatedSoldierAsset> {
  late final Future<ui.Image> _image = BaseCampSoldierPixelCache.instance
      .imageFor(widget.asset, widget.level);

  @override
  Widget build(BuildContext context) {
    final cached = BaseCampSoldierPixelCache.instance.cachedImage(
      widget.asset,
      widget.level,
    );
    if (cached != null) return _render(cached);
    return FutureBuilder<ui.Image>(
      future: _image,
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) {
          return Image.asset(
            widget.asset,
            fit: widget.fit,
            filterQuality: FilterQuality.none,
          );
        }
        return _render(image);
      },
    );
  }

  Widget _render(ui.Image image) {
    recordBaseCampAssetReady(widget.asset);
    return RawImage(
      key: ValueKey<String>(
        'soldier-pixelated-${widget.level.name}-${widget.asset}',
      ),
      image: image,
      fit: widget.fit,
      filterQuality: FilterQuality.none,
    );
  }
}
