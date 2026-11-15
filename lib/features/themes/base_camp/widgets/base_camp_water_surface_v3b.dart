import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../base_camp_map_configuration.dart';

const baseCampWaterV3BSourceSize = Size(440, 248);
const baseCampWaterV3BMapSourceSize = Size(1254, 1254);
const baseCampWaterV3BFrameDuration = Duration(milliseconds: 140);
const baseCampWaterV3BFrameCount = 24;
const baseCampWaterV3BLoopDuration = Duration(milliseconds: 3360);
const baseCampWaterV3BPatternScale = 1.0;
const baseCampWaterV3BHorizontalPitchFactor = .75;
const baseCampWaterV3BVerticalPitchFactor = .75;
const baseCampWaterV3BAdjacentRowOffsetFactor = .25;
const baseCampWaterV3BFeatherFactor = .25;
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

@immutable
class BaseCampWaterV3BPlacement {
  const BaseCampWaterV3BPlacement({
    required this.sourceRect,
    required this.phaseOffset,
    required this.row,
    required this.column,
  });

  final Rect sourceRect;
  final int phaseOffset;
  final int row;
  final int column;
}

/// Stable, deterministic WATER V3B placements in the 1254×1254 MAP source
/// coordinate system. Their positions never depend on the physical viewport.
List<BaseCampWaterV3BPlacement> baseCampWaterV3BPlacements({
  Size artworkSize = baseCampWaterV3BMapSourceSize,
  double patternScale = baseCampWaterV3BPatternScale,
}) {
  final tileWidth = baseCampWaterV3BSourceSize.width * patternScale;
  final tileHeight = baseCampWaterV3BSourceSize.height * patternScale;
  final pitchX = tileWidth * baseCampWaterV3BHorizontalPitchFactor;
  final pitchY = tileHeight * baseCampWaterV3BVerticalPitchFactor;
  final rowOffset = tileWidth * baseCampWaterV3BAdjacentRowOffsetFactor;
  final placements = <BaseCampWaterV3BPlacement>[];
  var row = 0;
  for (var y = -pitchY; y < artworkSize.height; y += pitchY, row++) {
    final firstX = -pitchX + (row.isOdd ? rowOffset : 0);
    var column = 0;
    for (var x = firstX; x < artworkSize.width; x += pitchX, column++) {
      final phase = (row * 7 + column * 5) % baseCampWaterV3BFrameCount;
      placements.add(
        BaseCampWaterV3BPlacement(
          sourceRect: Rect.fromLTWH(x, y, tileWidth, tileHeight),
          phaseOffset: phase,
          row: row,
          column: column,
        ),
      );
    }
  }
  return List<BaseCampWaterV3BPlacement>.unmodifiable(placements);
}

List<BaseCampWaterV3BPlacement> baseCampWaterV3BVisiblePlacements({
  required BaseCampWaterFx water,
  Size artworkSize = baseCampWaterV3BMapSourceSize,
  double patternScale = baseCampWaterV3BPatternScale,
}) {
  final waterPaths = <Path>[
    for (final area in water.effectiveAreas)
      if (area.mask.length >= 3) Path()..addPolygon(area.mask, true),
  ];
  return List<BaseCampWaterV3BPlacement>.unmodifiable(
    baseCampWaterV3BPlacements(
      artworkSize: artworkSize,
      patternScale: patternScale,
    ).where((placement) {
      final tilePath = Path()..addRect(placement.sourceRect);
      return waterPaths.any((waterPath) {
        if (!waterPath.getBounds().overlaps(placement.sourceRect)) {
          return false;
        }
        final intersection = Path.combine(
          PathOperation.intersect,
          waterPath,
          tilePath,
        );
        return intersection.computeMetrics().isNotEmpty;
      });
    }),
  );
}

Rect baseCampWaterV3BViewportRect({
  required Rect sourceRect,
  required Rect imageRect,
  required Size artworkSize,
}) {
  final scale = math.min(
    imageRect.width / artworkSize.width,
    imageRect.height / artworkSize.height,
  );
  return Rect.fromLTWH(
    imageRect.left + sourceRect.left * scale,
    imageRect.top + sourceRect.top * scale,
    sourceRect.width * scale,
    sourceRect.height * scale,
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
  Widget build(BuildContext context) {
    // Placement geometry is stable for the lifetime of this presentation.
    // Compute it outside the 140 ms frame builder so playback allocates no
    // source-space placement lists or destination rects per tick.
    final placements = baseCampWaterV3BVisiblePlacements(
      water: water,
      artworkSize: artworkSize,
    );
    final viewportRects = placements
        .map(
          (placement) => baseCampWaterV3BViewportRect(
            sourceRect: placement.sourceRect,
            imageRect: imageRect,
            artworkSize: artworkSize,
          ),
        )
        .toList(growable: false);
    return ClipPath(
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
          builder: (context, tick, _) => Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              for (var index = 0; index < placements.length; index++)
                Positioned.fromRect(
                  rect: viewportRects[index],
                  child: _BaseCampWaterV3BTile(
                    key: ValueKey('base-camp-water-v3b-tile-$index'),
                    frameIndex: baseCampWaterV3BFrameIndex(
                      tick + placements[index].phaseOffset,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaseCampWaterV3BTile extends StatelessWidget {
  const _BaseCampWaterV3BTile({super.key, required this.frameIndex});

  final int frameIndex;

  static const _horizontalFeather = LinearGradient(
    colors: <Color>[
      Colors.transparent,
      Colors.white,
      Colors.white,
      Colors.transparent,
    ],
    stops: <double>[
      0,
      baseCampWaterV3BFeatherFactor,
      1 - baseCampWaterV3BFeatherFactor,
      1,
    ],
  );

  static const _verticalFeather = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Colors.transparent,
      Colors.white,
      Colors.white,
      Colors.transparent,
    ],
    stops: <double>[
      0,
      baseCampWaterV3BFeatherFactor,
      1 - baseCampWaterV3BFeatherFactor,
      1,
    ],
  );

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: _horizontalFeather.createShader,
    blendMode: BlendMode.dstIn,
    child: ShaderMask(
      shaderCallback: _verticalFeather.createShader,
      blendMode: BlendMode.dstIn,
      child: Image(
        key: ValueKey('base-camp-water-v3b-frame-$frameIndex'),
        image: AssetImage(baseCampWaterV3BFrameAssets[frameIndex]),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: true,
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
