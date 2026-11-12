import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'base_camp_asset_metrics.dart';

const baseCampBreathingSoldierLowerAsset =
    'assets/images/themes/base_camp/breathing_soldier/gasmask_lowerboady.png';
const baseCampBreathingSoldierUpperAsset =
    'assets/images/themes/base_camp/breathing_soldier/gasmask_upperboady.png';

const baseCampRifleRegripSourceAssets = <String>[
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_F0.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_F1.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_F2.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_F3.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_F4.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_F5.png',
];

const baseCampRifleRegripAssets = <String>[
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F0.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F1.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F2.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F3.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F4.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F5.png',
];

const baseCampApprovedRifleGlobalX = -0.9999618530273438;
const baseCampApprovedRifleGlobalY = -1.3513513513514113;
const baseCampApprovedRifleGlobalScale = 0.9617116773450697;
const baseCampApprovedRifleFrameOffsets = <Offset>[
  Offset(-13.5, 46.5),
  Offset(-14, 47),
  Offset(-30.5, 46),
  Offset(-13.5, 25.5),
  Offset(-13, 44.5),
  Offset(-20, 46),
];
const baseCampApprovedRifleFrameScales = <double>[
  1.15,
  1.15,
  1.15,
  1.15,
  1.20,
  1.20,
];

@immutable
class BaseCampRifleGlobalAlignment {
  const BaseCampRifleGlobalAlignment({
    this.x = baseCampApprovedRifleGlobalX,
    this.y = baseCampApprovedRifleGlobalY,
    this.scale = baseCampApprovedRifleGlobalScale,
    this.verticalScaleX = 1,
    this.horizontalScaleY = 1,
    this.frameOffsets = baseCampApprovedRifleFrameOffsets,
    this.frameScales = baseCampApprovedRifleFrameScales,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.warmth = 0,
    this.frameDurationsMs = baseCampRifleRegripFrameDurations,
  });

  final double x;
  final double y;
  final double scale;
  final double verticalScaleX;
  final double horizontalScaleY;
  final List<Offset> frameOffsets;
  final List<double> frameScales;
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;
  final List<int> frameDurationsMs;

  int get eventDurationMs =>
      baseCampRifleRegripEventDurationMs(frameDurationsMs);

  BaseCampRifleGlobalAlignment copyWith({
    double? x,
    double? y,
    double? scale,
    double? verticalScaleX,
    double? horizontalScaleY,
    List<Offset>? frameOffsets,
    List<double>? frameScales,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
    List<int>? frameDurationsMs,
  }) => BaseCampRifleGlobalAlignment(
    x: x ?? this.x,
    y: y ?? this.y,
    scale: scale ?? this.scale,
    verticalScaleX: verticalScaleX ?? this.verticalScaleX,
    horizontalScaleY: horizontalScaleY ?? this.horizontalScaleY,
    frameOffsets: frameOffsets ?? this.frameOffsets,
    frameScales: frameScales ?? this.frameScales,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    warmth: warmth ?? this.warmth,
    frameDurationsMs: frameDurationsMs ?? this.frameDurationsMs,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 'soldier_alignment_v2',
    'reference': 'breathing_soldier',
    'target': 'rifle_regrip',
    'sourceCanvasPx': <int>[512, 512],
    'drawingAnchor': 'normal_visible_foot_center',
    'frameOffsetsPx': <Object?>[
      for (var frame = 0; frame < frameOffsets.length; frame++)
        <String, Object?>{
          'frame': frame,
          'x': frameOffsets[frame].dx,
          'y': frameOffsets[frame].dy,
          'scale': frameScales[frame],
        },
    ],
    'alignment': <String, double>{
      'offsetXdp': x,
      'offsetYdp': y,
      'scale': scale,
      'scaleXVertical': verticalScaleX,
      'scaleYHorizontal': horizontalScaleY,
    },
    'color': <String, double>{
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'warmth': warmth,
    },
    'frameDurationsMs': frameDurationsMs,
  };

