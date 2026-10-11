import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web-native, muted inline playback of the supplied authoritative asset.
class ActivityAmbientReferenceMedia extends StatefulWidget {
  const ActivityAmbientReferenceMedia({super.key, required this.reducedMotion});

  static const videoAsset =
      'assets/animations/activity/reference_motion/'
      'activity_reference_motion_activity_h264.mp4';
  static const staticAsset =
      'assets/animations/activity/reference_motion/'
      'activity_reference_motion_v1_frame.png';

  final bool reducedMotion;

  @override
  State<ActivityAmbientReferenceMedia> createState() =>
      _ActivityAmbientReferenceMediaState();
}

class _ActivityAmbientReferenceMediaState
    extends State<ActivityAmbientReferenceMedia> {
  late final String _viewType =
      'activity-reference-motion-${identityHashCode(this)}';
  late final web.HTMLVideoElement _video = web.HTMLVideoElement()
    ..autoplay = true
    ..loop = true
    ..muted = true
    ..defaultMuted = true
    ..controls = false
    ..playsInline = true
    ..disablePictureInPicture = true
    ..preload = 'auto'
    ..src = ui_web.assetManager.getAssetUrl(
      ActivityAmbientReferenceMedia.videoAsset,
    )
    ..setAttribute('playsinline', '')
    ..setAttribute('webkit-playsinline', '')
    ..setAttribute('muted', '')
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'contain'
    ..style.borderRadius = '50%'
    ..style.display = 'block'
    ..style.backgroundColor = 'transparent';

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
      isVisible: true,
    );
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant ActivityAmbientReferenceMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reducedMotion != widget.reducedMotion) _syncPlayback();
  }

  void _syncPlayback() {
    if (widget.reducedMotion) {
      _video.pause();
      return;
    }
    // The muted and playsinline attributes are required for iPhone Safari
    // autoplay. Calling play also resumes immediately after a reduced-motion
    // setting is turned off.
    _video.play();
  }

  @override
  void dispose() {
    _video.pause();
    _video.removeAttribute('src');
    _video.load();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reducedMotion) {
      return Image.asset(
        ActivityAmbientReferenceMedia.staticAsset,
        key: const ValueKey('activity-ambient-reference-static'),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
    return HtmlElementView(
      key: const ValueKey('activity-ambient-reference-video'),
      viewType: _viewType,
    );
  }
}
