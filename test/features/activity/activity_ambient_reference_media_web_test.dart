@TestOn('browser')
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/activity/widgets/activity_ambient_reference_media.dart';
import 'package:web/web.dart' as web;

void main() {
  testWidgets('plays the supplied H.264 asset as muted inline looping media', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 240,
          height: 240,
          child: ActivityAmbientReferenceMedia(reducedMotion: false),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final video = web.document.querySelector('video') as web.HTMLVideoElement?;
    expect(video, isNotNull);
    expect(video!.src, contains('activity_reference_motion_activity_h264.mp4'));
    expect(video.autoplay, isTrue);
    expect(video.loop, isTrue);
    expect(video.muted, isTrue);
    expect(video.playsInline, isTrue);
    expect(video.controls, isFalse);
    expect(video.readyState, greaterThan(0));
    expect(video.paused, isFalse);
  });

  testWidgets('replaces playback with the supplied static image immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 240,
          height: 240,
          child: ActivityAmbientReferenceMedia(reducedMotion: false),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 240,
          height: 240,
          child: ActivityAmbientReferenceMedia(reducedMotion: true),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('activity-ambient-reference-static')),
      findsOneWidget,
    );
    final video = web.document.querySelector('video') as web.HTMLVideoElement?;
    expect(video?.paused, isTrue);
  });
}
