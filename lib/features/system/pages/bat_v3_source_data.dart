import 'dart:ui';

class BatV3SourcePose {
  const BatV3SourcePose({
    required this.index,
    required this.name,
    required this.asset,
    required this.scale,
    required this.translation,
  });
  final int index;
  final String name;
  final String asset;
  final double scale;
  final Offset translation;
}

abstract final class BatV3SourceSet {
  static const canvas = Size(1280, 720);
  static const cycle = <int>[0, 1, 2, 1, 0, 3, 4, 3];
  static const flutterOffsets = <double>[0, -2, -4, -2, 0, 2, 4, 2];
  static const poses = <BatV3SourcePose>[
    BatV3SourcePose(
      index: 1,
      name: 'NEUTRAL',
      asset: 'assets/animations/sandbox/bat_v3/frame_01_neutral.jpg',
      scale: .90,
      translation: Offset(34, 8),
    ),
    BatV3SourcePose(
      index: 2,
      name: 'TOP INTERMEDIATE',
      asset: 'assets/animations/sandbox/bat_v3/frame_02_top_intermediate.jpg',
      scale: 1,
      translation: Offset(-126, -68),
    ),
    BatV3SourcePose(
      index: 3,
      name: 'TOP',
      asset: 'assets/animations/sandbox/bat_v3/frame_03_top.jpg',
      scale: 1,
      translation: Offset(-78, -122),
    ),
    BatV3SourcePose(
      index: 4,
      name: 'BOTTOM INTERMEDIATE',
      asset:
          'assets/animations/sandbox/bat_v3/frame_04_bottom_intermediate.jpg',
      scale: 1,
      translation: Offset(20, 166),
    ),
    BatV3SourcePose(
      index: 5,
      name: 'BOTTOM',
      asset: 'assets/animations/sandbox/bat_v3/frame_05_bottom.jpg',
      scale: 1,
      translation: Offset(-64, 224),
    ),
  ];
}