  factory BaseCampRifleGlobalAlignment.fromJson(Object? source) {
    if (source is! Map ||
        source['schema'] != 'soldier_alignment_v2' ||
        source['drawingAnchor'] != 'normal_visible_foot_center') {
      throw const FormatException('Unsupported soldier alignment');
    }
    final alignment = source['alignment'];
    final frames = source['frameOffsetsPx'];
    final color = source['color'];
    final durations = source['frameDurationsMs'];
    if (alignment is! Map ||
        frames is! List ||
        frames.length != 6 ||
        durations is! List ||
        durations.length != 6) {
      throw const FormatException('Incomplete soldier alignment');
    }
    double number(Object? value) {
      if (value is! num || !value.toDouble().isFinite) {
        throw const FormatException('Invalid number');
      }
      return value.toDouble();
    }

    final offsets = <Offset>[];
    final scales = <double>[];
    for (var index = 0; index < frames.length; index++) {
      final frame = frames[index];
      if (frame is! Map || frame['frame'] != index) {
        throw const FormatException('Invalid frame');
      }
      offsets.add(Offset(number(frame['x']), number(frame['y'])));
      scales.add(number(frame['scale']));
    }
    final parsedDurations = durations
        .map((value) {
          if (value is! num || value.toInt() <= 0 || value.toInt() > 10000) {
            throw const FormatException('Invalid duration');
          }
          return value.toInt();
        })
        .toList(growable: false);
    final parsed = BaseCampRifleGlobalAlignment(
      x: number(alignment['offsetXdp']),
      y: number(alignment['offsetYdp']),
      scale: number(alignment['scale']),
      // These fields were added without changing the v2 schema. Old v2 JSON
      // intentionally retains the exact old rendering at the 1.0 defaults.
      verticalScaleX: alignment['scaleXVertical'] == null
          ? 1
          : number(alignment['scaleXVertical']),
      horizontalScaleY: alignment['scaleYHorizontal'] == null
          ? 1
          : number(alignment['scaleYHorizontal']),
      frameOffsets: List<Offset>.unmodifiable(offsets),
      frameScales: List<double>.unmodifiable(scales),
      brightness: color is Map && color['brightness'] != null
          ? number(color['brightness'])
          : 0,
      contrast: color is Map && color['contrast'] != null
          ? number(color['contrast'])
          : 1,
      saturation: color is Map && color['saturation'] != null
          ? number(color['saturation'])
          : 1,
      warmth: color is Map && color['warmth'] != null
          ? number(color['warmth'])
          : 0,
      frameDurationsMs: List<int>.unmodifiable(parsedDurations),
    );
    if (parsed.x.abs() > 100 ||
        parsed.y.abs() > 100 ||
        parsed.scale < .5 ||
        parsed.scale > 1.5 ||
        parsed.verticalScaleX < .5 ||
        parsed.verticalScaleX > 1.5 ||
        parsed.horizontalScaleY < .5 ||
        parsed.horizontalScaleY > 1.5 ||
        parsed.frameScales.any((value) => value < .5 || value > 2)) {
      throw const FormatException('Soldier alignment outside limits');
    }
    return parsed;
  }
}

