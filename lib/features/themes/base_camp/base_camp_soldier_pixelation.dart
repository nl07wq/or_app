import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/services/device_settings_controller.dart';
import 'base_camp_asset_metrics.dart';

/// One source frame projected into the shared Soldier viewport coordinate
/// system. Every request uses the viewport origin as its pixel-grid origin.
@immutable
class BaseCampSoldierPixelRequest {
  const BaseCampSoldierPixelRequest({
    required this.asset,
    required this.cacheId,
    required this.profileKey,
    required this.viewport,
    required this.targetRect,
    this.devicePixelRatio = 1,
  });

  final String asset;
  final String cacheId;
  final String profileKey;
  final Size viewport;
  final Rect targetRect;
  final double devicePixelRatio;

  BaseCampSoldierPixelRequest withAsset(String nextAsset) =>
      BaseCampSoldierPixelRequest(
        asset: nextAsset,
        cacheId: cacheId,
        profileKey: profileKey,
        viewport: viewport,
        targetRect: targetRect,
        devicePixelRatio: devicePixelRatio,
      );

  /// The level contract is expressed in physical display pixels. Flutter
  /// layout coordinates are logical pixels, so Retina-class displays must
  /// divide the grid pitch by their device-pixel ratio. Treating the
  /// reference as logical pixels made a 11px LV.4 cell 33 physical pixels on
  /// a 3x iPhone display and destroyed the Soldier silhouette.
  double logicalBlockSize(SoldierPixelationLevel level) =>
      level.referenceBlockSize / devicePixelRatio;

  Rect displayRect(SoldierPixelationLevel level) {
    final block = logicalBlockSize(level);
    return Rect.fromLTRB(
      (targetRect.left / block).floor() * block,
      (targetRect.top / block).floor() * block,
      (targetRect.right / block).ceil() * block,
      (targetRect.bottom / block).ceil() * block,
    );
  }

  Size reducedSize(SoldierPixelationLevel level) {
    final rect = displayRect(level);
    final block = logicalBlockSize(level);
    final width = (rect.width / block).round().clamp(1, 1 << 20);
    final height = (rect.height / block).round().clamp(1, 1 << 20);
    return Size(width.toDouble(), height.toDouble());
  }

  String cacheKey(SoldierPixelationLevel level) {
    final reduced = reducedSize(level);
    final rect = displayRect(level);
    return '$cacheId@${reduced.width.toInt()}x${reduced.height.toInt()}'
        ':${rect.left.toStringAsFixed(3)},${rect.top.toStringAsFixed(3)}'
        ':dpr=${devicePixelRatio.toStringAsFixed(3)}';
  }
}

@immutable
class BaseCampSoldierPixelFrame {
  const BaseCampSoldierPixelFrame({
    required this.cacheId,
    required this.image,
    required this.displayRect,
    required this.level,
  });

  final String cacheId;
  final ui.Image image;
  final Rect displayRect;
  final SoldierPixelationLevel level;
}

class _CommittedPixelProfile {
  _CommittedPixelProfile(this.level, this.frames);

  final SoldierPixelationLevel level;
  final Map<String, BaseCampSoldierPixelFrame> frames;
}

/// Single-level, atomic Soldier frame cache. Frames for a new display profile
/// become visible only after the complete breathing and regrip set succeeds.
class BaseCampSoldierPixelCache extends ChangeNotifier {
  BaseCampSoldierPixelCache._();

  static final instance = BaseCampSoldierPixelCache._();

  SoldierPixelationLevel _level = SoldierPixelationLevel.original;
  int _generation = 0;
  final LinkedHashMap<String, _CommittedPixelProfile> _profiles =
      LinkedHashMap<String, _CommittedPixelProfile>();
  String? _preparingKey;
  Future<bool>? _preparation;
  Object? _lastFailure;
  int _processedImageCount = 0;

  @visibleForTesting
  int get processedImageCount => _processedImageCount;

  @visibleForTesting
  int get cachedImageCount => _profiles.values.fold<int>(
    0,
    (total, profile) => total + profile.frames.length,
  );

  @visibleForTesting
  int get cachedProfileCount => _profiles.length;

  @visibleForTesting
  int get cachedPixelCount => _profiles.values.fold<int>(
    0,
    (total, profile) =>
        total +
        profile.frames.values.fold<int>(
          0,
          (pixels, frame) => pixels + frame.image.width * frame.image.height,
        ),
  );

  bool get isPreparing => _preparation != null;
  Object? get lastFailure => _lastFailure;

  BaseCampSoldierPixelFrame? cachedFrame(
    BaseCampSoldierPixelRequest request,
    SoldierPixelationLevel level,
  ) {
    if (_level != level) return null;
    final profile = _profiles['$level|${request.profileKey}'];
    final exact = profile?.frames[request.cacheKey(level)];
    if (exact != null) return exact;
    for (final entry in _profiles.entries.toList().reversed) {
      if (!entry.key.endsWith('|${request.profileKey}')) continue;
      for (final frame in entry.value.frames.values) {
        if (frame.cacheId == request.cacheId) return frame;
      }
    }
    return null;
  }

