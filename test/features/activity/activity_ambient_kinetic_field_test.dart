import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/dashboard_glass_card.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/activity/activity_page.dart';
import 'package:or_app/features/activity/widgets/activity_ambient_kinetic_field.dart';
import 'package:or_app/features/activity/widgets/activity_ambient_aurora_glass_candidate.dart';
import 'package:or_app/features/activity/widgets/activity_ambient_native_candidate.dart';
import 'package:or_app/features/activity/widgets/activity_ambient_reference_media.dart';

void main() {
  test('coordinates detect track measure and accumulation causally', () {
    final detect = ActivityAmbientKineticField.sampleFor(
      region: 0,
      elapsedSeconds: 0,
    );
    final track = ActivityAmbientKineticField.sampleFor(
      region: 0,
      elapsedSeconds: 4,
    );
    final measure = ActivityAmbientKineticField.sampleFor(
      region: 0,
      elapsedSeconds: 10.8,
    );
    final accumulate = ActivityAmbientKineticField.sampleFor(
      region: 0,
      elapsedSeconds: 12.7,
    );

    expect(detect.phase, ActivityKineticPhase.detect);
    expect(track.phase, ActivityKineticPhase.track);
    expect(track.pathProgress, inInclusiveRange(0, 1));
    expect(measure.phase, ActivityKineticPhase.measure);
    expect(measure.signalProgress, greaterThan(0));
    expect(accumulate.phase, ActivityKineticPhase.accumulate);
    expect(accumulate.signalProgress, 1);
    expect(accumulate.accumulationProgress, greaterThan(0));
  });

  test('regions remain asynchronous and avoid a global reset', () {
    final phases = <ActivityKineticPhase>{
      for (
        var region = 0;
        region < ActivityAmbientKineticField.trackingRegionCount;
        region++
      )
        ActivityAmbientKineticField.sampleFor(
          region: region,
          elapsedSeconds: 4,
        ).phase,
    };
    expect(phases.length, greaterThan(2));
  });

  test('declares the supplied authoritative reference media', () {
    expect(
      ActivityAmbientReferenceMedia.videoAsset,
      'assets/animations/activity/reference_motion/'
      'activity_reference_motion_activity_h264.mp4',
    );
    expect(
      ActivityAmbientReferenceMedia.staticAsset,
      'assets/animations/activity/reference_motion/'
      'activity_reference_motion_v1_frame.png',
    );
    expect(File(ActivityAmbientReferenceMedia.videoAsset).lengthSync(), 997266);
    expect(
      File(ActivityAmbientReferenceMedia.staticAsset).lengthSync(),
      119457,
    );
  });

  test('web playback declares muted inline looping without controls', () {
    final source = File(
      'lib/features/activity/widgets/activity_ambient_reference_media_web.dart',
    ).readAsStringSync();
    expect(source, contains('..autoplay = true'));
    expect(source, contains('..loop = true'));
    expect(source, contains('..muted = true'));
    expect(source, contains('..playsInline = true'));
    expect(source, contains('..controls = false'));
    expect(source, contains("setAttribute('webkit-playsinline', '')"));
  });

  test('keeps the native filament comparison opt-in and asset-independent', () {
    expect(ActivityAmbientKineticField.useNativeCandidate, isFalse);
    expect(ActivityAmbientNativeCandidate.filamentCount, 180);
    expect(ActivityAmbientNativeCandidate.filamentStrokeWidthMultiplier, 3.0);
    expect(
      ActivityAmbientNativeCandidate.afterglowDuration,
      const Duration(seconds: 2),
    );
    expect(ActivityAmbientNativeCandidate.afterglowSegments, 4);
    final source = File(
      'lib/features/activity/widgets/activity_ambient_native_candidate.dart',
    ).readAsStringSync();
    expect(source, contains('class _NativeLuminousFlowPainter'));
    expect(source, contains('void _paintAfterglow'));
    expect(source, contains('lastElapsedDuration'));
    expect(source, isNot(contains('ActivityAmbientReferenceMedia')));
    expect(source, isNot(contains('HtmlElementView')));
  });

  test('uses programmatic Aurora Glass by default and retains all renderers', () {
    expect(
      ActivityAmbientKineticField.rendererFor(const {}),
      ActivityAmbientRenderer.auroraGlass,
    );
    expect(
      ActivityAmbientKineticField.rendererFor(const {
        'activityAmbientAuroraGlassCandidate': 'true',
      }),
      ActivityAmbientRenderer.auroraGlass,
    );
    expect(
      ActivityAmbientKineticField.rendererFor(const {
        'activityAmbientNativeCandidate': 'true',
      }),
      ActivityAmbientRenderer.nativeFilament,
    );
    expect(
      ActivityAmbientKineticField.rendererFor(const {
        'activityAmbientLegacyReferenceMedia': 'true',
      }),
      ActivityAmbientRenderer.legacyReferenceMedia,
    );
    expect(ActivityAmbientKineticField.useAuroraGlassCandidate, isTrue);
    expect(ActivityAmbientAuroraGlassCandidate.gridColumns, 30);
    expect(ActivityAmbientAuroraGlassCandidate.eventFrequency, 2.09);
    expect(ActivityAmbientAuroraGlassCandidate.globalSeed, 51);
    expect(ActivityAmbientAuroraGlassCandidate.motionSpeed, .20);
    expect(ActivityAmbientAuroraGlassCandidate.motionVariation, .20);
    final source = File(
      'lib/features/activity/widgets/activity_ambient_aurora_glass_candidate.dart',
    ).readAsStringSync();
    expect(source, contains('class _AuroraGlassPainter'));
    expect(source, contains('double _tileState'));
    expect(source, contains('Rect _tileGeometry'));
    expect(source, contains('Color _tileRgb'));
    expect(source, contains('class _GlassMaterial'));
    expect(source, contains('class _CurvedFragmentEvent'));
    expect(source, contains('double activationAt'));
    expect(source, contains('static const eventFrequency = 2.09'));
    expect(source, contains('static const globalSeed = 51'));
    expect(source, contains('static const _deployedMotionSpeed = .40'));
    expect(
      source,
      contains('static const motionSpeed = _deployedMotionSpeed * .50'),
    );
    expect(source, contains('static const _deployedMotionVariation = .50'));
    expect(
      source,
      contains('static const motionVariation = _deployedMotionVariation * .40'),
    );
    expect(source, contains('final double waveSpeed;'));
    expect(source, contains('final double phase1;'));
    expect(source, contains('final double phase2;'));
    expect(source, contains('final double halfWidth;'));
    expect(source, contains('double _selectedFragment'));
    expect(source, contains('double _directionalWeight'));
    expect(source, contains('final deformedFront ='));
    expect(source, contains('double _smoothSpatialNoise'));
    expect(source, contains('double _fragmentNoise'));
    expect(source, contains('final localFront ='));
    expect(source, contains('final localWidth ='));
    expect(source, contains('var remaining = 1.0'));
    expect(source, contains('remaining *= 1 - contribution'));
    expect(source, contains('final activationDelay'));
    expect(source, contains('final thresholdOffset'));
    expect(source, contains('SchedulerBinding.instance.currentFrameTimeStamp'));
    expect(source, contains('double _eventNoise'));
    expect(source, contains('double _smoothStep'));
    expect(source, contains('final first = math.max('));
    expect(source, contains('elapsed - 3.9'));
    expect(source, contains('ceil() + 2'));
    expect(source, contains('clamp(4.0, 22.0) / 24'));
    expect(source, isNot(contains('referenceFrameCount')));
    expect(source, isNot(contains('referenceFramesPerSecond')));
    expect(source, isNot(contains('_activationEventCount')));
    expect(source, isNot(contains('_activationEpochCount')));
    expect(source, isNot(contains('_spatialTimingVariation')));
    expect(source, isNot(contains('_activationOriginCount')));
    expect(source, isNot(contains('_originLifecycle')));
    expect(source, isNot(contains('_originPosition')));
    expect(source, isNot(contains('final diagonal =')));
    expect(source, isNot(contains('final wave =')));
    expect(source, isNot(contains('final centerX =')));
    expect(source, isNot(contains('squareDistance')));
    expect(source, isNot(contains('_distributedClusterTiming')));
    expect(source, contains('drawRect'));
    expect(source, isNot(contains('HtmlElementView')));
    expect(source, isNot(contains('.mp4')));
  });

  test('Aurora Glass bypasses the scope HUD and circular clip', () {
    final source = File(
      'lib/features/activity/widgets/activity_ambient_kinetic_field.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'if (ActivityAmbientKineticField.useAuroraGlassCandidate)',
    );
    final end = source.indexOf('final geometry =', start);
    final auroraBranch = source.substring(start, end);
    expect(auroraBranch, contains('ActivityAmbientAuroraGlassCandidate'));
    expect(auroraBranch, isNot(contains('ClipOval')));
    expect(auroraBranch, isNot(contains('_MovingScopePainter')));
  });

  test('Activity action surfaces reuse the Dashboard glass material', () {
    final activitySource = File(
      'lib/features/activity/activity_page.dart',
    ).readAsStringSync();
    final buttonSource = File(
      'lib/core/widgets/operation_button.dart',
    ).readAsStringSync();
    expect(activitySource, contains('DashboardGlassCard'));
    expect(activitySource, contains('transparentSurface: true'));
    expect(buttonSource, contains('final bool transparentSurface'));
    expect(buttonSource, contains('backgroundColor: transparentSurface'));
  });

  test(
    'keeps the phase-one scope and swarm center stationary in its viewport',
    () {
      const painterSize = Size(390, 788);
      final samples = [
        for (var index = 0; index <= 200; index++)
          ActivityAmbientKineticField.scopeGeometryFor(
            painterSize: painterSize,
            phase: index / 200,
          ),
      ];
      for (final geometry in samples) {
        expect(geometry.center.dx, closeTo(painterSize.width / 2, .001));
        expect(geometry.center.dy, closeTo(painterSize.height / 2, .001));
        expect(geometry.scopeBounds.top, greaterThanOrEqualTo(0));
        expect(
          geometry.scopeBounds.bottom,
          lessThanOrEqualTo(painterSize.height),
        );
        expect(geometry.visibleScopeBounds, geometry.scopeBounds);
      }
    },
  );

  Future<void> pumpField(
    WidgetTester tester, {
    required bool enabled,
    bool reducedMotion = false,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: ActivityAmbientKineticField(enabled: enabled),
                ),
                const Center(child: Text('ACTIVITY CONTENT')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders behind Activity content without intercepting input', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    expect(find.byKey(ActivityAmbientKineticField.fieldKey), findsOneWidget);
    final ancestors = tester.widgetList<IgnorePointer>(
      find.ancestor(
        of: find.byKey(ActivityAmbientKineticField.fieldKey),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(ancestors.any((widget) => widget.ignoring), isTrue);
    expect(find.text('ACTIVITY CONTENT'), findsOneWidget);
  });

  testWidgets('suppresses the field immediately when disabled', (tester) async {
    await pumpField(tester, enabled: false);
    expect(find.byKey(ActivityAmbientKineticField.fieldKey), findsNothing);
  });

  testWidgets('native candidate renders a static reduced-motion frame', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 15),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 240,
          child: ActivityAmbientNativeCandidate(
            animation: controller,
            reducedMotion: true,
          ),
        ),
      ),
    );
    expect(find.byKey(ActivityAmbientNativeCandidate.fieldKey), findsOneWidget);
  });

  testWidgets('native candidate has a deterministic static composition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 15),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: ActivityAmbientNativeCandidate(
            animation: controller,
            reducedMotion: true,
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(ActivityAmbientNativeCandidate.fieldKey),
      matchesGoldenFile('goldens/activity_native_candidate_static.png'),
    );
  });

  testWidgets('native candidate evolves at an equivalent active phase', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 15),
    )..value = .5;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: ActivityAmbientNativeCandidate(
            animation: controller,
            reducedMotion: false,
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(ActivityAmbientNativeCandidate.fieldKey),
      matchesGoldenFile('goldens/activity_native_candidate_phase_06.png'),
    );
  });

  testWidgets('Aurora Glass candidate fills a static reduced-motion viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 15),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: ActivityAmbientAuroraGlassCandidate(
            animation: controller,
            reducedMotion: true,
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(ActivityAmbientAuroraGlassCandidate.fieldKey),
      matchesGoldenFile('goldens/activity_aurora_glass_fullscreen_static.png'),
    );
  });

  testWidgets('Aurora Glass candidate reorganizes across a full viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 15),
    )..value = .5;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: ActivityAmbientAuroraGlassCandidate(
            animation: controller,
            reducedMotion: false,
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(ActivityAmbientAuroraGlassCandidate.fieldKey),
      matchesGoldenFile(
        'goldens/activity_aurora_glass_fullscreen_phase_06.png',
      ),
    );
  });

  testWidgets('renders a valid static measurement field for reduced motion', (
    tester,
  ) async {
    await pumpField(tester, enabled: true, reducedMotion: true);
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile('goldens/activity_kinetic_measurement_static.png'),
    );
  });

  testWidgets(
    'renders the supplied reference composition at the initial phase',
    (tester) async {
      await pumpField(tester, enabled: true);
      await expectLater(
        find.byKey(ActivityAmbientKineticField.fieldKey),
        matchesGoldenFile(
          'goldens/activity_kinetic_measurement_vortex_prototype.png',
        ),
      );
    },
  );

  testWidgets('keeps the supplied composition aligned with the scanning HUD', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    await tester.pump(const Duration(seconds: 4));
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile('goldens/activity_kinetic_measurement_tracking.png'),
    );
  });

  testWidgets('keeps the supplied composition within the stationary scope', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    await tester.pump(const Duration(milliseconds: 12000));
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile('goldens/activity_kinetic_measurement_accumulated.png'),
    );
  });

  testWidgets('keeps the static fallback aligned while the HUD scans', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile(
        'goldens/activity_kinetic_measurement_lower_viewport.png',
      ),
    );
  });

  testWidgets('keeps the ambient composition stable through 30 seconds', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    for (var second = 0; second < 30; second++) {
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile('goldens/activity_kinetic_measurement_30_seconds.png'),
    );
  });

  testWidgets(
    'ActivityPage gives default Aurora Glass its full Scaffold body',
    (tester) async {
      final originalSettings = DeviceSettingsController.instance.value;
      DeviceSettingsController.instance.resetForTesting(
        const DeviceSettings(ambientKineticFieldEnabled: true),
      );
      addTearDown(
        () =>
            DeviceSettingsController.instance.resetForTesting(originalSettings),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: ActivityPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));

      final field = tester.getRect(
        find.byKey(ActivityAmbientKineticField.fieldKey),
      );
      expect(field.height, greaterThan(700));
      expect(field.top, greaterThanOrEqualTo(0));
      expect(field.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
      expect(
        find.byKey(ActivityAmbientAuroraGlassCandidate.fieldKey),
        findsOneWidget,
      );
      expect(find.byType(DashboardGlassCard), findsNWidgets(2));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/activity_scope_below_record.png'),
      );
    },
  );

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('keeps a full-height Aurora field at $width px', (
      tester,
    ) async {
      await pumpField(tester, enabled: true, width: width);
      final field = tester.getRect(
        find.byKey(ActivityAmbientKineticField.fieldKey),
      );
      final aurora = tester.getRect(
        find.byKey(ActivityAmbientAuroraGlassCandidate.fieldKey),
      );
      expect(field.width, closeTo(width, 1));
      expect(field.height, closeTo(700, 1));
      expect(aurora, field);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'aurora remains continuous across the former reference boundary',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390,
                height: 844,
                child: ActivityAmbientAuroraGlassCandidate(
                  animation: AlwaysStoppedAnimation<double>(0),
                  reducedMotion: false,
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 11460));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