class BaseCampRifleAlignmentController
    extends ValueNotifier<BaseCampRifleGlobalAlignment> {
  BaseCampRifleAlignmentController({
    Future<SharedPreferences> Function()? preferencesLoader,
    Future<bool> Function(SharedPreferences, String, String)? storageWriter,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _storageWriter =
           storageWriter ??
           ((preferences, key, value) => preferences.setString(key, value)),
       super(const BaseCampRifleGlobalAlignment());

  static const storageKey = 'base_camp.soldier_alignment.v2';
  final Future<SharedPreferences> Function() _preferencesLoader;
  final Future<bool> Function(SharedPreferences, String, String) _storageWriter;
  Future<void>? _loadOperation;
  bool _loaded = false;

  Future<void> load() => _loadOperation ??= _load();

  Future<void> _load() async {
    final raw = (await _preferencesLoader()).getString(storageKey);
    if (raw != null) {
      try {
        value = BaseCampRifleGlobalAlignment.fromJson(jsonDecode(raw));
      } on FormatException {
        // A corrupt value is never replaced automatically. The approved
        // preset remains usable until the user explicitly applies/reset it.
      }
    }
    _loaded = true;
  }

  Future<void> save(BaseCampRifleGlobalAlignment next) async {
    final encoded = jsonEncode(next.toJson());
    final preferences = await _preferencesLoader();
    final saved = await _storageWriter(preferences, storageKey, encoded);
    if (!saved || preferences.getString(storageKey) != encoded) {
      throw StateError('Soldier alignment persistence failed');
    }
    value = next;
    _loaded = true;
  }

  bool get isLoaded => _loaded;

  @visibleForTesting
  void resetForTesting([
    BaseCampRifleGlobalAlignment next = const BaseCampRifleGlobalAlignment(),
  ]) {
    value = next;
    _loaded = false;
    _loadOperation = null;
  }
}

/// The single production source used by Preview and Dashboard. Loading never
/// writes the new preset, so an existing user alignment always wins.
final baseCampRifleGlobalAlignment = BaseCampRifleAlignmentController();

@immutable
class BaseCampRifleRegripLayout {
  const BaseCampRifleRegripLayout({
    required this.normalFootY,
    required this.normalHeadY,
    required this.specialFootY,
    required this.specialHeadY,
    required this.specialLeft,
    required this.specialTop,
    required this.specialDimension,
  });

  final double normalFootY;
  final double normalHeadY;
  final double specialFootY;
  final double specialHeadY;
  final double specialLeft;
  final double specialTop;
  final double specialDimension;
}

@immutable
class BaseCampRifleRegripTransform {
  const BaseCampRifleRegripTransform({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  double get dimension => width;
}

const _normalSoldierCanvas = Size(1312, 1199);
const _normalSoldierVisibleLeft = 81.0;
const _normalSoldierVisibleRight = 1263.0;
const _normalSoldierVisibleTop = 0.0;
const _normalSoldierVisibleHeight = 1183.0;
const _normalSoldierVisibleBottom = 1182.0;
const _rifleFrameCanvas = 512.0;
const _rifleFrameVisibleTop = 32.0;
const _rifleFrameVisibleHeight = 480.0;
const _rifleFrameVisibleBottom = 511.0;

BaseCampRifleRegripLayout baseCampRifleRegripLayout(Size viewport) {
  final normalScale = math.min(
    viewport.width / _normalSoldierCanvas.width,
    viewport.height / _normalSoldierCanvas.height,
  );
  final frameScale =
      normalScale * _normalSoldierVisibleHeight / _rifleFrameVisibleHeight;
  final normalLeft =
      (viewport.width - _normalSoldierCanvas.width * normalScale) / 2;
  final normalTop =
      (viewport.height - _normalSoldierCanvas.height * normalScale) / 2;
  final normalFoot = normalTop + _normalSoldierVisibleBottom * normalScale;
  final normalHead = normalTop + _normalSoldierVisibleTop * normalScale;
  final normalCenter =
      normalLeft +
      (_normalSoldierVisibleLeft + _normalSoldierVisibleRight) /
          2 *
          normalScale;
  final specialLeft = normalCenter - _rifleFrameCanvas / 2 * frameScale;
  final specialTop = normalFoot - _rifleFrameVisibleBottom * frameScale;
  return BaseCampRifleRegripLayout(
    normalFootY: normalFoot,
    normalHeadY: normalHead,
    specialFootY: specialTop + _rifleFrameVisibleBottom * frameScale,
    specialHeadY: specialTop + _rifleFrameVisibleTop * frameScale,
    specialLeft: specialLeft,
    specialTop: specialTop,
    specialDimension: _rifleFrameCanvas * frameScale,
  );
}

BaseCampRifleRegripTransform baseCampRifleRegripTransform(
  Size viewport,
  int frame, {
  double globalX = baseCampApprovedRifleGlobalX,
  double globalY = baseCampApprovedRifleGlobalY,
  double globalScale = baseCampApprovedRifleGlobalScale,
  List<Offset> frameOffsets = baseCampApprovedRifleFrameOffsets,
  List<double> frameScales = baseCampApprovedRifleFrameScales,
  double verticalScaleX = 1,
  double horizontalScaleY = 1,
}) {
  final layout = baseCampRifleRegripLayout(viewport);
  final dimension = layout.specialDimension * globalScale * frameScales[frame];
  final sourceScale = dimension / _rifleFrameCanvas;
  final left =
      layout.specialLeft +
      layout.specialDimension / 2 -
      dimension / 2 +
      globalX +
      frameOffsets[frame].dx * sourceScale;
  final top =
      layout.specialTop +
      layout.specialDimension -
      dimension +
      globalY +
      frameOffsets[frame].dy * sourceScale;
  final width = dimension * horizontalScaleY;
  final height = dimension * verticalScaleX;
  return BaseCampRifleRegripTransform(
    left: left + (dimension - width) / 2,
    top: top + dimension - height,
    width: width,
    height: height,
  );
}

class BaseCampRifleRegripFrame extends StatelessWidget {
  const BaseCampRifleRegripFrame({
    super.key,
    required this.frame,
    this.globalX = baseCampApprovedRifleGlobalX,
    this.globalY = baseCampApprovedRifleGlobalY,
    this.globalScale = baseCampApprovedRifleGlobalScale,
    this.frameOffsets = baseCampApprovedRifleFrameOffsets,
    this.frameScales = baseCampApprovedRifleFrameScales,
    this.verticalScaleX = 1,
    this.horizontalScaleY = 1,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.warmth = 0,
    this.assets = baseCampRifleRegripAssets,
    this.opacity = 1,
  });

  final int frame;
  final double globalX;
  final double globalY;
  final double globalScale;
  final List<Offset> frameOffsets;
  final List<double> frameScales;
  final double verticalScaleX;
  final double horizontalScaleY;
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;
  final List<String> assets;
  final double opacity;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final transform = baseCampRifleRegripTransform(
        constraints.biggest,
        frame,
        globalX: globalX,
        globalY: globalY,
        globalScale: globalScale,
        frameOffsets: frameOffsets,
        frameScales: frameScales,
        verticalScaleX: verticalScaleX,
        horizontalScaleY: horizontalScaleY,
      );
      final image = Image.asset(
        assets[frame],
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
        frameBuilder: (context, child, frameIndex, synchronous) {
          if (frameIndex != null || synchronous) {
            recordBaseCampAssetReady(assets[frame]);
          }
          return child;
        },
      );
      final frameImage =
          brightness == 0 && contrast == 1 && saturation == 1 && warmth == 0
          ? image
          : ColorFiltered(
              colorFilter: baseCampSoldierColorFilter(
                brightness: brightness,
                contrast: contrast,
                saturation: saturation,
                warmth: warmth,
              ),
              child: image,
            );
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: transform.left,
            top: transform.top,
            width: transform.width,
            height: transform.height,
            child: Opacity(opacity: opacity, child: frameImage),
          ),
        ],
      );
    },
  );
}

