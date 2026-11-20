import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/services/device_settings_controller.dart';
import 'base_camp_asset_metrics.dart';

enum BaseCampSoldierMotion { breathing, regrip }

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

  BaseCampSoldierMotion get motion => cacheId.startsWith('regrip-frame-')
      ? BaseCampSoldierMotion.regrip
      : BaseCampSoldierMotion.breathing;

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
  _CommittedPixelProfile(this.motion, this.level, this.frames);

  final BaseCampSoldierMotion motion;
  final SoldierPixelationLevel level;
  final Map<String, BaseCampSoldierPixelFrame> frames;
}

/// Motion-specific atomic Soldier frame cache. A new breathing or regrip
/// profile becomes visible only after that motion's complete frame set
/// succeeds. Preparing one motion never invalidates the other.
class BaseCampSoldierPixelCache extends ChangeNotifier {
  BaseCampSoldierPixelCache._();

  static final instance = BaseCampSoldierPixelCache._();

  final Map<BaseCampSoldierMotion, SoldierPixelationLevel> _levels = {
    for (final motion in BaseCampSoldierMotion.values)
      motion: SoldierPixelationLevel.original,
  };
  final Map<BaseCampSoldierMotion, int> _generations = {
    for (final motion in BaseCampSoldierMotion.values) motion: 0,
  };
  final LinkedHashMap<String, _CommittedPixelProfile> _profiles =
      LinkedHashMap<String, _CommittedPixelProfile>();
  final Map<BaseCampSoldierMotion, String?> _preparingKeys = {
    for (final motion in BaseCampSoldierMotion.values) motion: null,
  };
  final Map<BaseCampSoldierMotion, Future<bool>?> _preparations = {
    for (final motion in BaseCampSoldierMotion.values) motion: null,
  };
  final Map<BaseCampSoldierMotion, Object?> _failures = {
    for (final motion in BaseCampSoldierMotion.values) motion: null,
  };
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

  bool get isPreparing => _preparations.values.any((value) => value != null);
  Object? get lastFailure => _failures.values.whereType<Object>().firstOrNull;

  bool isPreparingMotion(BaseCampSoldierMotion motion) =>
      _preparations[motion] != null;

  Object? failureFor(BaseCampSoldierMotion motion) => _failures[motion];

  SoldierPixelationLevel selectedLevelFor(BaseCampSoldierMotion motion) =>
      _levels[motion]!;

  BaseCampSoldierPixelFrame? cachedFrame(
    BaseCampSoldierPixelRequest request,
    SoldierPixelationLevel level,
  ) {
    final motion = request.motion;
    if (_levels[motion] != level) return null;
    final profile = _profiles['${motion.name}|$level|${request.profileKey}'];
    final exact = profile?.frames[request.cacheKey(level)];
    if (exact != null) return exact;
    for (final entry in _profiles.entries.toList().reversed) {
      if (entry.value.motion != motion ||
          !entry.key.endsWith('|${request.profileKey}')) {
        continue;
      }
      for (final frame in entry.value.frames.values) {
        if (frame.cacheId == request.cacheId) return frame;
      }
    }
    return null;
  }

  void selectLevel(SoldierPixelationLevel level) {
    for (final motion in BaseCampSoldierMotion.values) {
      selectMotionLevel(motion, level);
    }
  }

  void selectMotionLevel(
    BaseCampSoldierMotion motion,
    SoldierPixelationLevel level,
  ) {
    if (_levels[motion] == level) return;
    _levels[motion] = level;
    _generations[motion] = _generations[motion]! + 1;
    _preparingKeys[motion] = null;
    _preparations[motion] = null;
    _failures[motion] = null;
    if (level == SoldierPixelationLevel.original) {
      final obsoleteKeys = _profiles.entries
          .where((entry) => entry.value.motion == motion)
          .map((entry) => entry.key)
          .toList(growable: false);
      for (final key in obsoleteKeys) {
        _disposeProfileAfterFrame(_profiles.remove(key)!);
      }
    }
  }

  /// Stages a complete profile and commits it atomically. A failure leaves the
  /// released ORIGINAL frames visible and is exposed through [lastFailure].
  Future<bool> prepareRequests(
    Iterable<BaseCampSoldierPixelRequest> requests,
    SoldierPixelationLevel level,
  ) {
    final list = requests.toList(growable: false);
    if (list.isEmpty) return Future<bool>.value(false);
    final grouped =
        <BaseCampSoldierMotion, List<BaseCampSoldierPixelRequest>>{};
    for (final request in list) {
      grouped.putIfAbsent(request.motion, () => []).add(request);
    }
    return Future.wait<bool>([
      for (final entry in grouped.entries)
        prepareMotionRequests(entry.value, entry.key, level),
    ]).then((results) => results.every((result) => result));
  }

