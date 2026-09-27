import 'dart:ui';

class BatV3SourcePose {
  const BatV3SourcePose({
    required this.index,
    required this.name,
    required this.asset,
    required this.scale,
    required this.translation,
    required this.body,
    required this.silhouette,
    required this.canonicalAsset,
  });
  final int index;
  final String name;
  final String asset;
  final double scale;
  final Offset translation;
  final BatV3BodyMeasurement body;
  final BatV3SilhouetteBounds silhouette;
  final String canonicalAsset;
}

/// Measurements are sampled from the luminance mask inside a stable
/// head/shoulder/torso region. Wing extrema are deliberately excluded.
class BatV3BodyMeasurement {
  const BatV3BodyMeasurement({
    required this.width,
    required this.height,
    required this.anchor,
  });

  final double width;
  final double height;
  final Offset anchor;
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
  static const canvas = Size(1280, 720);
  static const registrationReference = Offset(440, 410);
  static const _canvasCenter = Offset(640, 360);
  static const canonicalSafetyPadding = 64.0;
  static const _registeredUnion = Rect.fromLTRB(155, -178, 1149, 958);
  static const canonicalOrigin = Offset(114, 108);
  static const canonicalCanvas = Size(1135, 1296);
  static const canonicalBodyAnchor = Offset(436, 642);

  static Rect get registeredSilhouetteUnion => _registeredUnion;
  static const cycle = <int>[0, 1, 2, 1, 0, 3, 4, 3];
  static const flutterOffsets = <double>[0, -2, -4, -2, 0, 2, 4, 2];
  static const poses = <BatV3SourcePose>[
    BatV3SourcePose(
      index: 1,
      name: 'NEUTRAL',
      asset: 'assets/animations/sandbox/bat_v3/frame_01_neutral.jpg',
      scale: .8,
      translation: Offset.zero,
      canonicalAsset: 'assets/animations/sandbox/bat_v3_canonical/pose_01.png',
      body: BatV3BodyMeasurement(
        width: 587,
        height: 270,
        anchor: Offset(401.00, 447.93),
      ),
      silhouette: BatV3SilhouetteBounds(
        minX: 63,
        minY: 203,
        maxX: 1255,
        maxY: 579,
      ),
    ),
    BatV3SourcePose(
      index: 2,
      name: 'TOP INTERMEDIATE',
      asset: 'assets/animations/sandbox/bat_v3/frame_02_top_intermediate.jpg',
      scale: 8 / 7,
      translation: Offset.zero,
      canonicalAsset: 'assets/animations/sandbox/bat_v3_canonical/pose_02.png',
      body: BatV3BodyMeasurement(
        width: 433,
        height: 198,
        anchor: Offset(570.22, 559.44),
      ),
      silhouette: BatV3SilhouetteBounds(
        minX: 327,
        minY: 54,
        maxX: 1052,
        maxY: 657,
      ),
    ),
    BatV3SourcePose(
      index: 3,
      name: 'TOP',
      asset: 'assets/animations/sandbox/bat_v3/frame_03_top.jpg',
      scale: 20 / 19,
      translation: Offset.zero,
      canonicalAsset: 'assets/animations/sandbox/bat_v3_canonical/pose_03.png',
      body: BatV3BodyMeasurement(
        width: 463,
        height: 201,
        anchor: Offset(529.94, 572.36),
      ),
      silhouette: BatV3SilhouetteBounds(
        minX: 267,
        minY: 28,
        maxX: 1142,
        maxY: 675,
      ),
    ),
    BatV3SourcePose(
      index: 4,
      name: 'BOTTOM INTERMEDIATE',
      asset:
          'assets/animations/sandbox/bat_v3/frame_04_bottom_intermediate.jpg',
      scale: .98,
      translation: Offset.zero,
      canonicalAsset: 'assets/animations/sandbox/bat_v3_canonical/pose_04.png',
      body: BatV3BodyMeasurement(
        width: 473,
        height: 242,
        anchor: Offset(378.80, 218.18),
      ),
      silhouette: BatV3SilhouetteBounds(
        minX: 137,
        minY: 78,
        maxX: 1085,
        maxY: 669,
      ),
    ),
    BatV3SourcePose(
      index: 5,
      name: 'BOTTOM',
      asset: 'assets/animations/sandbox/bat_v3/frame_05_bottom.jpg',
      scale: 40 / 37,
      translation: Offset.zero,
      canonicalAsset: 'assets/animations/sandbox/bat_v3_canonical/pose_05.png',
      body: BatV3BodyMeasurement(
        width: 450,
        height: 242,
        anchor: Offset(436.40, 148.53),
      ),
      silhouette: BatV3SilhouetteBounds(
        minX: 200,
        minY: 28,
        maxX: 1019,
        maxY: 696,
      ),
    ),
  ];

  /// The uniform source-space transform used by the presentation renderer.
  /// Runtime uses pre-baked canonical images; this is source-audit metadata.
  static Offset registeredAnchorFor(BatV3SourcePose pose) =>
      registrationReference;

  static Size registeredBodySizeFor(BatV3SourcePose pose) =>
      Size(pose.body.width * pose.scale, pose.body.height * pose.scale);

  static Size inspectionBodySizeFor(
    BatV3SourcePose pose,
    double inspectionScale,
  ) {
    final body = registeredBodySizeFor(pose);
    return Size(body.width * inspectionScale, body.height * inspectionScale);
  }

  static Rect registeredSilhouetteBoundsFor(BatV3SourcePose pose) =>
      const Rect.fromLTRB(64, 64, 1071, 1232);

  static Rect canonicalSilhouetteBoundsFor(BatV3SourcePose pose) =>
      registeredSilhouetteBoundsFor(pose);

  static bool isFullyContained(BatV3SourcePose pose) {
    final bounds = canonicalSilhouetteBoundsFor(pose);
    return bounds.left >= canonicalSafetyPadding &&
        bounds.top >= canonicalSafetyPadding &&
        bounds.right <= canonicalCanvas.width - canonicalSafetyPadding &&
        bounds.bottom <= canonicalCanvas.height - canonicalSafetyPadding;
  }
}
