import 'package:flutter/widgets.dart';

/// Static fallback for non-web targets and reduced-motion rendering.
class ActivityAmbientReferenceMedia extends StatelessWidget {
  const ActivityAmbientReferenceMedia({super.key, required this.reducedMotion});

  static const videoAsset =
      'assets/animations/activity/reference_motion/'
      'activity_reference_motion_activity_h264.mp4';
  static const staticAsset =
      'assets/animations/activity/reference_motion/'
      'activity_reference_motion_v1_frame.png';

  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => Image.asset(
    staticAsset,
    key: const ValueKey('activity-ambient-reference-static'),
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}
