import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../base_camp_map_configuration.dart';

const baseCampWaterV3BSourceSize = Size(440, 248);
const baseCampWaterV3BFrameDuration = Duration(milliseconds: 140);
const baseCampWaterV3BFrameCount = 24;
const baseCampWaterV3BLoopDuration = Duration(milliseconds: 3360);
const baseCampWaterV3BAssetDirectory =
    'assets/images/themes/base_camp/water_v3b/frames_rgba';

const baseCampWaterV3BFrameAssets = <String>[
  '$baseCampWaterV3BAssetDirectory/frame_00.png',
  '$baseCampWaterV3BAssetDirectory/frame_01.png',
  '$baseCampWaterV3BAssetDirectory/frame_02.png',
  '$baseCampWaterV3BAssetDirectory/frame_03.png',
  '$baseCampWaterV3BAssetDirectory/frame_04.png',
  '$baseCampWaterV3BAssetDirectory/frame_05.png',
  '$baseCampWaterV3BAssetDirectory/frame_06.png',
  '$baseCampWaterV3BAssetDirectory/frame_07.png',
  '$baseCampWaterV3BAssetDirectory/frame_08.png',
  '$baseCampWaterV3BAssetDirectory/frame_09.png',
  '$baseCampWaterV3BAssetDirectory/frame_10.png',
  '$baseCampWaterV3BAssetDirectory/frame_11.png',
  '$baseCampWaterV3BAssetDirectory/frame_12.png',
  '$baseCampWaterV3BAssetDirectory/frame_13.png',
  '$baseCampWaterV3BAssetDirectory/frame_14.png',
  '$baseCampWaterV3BAssetDirectory/frame_15.png',
  '$baseCampWaterV3BAssetDirectory/frame_16.png',
  '$baseCampWaterV3BAssetDirectory/frame_17.png',
  '$baseCampWaterV3BAssetDirectory/frame_18.png',
  '$baseCampWaterV3BAssetDirectory/frame_19.png',
  '$baseCampWaterV3BAssetDirectory/frame_20.png',
  '$baseCampWaterV3BAssetDirectory/frame_21.png',
  '$baseCampWaterV3BAssetDirectory/frame_22.png',
  '$baseCampWaterV3BAssetDirectory/frame_23.png',
];

int baseCampWaterV3BFrameIndex(int tick) => tick % baseCampWaterV3BFrameCount;

/// Returns one uniformly scaled placement that covers the MAP artwork.
///
/// The approved 440:248 source is never stretched independently. A single
/// centered instance is cropped by the MAP viewport and WATER mask, avoiding
/// tiles, seams, and motion that is independent from MAP pan/zoom.
Rect baseCampWaterV3BDestinationRect(Rect imageRect) {
  final scale = math.max(
    imageRect.width / baseCampWaterV3BSourceSize.width,
    imageRect.height / baseCampWaterV3BSourceSize.height,
  );
  return Rect.fromCenter(
    center: imageRect.center,
    width: baseCampWaterV3BSourceSize.width * scale,
    height: baseCampWaterV3BSourceSize.height * scale,
  );
}

/// Approved WATER V3B prototype ⑤ (rounding_v2) presentation layer.
///
/// All pixel content comes from the supplied transparent RGBA frames. Flutter
/// only selects the current frame and performs normal alpha compositing inside
/// the existing WATER minus EXCLUSION clip.
class BaseCampWaterSurfaceV3BLayer extends StatelessWidget {
  const BaseCampWaterSurfaceV3BLayer({
    super.key,
    required this.water,
    required this.imageRect,
    required this.artworkSize,
    required this.frameTick,
  });

  final BaseCampWaterFx water;
  final Rect imageRect;
  final Size artworkSize;
  final ValueListenable<int> frameTick;

  @override
  Widget build(BuildContext context) => ClipPath(
    key: const ValueKey('base-camp-water-mask-clip'),
    clipper: BaseCampWaterMaskClipper(
      water: water,
      imageRect: imageRect,
      artworkSize: artworkSize,
    ),
    clipBehavior: Clip.hardEdge,
    child: RepaintBoundary(
      key: const ValueKey('base-camp-water-v3b-overlay'),
      child: ValueListenableBuilder<int>(
        valueListenable: frameTick,
        builder: (context, tick, _) {
          final destination = baseCampWaterV3BDestinationRect(imageRect);
          final frameIndex = baseCampWaterV3BFrameIndex(tick);
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              Positioned.fromRect(
                rect: destination,
                child: Image(
                  key: ValueKey('base-camp-water-v3b-frame-$frameIndex'),
                  image: AssetImage(baseCampWaterV3BFrameAssets[frameIndex]),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class BaseCampWaterMaskClipper extends CustomClipper<Path> {
  const BaseCampWaterMaskClipper({
    required this.water,
    required this.imageRect,
    required this.artworkSize,
  });

  final BaseCampWaterFx water;
  final Rect imageRect;
  final Size artworkSize;

  Offset _toViewport(Offset point) => Offset(
    imageRect.left + point.dx * imageRect.width / artworkSize.width,
    imageRect.top + point.dy * imageRect.height / artworkSize.height,
  );

  @override
  Path getClip(Size size) {
    // Some approved exclusions cross a WATER boundary. Build a true set
    // difference so their out-of-water portion never becomes a filled island.
    Path? waterUnion;
    Path? exclusionUnion;
    for (final area in water.effectiveAreas) {
      if (area.mask.length < 3) continue;
      final waterPolygon = Path()
        ..addPolygon(area.mask.map(_toViewport).toList(growable: false), true);
      waterUnion = waterUnion == null
          ? waterPolygon
          : Path.combine(PathOperation.union, waterUnion, waterPolygon);
      for (final exclusion in area.exclusionMasks) {
        if (exclusion.length < 3) continue;
        final exclusionPolygon = Path()
          ..addPolygon(
            exclusion.map(_toViewport).toList(growable: false),
            true,
          );
        exclusionUnion = exclusionUnion == null
            ? exclusionPolygon
            : Path.combine(
                PathOperation.union,
                exclusionUnion,
                exclusionPolygon,
              );
      }
    }
    final waterPath = waterUnion ?? Path();
    return exclusionUnion == null
        ? waterPath
        : Path.combine(PathOperation.difference, waterPath, exclusionUnion);
  }

  @override
  bool shouldReclip(BaseCampWaterMaskClipper oldClipper) =>
      oldClipper.water != water ||
      oldClipper.imageRect != imageRect ||
      oldClipper.artworkSize != artworkSize;
}
