import 'dart:math' as math;

import 'package:flutter/material.dart';

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
const baseCampApprovedRifleGlobalY = 5.3333892822265625;
const baseCampApprovedRifleGlobalScale = 0.9773123770508106;
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
  });

  final double x;
  final double y;
  final double scale;
}

/// Session-only production override. Preview edits never touch Dashboard until
/// APPLY is explicitly chosen and never overwrite persisted user map data.
final baseCampRifleGlobalAlignment =
    ValueNotifier<BaseCampRifleGlobalAlignment>(
      const BaseCampRifleGlobalAlignment(),
    );

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
    required this.dimension,
  });

  final double left;
  final double top;
  final double dimension;
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
}) {
  final layout = baseCampRifleRegripLayout(viewport);
  final dimension = layout.specialDimension * globalScale * frameScales[frame];
  final sourceScale = dimension / _rifleFrameCanvas;
  return BaseCampRifleRegripTransform(
    left:
        layout.specialLeft +
        layout.specialDimension / 2 -
        dimension / 2 +
        globalX +
        frameOffsets[frame].dx * sourceScale,
    top:
        layout.specialTop +
        layout.specialDimension -
        dimension +
        globalY +
        frameOffsets[frame].dy * sourceScale,
    dimension: dimension,
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
    this.assets = baseCampRifleRegripAssets,
    this.opacity = 1,
  });

  final int frame;
  final double globalX;
  final double globalY;
  final double globalScale;
  final List<Offset> frameOffsets;
  final List<double> frameScales;
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
      );
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: transform.left,
            top: transform.top,
            width: transform.dimension,
            height: transform.dimension,
            child: Opacity(
              opacity: opacity,
              child: Image.asset(
                assets[frame],
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                frameBuilder: (context, child, frameIndex, synchronous) {
                  if (frameIndex != null || synchronous) {
                    recordBaseCampAssetReady(assets[frame]);
                  }
                  return child;
                },
              ),
            ),
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

BaseCampRifleRegripPhase baseCampRifleRegripPhase(int elapsedMs) {
  if (elapsedMs < baseCampRifleRegripPreIdleMs) {
    return BaseCampRifleRegripPhase.preIdle;
  }
  if (elapsedMs <
      baseCampRifleRegripPreIdleMs + baseCampRifleRegripAnimationMs) {
    return BaseCampRifleRegripPhase.rifleRegrip;
  }
  if (elapsedMs < baseCampRifleRegripEventMs) {
    return BaseCampRifleRegripPhase.postIdle;
  }
  return BaseCampRifleRegripPhase.breathing;
}

int baseCampRifleRegripFrameIndex(int eventElapsedMs) {
  var frameElapsed = eventElapsedMs - baseCampRifleRegripPreIdleMs;
  for (
    var index = 0;
    index < baseCampRifleRegripFrameDurations.length;
    index++
  ) {
    final duration = baseCampRifleRegripFrameDurations[index];
    if (frameElapsed < duration) return index;
    frameElapsed -= duration;
  }
  return baseCampRifleRegripFrameDurations.length - 1;
}

int baseCampRifleRegripIntervalMs(int Function(int max) nextInt) =>
    60000 + nextInt(60001);

const _breathingCycleMs = 2400.0;

double baseCampBreathingOffset(double elapsedMs) {
  final phase = (elapsedMs % _breathingCycleMs) / _breathingCycleMs;
  return -.5 * (1 - math.cos(2 * math.pi * phase));
}
