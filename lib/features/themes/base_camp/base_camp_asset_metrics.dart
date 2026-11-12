import '../../../core/services/system_diagnostics.dart';

class BaseCampAssetMetric {
  const BaseCampAssetMetric({
    required this.bytes,
    required this.width,
    required this.height,
    this.frames = 1,
  });

  final int bytes;
  final int width;
  final int height;
  final int frames;
  int get estimatedDecodedBytes => width * height * 4 * frames;
}

const baseCampAssetMetrics = <String, BaseCampAssetMetric>{
  'assets/images/themes/base_camp/base_camp_map_v3.png': BaseCampAssetMetric(
    bytes: 2945447,
    width: 1254,
    height: 1254,
  ),
  'assets/images/themes/base_camp/objects/status_parabola_transparent_fixed.gif':
      BaseCampAssetMetric(bytes: 82594, width: 281, height: 133, frames: 6),
  'assets/images/themes/base_camp/objects/food.png': BaseCampAssetMetric(
    bytes: 1949569,
    width: 1609,
    height: 977,
  ),
  'assets/images/themes/base_camp/objects/training.gif': BaseCampAssetMetric(
    bytes: 39070,
    width: 308,
    height: 166,
  ),
  'assets/images/themes/base_camp/objects/activity.gif': BaseCampAssetMetric(
    bytes: 30825,
    width: 292,
    height: 141,
  ),
  'assets/images/themes/base_camp/objects/command_center.png':
      BaseCampAssetMetric(bytes: 1547628, width: 1523, height: 1033),
  'assets/images/themes/base_camp/objects/flag.gif': BaseCampAssetMetric(
    bytes: 162747,
    width: 304,
    height: 471,
    frames: 5,
  ),
  'assets/images/themes/base_camp/base_camp_walker_down_right.gif':
      BaseCampAssetMetric(bytes: 137785, width: 360, height: 600, frames: 7),
  'assets/images/themes/base_camp/base_camp_walker_up_left.gif':
      BaseCampAssetMetric(bytes: 163404, width: 360, height: 600, frames: 8),
  'assets/images/themes/base_camp/base_camp_walker_rear_upper_right.gif':
      BaseCampAssetMetric(bytes: 107134, width: 322, height: 518, frames: 5),
  'assets/images/themes/base_camp/base_camp_walker_front.gif':
      BaseCampAssetMetric(bytes: 116579, width: 350, height: 565, frames: 5),
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_00.png':
      BaseCampAssetMetric(bytes: 33139, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_01.png':
      BaseCampAssetMetric(bytes: 33805, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_02.png':
      BaseCampAssetMetric(bytes: 40272, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_03.png':
      BaseCampAssetMetric(bytes: 33139, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_04.png':
      BaseCampAssetMetric(bytes: 33959, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_05.png':
      BaseCampAssetMetric(bytes: 35575, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_06.png':
      BaseCampAssetMetric(bytes: 33959, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_00.png':
      BaseCampAssetMetric(bytes: 311207, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_01.png':
      BaseCampAssetMetric(bytes: 38572, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_02.png':
      BaseCampAssetMetric(bytes: 41373, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_03.png':
      BaseCampAssetMetric(bytes: 38572, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_04.png':
      BaseCampAssetMetric(bytes: 34804, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_05.png':
      BaseCampAssetMetric(bytes: 38434, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_06.png':
      BaseCampAssetMetric(bytes: 46177, width: 360, height: 600),
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_07.png':
      BaseCampAssetMetric(bytes: 38434, width: 360, height: 600),
  'assets/images/themes/base_camp/rear_upper_right/frame_00.png':
      BaseCampAssetMetric(bytes: 31896, width: 322, height: 518),
  'assets/images/themes/base_camp/rear_upper_right/frame_01.png':
      BaseCampAssetMetric(bytes: 32627, width: 322, height: 518),
  'assets/images/themes/base_camp/rear_upper_right/frame_02.png':
      BaseCampAssetMetric(bytes: 29892, width: 322, height: 518),
  'assets/images/themes/base_camp/rear_upper_right/frame_03.png':
      BaseCampAssetMetric(bytes: 31912, width: 322, height: 518),
  'assets/images/themes/base_camp/rear_upper_right/frame_04.png':
      BaseCampAssetMetric(bytes: 30574, width: 322, height: 518),
  'assets/images/themes/base_camp/front/frame_00.png': BaseCampAssetMetric(
    bytes: 34337,
    width: 350,
    height: 565,
  ),
  'assets/images/themes/base_camp/front/frame_01.png': BaseCampAssetMetric(
    bytes: 36962,
    width: 350,
    height: 565,
  ),
  'assets/images/themes/base_camp/front/frame_02.png': BaseCampAssetMetric(
    bytes: 32488,
    width: 350,
    height: 565,
  ),
  'assets/images/themes/base_camp/front/frame_03.png': BaseCampAssetMetric(
    bytes: 33371,
    width: 350,
    height: 565,
  ),
  'assets/images/themes/base_camp/front/frame_04.png': BaseCampAssetMetric(
    bytes: 31595,
    width: 350,
    height: 565,
  ),
  'assets/images/themes/base_camp/breathing_soldier/gasmask_lowerboady.png':
      BaseCampAssetMetric(bytes: 187596, width: 1312, height: 1199),
  'assets/images/themes/base_camp/breathing_soldier/gasmask_upperboady.png':
      BaseCampAssetMetric(bytes: 360369, width: 1312, height: 1199),
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F0.png':
      BaseCampAssetMetric(bytes: 142577, width: 512, height: 512),
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F1.png':
      BaseCampAssetMetric(bytes: 141142, width: 512, height: 512),
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F2.png':
      BaseCampAssetMetric(bytes: 138131, width: 512, height: 512),
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F3.png':
      BaseCampAssetMetric(bytes: 140127, width: 512, height: 512),
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F4.png':
      BaseCampAssetMetric(bytes: 133003, width: 512, height: 512),
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F5.png':
      BaseCampAssetMetric(bytes: 134311, width: 512, height: 512),
};

void recordBaseCampAssetReady(String asset) {
  final metric = baseCampAssetMetrics[asset];
  if (metric == null) return;
  SystemDiagnostics.instance.recordAssetOnce(
    asset,
    bytes: metric.bytes,
    width: metric.width,
    height: metric.height,
    frames: metric.frames,
  );
}
