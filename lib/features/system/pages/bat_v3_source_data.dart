import 'dart:ui';

/// Immutable source metadata and the derived, pre-baked V4 animation cels.
/// Source coordinates are build/audit evidence only. Runtime selects the
/// canonical PNG and never reapplies [normalizationScale] or a translation.
class BatV3SourcePose {
  const BatV3SourcePose({
    required this.index,
    required this.name,
    required this.asset,
    required this.canonicalAsset,
    required this.head,
    required this.shoulder,
    required this.posterior,
    required this.bodyOrigin,
    required this.sourceBodyAxis,
    required this.normalizationScale,
    required this.canonicalSilhouette,
  });
  final int index;
  final String name;
  final String asset;
  final String canonicalAsset;
  final Offset head;
  final Offset shoulder;
  final Offset posterior;

  /// Measured torso reference: head/shoulder/posterior landmark centroid.
  final Offset bodyOrigin;
  final double sourceBodyAxis;
  final double normalizationScale;
  final BatV3SilhouetteBounds canonicalSilhouette;
  double get canonicalBodyAxis => sourceBodyAxis * normalizationScale;
}

class BatV3SilhouetteBounds {
  const BatV3SilhouetteBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
  Rect get rect => Rect.fromLTRB(minX, minY, maxX, maxY);
}

abstract final class BatV3SourceSet {
  static const canonicalCanvas = Size(1800, 1700);
  static const canonicalBodyAnchor = Offset(800, 850);
  static const canonicalBodyAxis = 480.0;
  static const canonicalSafetyPadding = 96.0;

  /// [CatRunCoatPatterns.baseColor], the CAT V2.10 NORMAL silhouette authority.
  static const catProductionGrayArgb = 0xFF7A7A7A;
  static const cycle = <int>[0, 1, 2, 1, 0, 3, 4, 3];
  static const flutterOffsets = <double>[0, -2, -4, -2, 0, 2, 4, 2];

  static const poses = <BatV3SourcePose>[
    BatV3SourcePose(
      index: 1,
      name: 'NEUTRAL',
      asset: 'assets/animations/sandbox/bat_v3/frame_01_neutral.jpg',
      canonicalAsset:
          'assets/animations/sandbox/bat_v3/canonical/frame_01_neutral.png',
      head: Offset(70, 470),
      shoulder: Offset(450, 430),
      posterior: Offset(600, 480),
      bodyOrigin: Offset(1120 / 3, 460),
      sourceBodyAxis: 530.094,
      normalizationScale: .905499213,
      canonicalSilhouette: BatV3SilhouetteBounds(
        minX: 518,
        minY: 615,
        maxX: 1602,
        maxY: 959,
      ),
    ),
    BatV3SourcePose(
      index: 2,
      name: 'TOP INTERMEDIATE',
      asset: 'assets/animations/sandbox/bat_v3/frame_02_top_intermediate.jpg',
      canonicalAsset:
          'assets/animations/sandbox/bat_v3/canonical/frame_02_top_intermediate.png',
      head: Offset(330, 585),
      shoulder: Offset(640, 540),
      posterior: Offset(710, 580),
      bodyOrigin: Offset(560, 1705 / 3),
      sourceBodyAxis: 380.033,
      normalizationScale: 1.263048564,
      canonicalSilhouette: BatV3SilhouetteBounds(
        minX: 504,
        minY: 197,
        maxX: 1432,
        maxY: 965,
      ),
    ),
    BatV3SourcePose(
      index: 3,
      name: 'TOP',
      asset: 'assets/animations/sandbox/bat_v3/frame_03_top.jpg',
      canonicalAsset:
          'assets/animations/sandbox/bat_v3/canonical/frame_03_top.png',
      head: Offset(270, 590),
      shoulder: Offset(600, 550),
      posterior: Offset(700, 600),
      bodyOrigin: Offset(1570 / 3, 1740 / 3),
      sourceBodyAxis: 430.116,
      normalizationScale: 1.115977332,
      canonicalSilhouette: BatV3SilhouetteBounds(
        minX: 512,
        minY: 231,
        maxX: 1495,
        maxY: 959,
      ),
    ),
    BatV3SourcePose(
      index: 4,
      name: 'BOTTOM INTERMEDIATE',
      asset:
          'assets/animations/sandbox/bat_v3/frame_04_bottom_intermediate.jpg',
      canonicalAsset:
          'assets/animations/sandbox/bat_v3/canonical/frame_04_bottom_intermediate.png',
      head: Offset(140, 230),
      shoulder: Offset(450, 190),
      posterior: Offset(600, 230),
      bodyOrigin: Offset(1190 / 3, 650 / 3),
      sourceBodyAxis: 460,
      normalizationScale: 1.043478261,
      canonicalSilhouette: BatV3SilhouetteBounds(
        minX: 527,
        minY: 704,
        maxX: 1522,
        maxY: 1324,
      ),
    ),
    BatV3SourcePose(
      index: 5,
      name: 'BOTTOM',
      asset: 'assets/animations/sandbox/bat_v3/frame_05_bottom.jpg',
      canonicalAsset:
          'assets/animations/sandbox/bat_v3/canonical/frame_05_bottom.png',
      head: Offset(200, 160),
      shoulder: Offset(500, 130),
      posterior: Offset(620, 170),
      bodyOrigin: Offset(1320 / 3, 460 / 3),
      sourceBodyAxis: 420.119,
      normalizationScale: 1.142533341,
      canonicalSilhouette: BatV3SilhouetteBounds(
        minX: 523,
        minY: 705,
        maxX: 1466,
        maxY: 1473,
      ),
    ),
  ];

  static bool isFullyContained(BatV3SourcePose pose) {
    final bounds = pose.canonicalSilhouette;
    return bounds.minX >= canonicalSafetyPadding &&
        bounds.minY >= canonicalSafetyPadding &&
        bounds.maxX <= canonicalCanvas.width - canonicalSafetyPadding &&
        bounds.maxY <= canonicalCanvas.height - canonicalSafetyPadding;
  }

  static Offset canonicalLandmark(BatV3SourcePose pose, Offset landmark) =>
      canonicalBodyAnchor +
      (landmark - pose.bodyOrigin) * pose.normalizationScale;
}