class BaseCampBreathingSoldier extends StatelessWidget {
  const BaseCampBreathingSoldier({
    super.key,
    required this.dy,
    this.opacity = 1,
  });

  final double dy;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Image.asset(
          baseCampBreathingSoldierLowerAsset,
          key: const ValueKey('base-camp-soldier-lower'),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          frameBuilder: (context, child, frame, synchronous) {
            if (frame != null || synchronous) {
              recordBaseCampAssetReady(baseCampBreathingSoldierLowerAsset);
            }
            return child;
          },
        ),
        Transform.translate(
          offset: Offset(0, dy),
          child: Image.asset(
            baseCampBreathingSoldierUpperAsset,
            key: const ValueKey('base-camp-soldier-upper'),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            frameBuilder: (context, child, frame, synchronous) {
              if (frame != null || synchronous) {
                recordBaseCampAssetReady(baseCampBreathingSoldierUpperAsset);
              }
              return child;
            },
          ),
        ),
      ],
    ),
  );
}

enum BaseCampRifleRegripPhase { breathing, preIdle, rifleRegrip, postIdle }

const baseCampRifleRegripPreIdleMs = 1000;
const baseCampRifleRegripAnimationMs = 1850;
const baseCampRifleRegripPostIdleMs = 1000;
const baseCampRifleRegripEventMs =
    baseCampRifleRegripPreIdleMs +
    baseCampRifleRegripAnimationMs +
    baseCampRifleRegripPostIdleMs;
