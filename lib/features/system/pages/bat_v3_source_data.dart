import 'dart:ui';

class BatV3SourcePose {
  const BatV3SourcePose({
    required this.index,
    required this.name,
    required this.asset,
    required this.scale,
    required this.translation,
    required this.body,
  });
  final int index;
  final String name;
  final String asset;
  final double scale;
  final Offset translation;
  final BatV3BodyMeasurement body;
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

abstract final class BatV3SourceSet {
  static const canvas = Size(1280, 720);
  static const registrationReference = Offset(440, 410);
  static const _canvasCenter = Offset(640, 360);
  static const cycle = <int>[0, 1, 2, 1, 0, 3, 4, 3];
  static const flutterOffsets = <double>[0, -2, -4, -2, 0, 2, 4, 2];
  static const poses = <BatV3SourcePose>[
    BatV3SourcePose(
      index: 1,
      name: 'NEUTRAL',
      asset: 'assets/animations/sandbox/bat_v3/frame_01_neutral.jpg',
      scale: .83,
      translation: Offset(-1.63, -22.98),
      body: BatV3BodyMeasurement(
        width: 587,
        height: 270,
        anchor: Offset(401.00, 447.93),
      ),
    ),
    BatV3SourcePose(
      index: 2,
      name: 'TOP INTERMEDIATE',
      asset: 'assets/animations/sandbox/bat_v3/frame_02_top_intermediate.jpg',
      scale: 1.13,
      translation: Offset(-121.15, -175.37),
      body: BatV3BodyMeasurement(
        width: 433,
        height: 198,
        anchor: Offset(570.22, 559.44),
      ),
    ),
    BatV3SourcePose(
      index: 3,
      name: 'TOP',
      asset: 'assets/animations/sandbox/bat_v3/frame_03_top.jpg',
      scale: 1.08,
      translation: Offset(-81.14, -179.35),
      body: BatV3BodyMeasurement(
        width: 463,
        height: 201,
        anchor: Offset(529.94, 572.36),
      ),
    ),
    BatV3SourcePose(
      index: 4,
      name: 'BOTTOM INTERMEDIATE',
      asset:
          'assets/animations/sandbox/bat_v3/frame_04_bottom_intermediate.jpg',
      scale: .98,
      translation: Offset(55.98, 188.98),
      body: BatV3BodyMeasurement(
        width: 473,
        height: 242,
        anchor: Offset(378.80, 218.18),
      ),
    ),
    BatV3SourcePose(
      index: 5,
      name: 'BOTTOM',
      asset: 'assets/animations/sandbox/bat_v3/frame_05_bottom.jpg',
      scale: 1,
      translation: Offset(3.60, 261.47),
      body: BatV3BodyMeasurement(
        width: 450,
        height: 242,
        anchor: Offset(436.40, 148.53),
      ),
    ),
  ];

  /// The uniform source-space transform used by the presentation renderer.
  static Offset registeredAnchorFor(BatV3SourcePose pose) =>
      _canvasCenter +
      (pose.body.anchor - _canvasCenter) * pose.scale +
      pose.translation;

  static Size registeredBodySizeFor(BatV3SourcePose pose) =>
      Size(pose.body.width * pose.scale, pose.body.height * pose.scale);

  static Size inspectionBodySizeFor(
    BatV3SourcePose pose,
    double inspectionScale,
  ) {
    final body = registeredBodySizeFor(pose);
    return Size(body.width * inspectionScale, body.height * inspectionScale);
  }
}