  Future<bool> prepareMotionRequests(
    Iterable<BaseCampSoldierPixelRequest> requests,
    BaseCampSoldierMotion motion,
    SoldierPixelationLevel level,
  ) {
    final list = requests.toList(growable: false);
    if (level == SoldierPixelationLevel.original) {
      selectMotionLevel(motion, level);
      return Future<bool>.value(true);
    }
    if (list.isEmpty) return Future<bool>.value(false);
    final profileKey = list.first.profileKey;
    if (list.any(
      (request) => request.profileKey != profileKey || request.motion != motion,
    )) {
      throw ArgumentError(
        'Soldier pixel requests must share one motion and profile',
      );
    }
    selectMotionLevel(motion, level);
    final preparationKey = '${motion.name}|$level|$profileKey';
    final cacheProfileKey = preparationKey;
    final committed = _profiles[cacheProfileKey];
    if (committed != null &&
        list.every(
          (request) => committed.frames.containsKey(request.cacheKey(level)),
        )) {
      _profiles.remove(cacheProfileKey);
      _profiles[cacheProfileKey] = committed;
      return Future<bool>.value(true);
    }
    if (_preparingKeys[motion] == preparationKey &&
        _preparations[motion] != null) {
      return _preparations[motion]!;
    }
    final generation = _generations[motion]! + 1;
    _generations[motion] = generation;
    _preparingKeys[motion] = preparationKey;
    _failures[motion] = null;
    notifyListeners();
    final operation = _prepare(list, motion, level, profileKey, generation);
    _preparations[motion] = operation;
    return operation;
  }

  Future<bool> _prepare(
    List<BaseCampSoldierPixelRequest> requests,
    BaseCampSoldierMotion motion,
    SoldierPixelationLevel level,
    String profileKey,
    int generation,
  ) async {
    final staged = <String, BaseCampSoldierPixelFrame>{};
    final sources = <String, ui.Image>{};
    try {
      for (final request in requests) {
        if (generation != _generations[motion] || level != _levels[motion]) {
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
      if (generation != _generations[motion] || level != _levels[motion]) {
        _disposeFramesNow(staged.values);
        return false;
      }
      final cacheProfileKey = '${motion.name}|$level|$profileKey';
      final obsoleteKeys = _profiles.entries
          .where(
            (entry) =>
                entry.value.motion == motion &&
                entry.key.endsWith('|$profileKey'),
          )
          .map((entry) => entry.key)
          .toList(growable: false);
      final obsolete = <_CommittedPixelProfile>[
        for (final key in obsoleteKeys) _profiles.remove(key)!,
      ];
      _profiles[cacheProfileKey] = _CommittedPixelProfile(
        motion,
        level,
        staged,
      );
      _disposeProfilesAfterFrame(obsolete);
      while (_profiles.length > 4) {
        final evictedKey = _profiles.keys.first;
        final evicted = _profiles.remove(evictedKey)!;
        _disposeProfileAfterFrame(evicted);
      }
      _processedImageCount += staged.length;
      _failures[motion] = null;
      return true;
    } catch (error) {
      _disposeFramesNow(staged.values);
      if (generation == _generations[motion] && level == _levels[motion]) {
        _failures[motion] = error;
      }
      return false;
    } finally {
      for (final source in sources.values) {
        source.dispose();
      }
      if (generation == _generations[motion]) {
        _preparingKeys[motion] = null;
        _preparations[motion] = null;
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
    for (final motion in BaseCampSoldierMotion.values) {
      _generations[motion] = _generations[motion]! + 1;
      _preparingKeys[motion] = null;
      _preparations[motion] = null;
      _failures[motion] = null;
      _levels[motion] = SoldierPixelationLevel.original;
    }
    _disposeProfilesAfterFrame(_profiles.values);
    _profiles.clear();
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
      final motion = request.motion;
      final level = switch (motion) {
        BaseCampSoldierMotion.breathing => settings.breathingPixelLevel,
        BaseCampSoldierMotion.regrip => settings.regripPixelLevel,
      };
      if (level == SoldierPixelationLevel.original) {
        BaseCampSoldierPixelCache.instance.selectMotionLevel(motion, level);
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
    final positioned = Stack(
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
    return originalOffset == Offset.zero
        ? positioned
        : Transform.translate(offset: originalOffset, child: positioned);
  }
}