  void selectLevel(SoldierPixelationLevel level) {
    if (_level == level) return;
    _level = level;
    _generation++;
    _preparingKey = null;
    _preparation = null;
    _lastFailure = null;
    if (level == SoldierPixelationLevel.original) {
      _disposeProfilesAfterFrame(_profiles.values);
      _profiles.clear();
    }
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
    final cacheProfileKey = '$level|$profileKey';
    final committed = _profiles[cacheProfileKey];
    if (committed != null &&
        list.every(
          (request) => committed.frames.containsKey(request.cacheKey(level)),
        )) {
      _profiles.remove(cacheProfileKey);
      _profiles[cacheProfileKey] = committed;
      return Future<bool>.value(true);
    }
    if (_preparingKey == preparationKey && _preparation != null) {
      return _preparation!;
    }
    final generation = ++_generation;
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
    final staged = <String, BaseCampSoldierPixelFrame>{};
    final sources = <String, ui.Image>{};
    try {
      for (final request in requests) {
        if (generation != _generation || level != _level) {
          _disposeFramesNow(staged.values);
          return false;
        }
        final source = sources[request.asset] ??= await _loadSource(
          request.asset,
        );
        staged[request.cacheKey(level)] = await _process(
          request,
          level,
          source,
        );
      }
      if (generation != _generation || level != _level) {
        _disposeFramesNow(staged.values);
        return false;
      }
      final cacheProfileKey = '$level|$profileKey';
      final obsolete = _profiles.remove(cacheProfileKey);
      _profiles[cacheProfileKey] = _CommittedPixelProfile(level, staged);
      if (obsolete != null) _disposeProfileAfterFrame(obsolete);
      while (_profiles.length > 2) {
        final evictedKey = _profiles.keys.first;
        final evicted = _profiles.remove(evictedKey)!;
        _disposeProfileAfterFrame(evicted);
      }
      _processedImageCount += staged.length;
      _lastFailure = null;
      return true;
    } catch (error) {
      _disposeFramesNow(staged.values);
      if (generation == _generation && level == _level) {
        _lastFailure = error;
      }
      return false;
    } finally {
      for (final source in sources.values) {
        source.dispose();
      }
      if (generation == _generation) {
        _preparingKey = null;
        _preparation = null;
        notifyListeners();
      }
    }
  }

  Future<BaseCampSoldierPixelFrame> _process(
    BaseCampSoldierPixelRequest request,
    SoldierPixelationLevel level,
    ui.Image source,
  ) async {
    final reducedSize = request.reducedSize(level);
    final displayRect = request.displayRect(level);
    final block = request.logicalBlockSize(level);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final sourceRect = Rect.fromLTWH(
      0,
      0,
      source.width.toDouble(),
      source.height.toDouble(),
    );
    final target = Rect.fromLTWH(
      (request.targetRect.left - displayRect.left) / block,
      (request.targetRect.top - displayRect.top) / block,
      request.targetRect.width / block,
      request.targetRect.height / block,
    );
    canvas.drawImageRect(
      source,
      sourceRect,
      target,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
    final image = await recorder.endRecording().toImage(
      reducedSize.width.toInt(),
      reducedSize.height.toInt(),
    );
    return BaseCampSoldierPixelFrame(
      cacheId: request.cacheId,
      image: image,
      displayRect: displayRect,
      level: level,
    );
  }

  Future<ui.Image> _loadSource(String asset) {
    final completer = Completer<ui.Image>();
    final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info.image.clone());
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  void _disposeProfileAfterFrame(_CommittedPixelProfile profile) =>
      _disposeFramesAfterFrame(profile.frames.values);

  void _disposeProfilesAfterFrame(Iterable<_CommittedPixelProfile> profiles) =>
      _disposeFramesAfterFrame(
        profiles.expand((profile) => profile.frames.values),
      );

  void _disposeFramesAfterFrame(Iterable<BaseCampSoldierPixelFrame> frames) {
    final obsolete = frames.toList(growable: false);
    if (obsolete.isEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _disposeFramesNow(obsolete);
    });
  }

  void _disposeFramesNow(Iterable<BaseCampSoldierPixelFrame> frames) {
    for (final frame in frames) {
      frame.image.dispose();
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _generation++;
    _preparingKey = null;
    _preparation = null;
    _disposeProfilesAfterFrame(_profiles.values);
    _profiles.clear();
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
    this.originalRect,
    this.originalOffset = Offset.zero,
  });

  final BaseCampSoldierPixelRequest request;
  final BoxFit fit;
  final Rect? originalRect;
  final Offset originalOffset;

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
          final frame = BaseCampSoldierPixelCache.instance.cachedFrame(
            request,
            level,
          );
          return frame == null ? _original() : _render(frame);
        },
      );
    },
  );

  Widget _original() {
    final image = Image.asset(
      request.asset,
      fit: fit,
      filterQuality: FilterQuality.none,
      frameBuilder: (context, child, frame, synchronous) {
        if (frame != null || synchronous) {
          recordBaseCampAssetReady(request.asset);
        }
        return child;
      },
    );
    final rect = originalRect;
    final positioned = rect == null
        ? image
        : Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: <Widget>[Positioned.fromRect(rect: rect, child: image)],
          );
    return originalOffset == Offset.zero
        ? positioned
        : Transform.translate(offset: originalOffset, child: positioned);
  }

  Widget _render(BaseCampSoldierPixelFrame frame) {
    recordBaseCampAssetReady(request.asset);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        Positioned.fromRect(
          rect: frame.displayRect,
          child: RawImage(
            key: ValueKey<String>(
              'soldier-pixelated-${frame.level.name}-${request.asset}',
            ),
            image: frame.image,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
        ),
      ],
    );
  }
}
