import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/animations_sandbox_page.dart';
import 'package:or_app/features/system/pages/bat_flight_motion_poc.dart';
import 'package:or_app/features/system/pages/bat_source_vector_rebuild_data.dart';

void main() {
  test('five frozen HIGH vectors retain the authoritative source order', () {
    final frames = BatSourceVectorRebuild.frames;

    expect(frames, hasLength(5));
    expect(frames.map((frame) => frame.sourceIndex), [1, 2, 3, 4, 5]);
    expect(frames.map((frame) => frame.sourceIdentifier), [
      'A7A548DF-0053-4996-9409-382DF7E51BA5/1-写真1.jpg',
      'A7A548DF-0053-4996-9409-382DF7E51BA5/2-写真2.jpg',
      'A7A548DF-0053-4996-9409-382DF7E51BA5/3-写真3.jpg',
      'A7A548DF-0053-4996-9409-382DF7E51BA5/4-写真4.jpg',
      'A7A548DF-0053-4996-9409-382DF7E51BA5/5-写真5.jpg',
    ]);
    expect(frames.map((frame) => frame.highPoints).toSet(), hasLength(5));
    expect(frames.map((frame) => frame.rawPoints).toSet(), hasLength(5));
  });

  test(
    'each source-derived HIGH vector passes its independent fidelity gate',
    () {
      for (final frame in BatSourceVectorRebuild.frames) {
        expect(frame.rawPointCount, greaterThan(frame.highPointCount));
        expect(frame.highPointCount, greaterThan(100));
        expect(
          frame.iou,
          greaterThanOrEqualTo(BatSourceVectorRebuild.minimumIou),
        );
        expect(
          frame.disagreement,
          lessThanOrEqualTo(BatSourceVectorRebuild.maximumDisagreement),
        );
      }
      expect(BatSourceVectorRebuild.allFramesPass, isTrue);
    },
  );

  test(
    'registration is presentation-only and never deforms frozen geometry',
    () {
      for (final frame in BatSourceVectorRebuild.frames) {
        final highBefore = List<int>.from(frame.highPoints);
        final rawBefore = List<int>.from(frame.rawPoints);
        final painter = BatSourceVectorPainter(
          frame: frame,
          mode: BatSourceInspectionMode.registered,
          leftToRight: true,
          scale: 1,
        );

        expect(painter.frame.highPoints, highBefore);
        expect(painter.frame.rawPoints, rawBefore);
        expect(BatSourceVectorFrame.uniformScale, 1.0);
        expect(frame.registrationTranslation.isFinite, isTrue);
      }
    },
  );

  testWidgets(
    'audit modes, all frames, whole-geometry mirror, and 48px preview work',
    (tester) async {
      await tester.pumpWidget(_host());

      for (var index = 0; index < 5; index++) {
        await tester.tap(
          find.byKey(ValueKey('bat-source-vector-frame-${index + 1}')),
        );
        await tester.pump();
        expect(
          find.text(
            'FRAME ${(index + 1).toString().padLeft(2, '0')} · '
            'SOURCE CORRESPONDENCE PASS',
          ),
          findsOneWidget,
        );
      }

      for (final mode in BatSourceInspectionMode.values) {
        final modeButton = find.byKey(
          ValueKey('bat-source-vector-mode-${mode.name}'),
        );
        await tester.ensureVisible(modeButton);
        await tester.tap(modeButton);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: mode.name);
      }

      final rtl = find.byKey(const ValueKey('bat-source-vector-direction-rtl'));
      await tester.ensureVisible(rtl);
      await tester.tap(rtl);
      await tester.pump();
      final preview = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(
            const ValueKey('bat-source-vector-production-preview'),
          ),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = preview.painter! as BatSourceVectorPainter;
      expect(painter.leftToRight, isFalse);
      expect(
        tester
            .getSize(
              find.byKey(
                const ValueKey('bat-source-vector-production-preview'),
              ),
            )
            .height,
        48,
      );
    },
  );

  testWidgets(
    'the source-fidelity audit remains layout-safe at 320, 390, and 900',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0, 900.0]) {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(_host());
        final frame = find.byKey(const ValueKey('bat-source-vector-frame-5'));
        final zoom = find.byKey(const ValueKey('bat-source-vector-zoom-4'));
        await tester.ensureVisible(frame);
        await tester.tap(frame);
        await tester.ensureVisible(zoom);
        await tester.tap(zoom);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('bat-source-vector-production-preview')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    },
  );

  testWidgets('ANIMATIONS SANDBOX keeps the active BAT source audit surface', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 12000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const MaterialApp(home: AnimationsSandboxPage()));

    expect(
      find.byKey(const ValueKey('bat-source-vector-rebuild-poc')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bat-source-vector-production-preview')),
      findsOneWidget,
    );
    expect(find.text('CAT TRACE PIPELINE POC'), findsNothing);
  });
}

Widget _host() => MaterialApp(
  home: Scaffold(body: ListView(children: const [BatFlightMotionPoc()])),
);