const baseCampRifleRegripFrameDurations = <int>[400, 350, 200, 350, 150, 400];

int baseCampRifleRegripEventDurationMs(List<int> durations) =>
    baseCampRifleRegripPreIdleMs +
    durations.fold<int>(0, (total, duration) => total + duration) +
    baseCampRifleRegripPostIdleMs;

BaseCampRifleRegripPhase baseCampRifleRegripPhase(
  int elapsedMs, {
  List<int> frameDurations = baseCampRifleRegripFrameDurations,
}) {
  final animationMs = frameDurations.fold<int>(
    0,
    (total, duration) => total + duration,
  );
  final eventMs = baseCampRifleRegripEventDurationMs(frameDurations);
  if (elapsedMs < baseCampRifleRegripPreIdleMs) {
    return BaseCampRifleRegripPhase.preIdle;
  }
  if (elapsedMs < baseCampRifleRegripPreIdleMs + animationMs) {
    return BaseCampRifleRegripPhase.rifleRegrip;
  }
  if (elapsedMs < eventMs) {
    return BaseCampRifleRegripPhase.postIdle;
  }
  return BaseCampRifleRegripPhase.breathing;
}

int baseCampRifleRegripFrameIndex(
  int eventElapsedMs, {
  List<int> frameDurations = baseCampRifleRegripFrameDurations,
}) {
  var frameElapsed = eventElapsedMs - baseCampRifleRegripPreIdleMs;
  for (var index = 0; index < frameDurations.length; index++) {
    final duration = frameDurations[index];
    if (frameElapsed < duration) return index;
    frameElapsed -= duration;
  }
  return frameDurations.length - 1;
}

ColorFilter baseCampSoldierColorFilter({
  required double brightness,
  required double contrast,
  required double saturation,
  required double warmth,
}) {
  const red = .2126, green = .7152, blue = .0722;
  final inverseSaturation = 1 - saturation;
  final translation = 255 * brightness + 128 * (1 - contrast);
  return ColorFilter.matrix(<double>[
    (red * inverseSaturation + saturation) * contrast,
    green * inverseSaturation * contrast,
    blue * inverseSaturation * contrast,
    0,
    translation + 255 * warmth,
    red * inverseSaturation * contrast,
    (green * inverseSaturation + saturation) * contrast,
    blue * inverseSaturation * contrast,
    0,
    translation,
    red * inverseSaturation * contrast,
    green * inverseSaturation * contrast,
    (blue * inverseSaturation + saturation) * contrast,
    0,
    translation - 255 * warmth,
    0,
    0,
    0,
    1,
    0,
  ]);
}

int baseCampRifleRegripIntervalMs(int Function(int max) nextInt) =>
    60000 + nextInt(60001);

const _breathingCycleMs = 2400.0;

double baseCampBreathingOffset(double elapsedMs) {
  final phase = (elapsedMs % _breathingCycleMs) / _breathingCycleMs;
  return -.5 * (1 - math.cos(2 * math.pi * phase));
}
