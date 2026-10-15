import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/morning/widgets/status_radial_spectrum_ambient.dart';

void main() {
  test('declares a dense native radial spectrum without media assets', () {
    expect(StatusRadialSpectrumAmbient.barCount, 144);
    expect(StatusRadialSpectrumAmbient.bubbleCount, 96);
    expect(
      StatusRadialSpectrumAmbient.cycleDuration,
      const Duration(seconds: 24),
    );
    expect(StatusRadialSpectrumAmbient.equalizerSpeedMultiplier, 1.5);
    expect(StatusRadialSpectrumAmbient.equalizerAmplitudeMultiplier, 1.3);
    expect(StatusRadialSpectrumAmbient.amplitudeTargetUpdatesPerSecond, 10);
    expect(
      StatusRadialSpectrumAmbient.amplitudeAttack,
      const Duration(milliseconds: 60),
    );
    expect(
      StatusRadialSpectrumAmbient.amplitudeRelease,
      const Duration(milliseconds: 140),
    );
    expect(
      StatusRadialSpectrumAmbient.pulseMinimumInterval,
      const Duration(seconds: 3),
    );
    expect(
      StatusRadialSpectrumAmbient.pulseMaximumInterval,
      const Duration(seconds: 6),
    );
    expect(
      StatusRadialSpectrumAmbient.pulseAttack,
      const Duration(milliseconds: 65),
    );
    expect(
      StatusRadialSpectrumAmbient.pulseCompression,
      const Duration(milliseconds: 90),
    );
    expect(
      StatusRadialSpectrumAmbient.pulseRecovery,
      const Duration(milliseconds: 180),
    );
    expect(
      StatusRadialSpectrumAmbient.pulseDuration,
      const Duration(milliseconds: 335),
    );
    expect(StatusRadialSpectrumAmbient.pulseMaximumScale, 1.20);
    expect(StatusRadialSpectrumAmbient.pulseCompressionScale, .94);
    expect(StatusRadialSpectrumAmbient.pulseMaximumDisplacement, 14.0);
    expect(StatusRadialSpectrumAmbient.flameSampleCount, 216);

    final source = File(
      'lib/features/morning/widgets/status_radial_spectrum_ambient.dart',
    ).readAsStringSync();
    expect(source, contains('class _StatusRadialSpectrumPainter'));
    expect(source, contains('Offset.fromDirection'));
    expect(source, isNot(contains('localBand')));
    expect(source, isNot(contains('travelingPeak')));
    expect(source, contains('void _paintDonut'));
    expect(source, contains('void _paintBubbles'));
    expect(source, contains('SweepGradient'));
    expect(source, contains('static const _donutPalette'));
    expect(source, contains('final colorTime ='));
    expect(source, contains('colorTime / (math.pi * 2)'));
    expect(source, contains('final edgeFade ='));
    expect(source, contains('StatusRadialSpectrumAmbient.bubbleCount'));
    expect(source, contains('equalizerSpeedMultiplier'));
    expect(source, contains('equalizerAmplitudeMultiplier'));
    expect(source, contains('class _FastSpectrumMotion'));
    expect(source, contains('static const _updateHz'));
    expect(source, contains('static const _attackSeconds = .060'));
    expect(source, contains('static const _releaseSeconds = .140'));
    expect(source, contains('final neighborhood ='));
    expect(source, contains('final tallPeak ='));
    expect(source, contains('_spectrumMotion.amplitudeFor'));
    expect(source, contains('class _StatusPulseMotion'));
    expect(source, contains('_pulseMotion.stateFor'));
    expect(source, contains('_pulseMotion.jitterFor'));
    expect(source, contains('canvas.scale(pulse.scale, pulse.scale)'));
    expect(source, contains('void _paintImpactField'));
    expect(source, contains('final _ringBandPath = Path()'));
    expect(source, contains('final _ringOuterPath = Path()'));
    expect(source, contains('final _hudMarkingPath = Path()'));
    expect(source, contains('StatusRadialSpectrumAmbient.flameSampleCount'));
    expect(source, contains('void _appendDeformedRingContour'));
    expect(source, contains('void _paintHudRingPattern'));
    expect(source, contains('const Color(0x7003060D)'));
    expect(source, contains('for (var track = 0; track < 3; track++)'));
    expect(source, contains('markings.addOval'));
    expect(source, isNot(contains('const segmentCount = 13')));
    expect(source, contains('double _flameContourExtension'));
    expect(source, isNot(contains('_flameTonguePath')));
    expect(source, contains('static const _flameTongueCount = 26'));
    expect(source, contains('static const _flameMotionSpeed = 2.45'));
    expect(source, contains('static const _flameMotionAmplitude = .96'));
    expect(source, contains('final emergence'));
    expect(source, contains('final extensionPhase'));
    expect(source, contains('final curlPhase'));
    expect(source, contains('final thinning'));
    expect(source, contains('final rootWidth'));
    expect(source, contains('final stratifiedRoot'));
    expect(source, contains('final rootJitter'));
    expect(source, contains('final quietRootMotion'));
    expect(source, contains('final bodyCenter'));
    expect(source, contains('final tipCenter'));
    expect(source, contains('final curlDirection'));
    expect(source, contains('double _flameLobe('));
    expect(source, contains('math.pow(normalized, exponent)'));
    expect(source, contains('path.lineTo(point.dx, point.dy)'));
    expect(source, isNot(contains('path.quadraticBezierTo')));
    expect(source, contains('final _donutEdgeCore = Paint()'));
    expect(source, contains('..strokeJoin = StrokeJoin.miter'));
    expect(source, contains('..drawPath(outer, _donutEdgeCore)'));
    expect(source, contains('final lifetime'));
    expect(source, contains('deformed: false'));
    expect(source, contains('extension * _flameMotionAmplitude'));
    expect(source, contains('clamp(-.35, 11.2)'));
    expect(source, isNot(contains('double _amplitude')));
    expect(source, contains('class _SpectrumLayout'));
    expect(source, contains('final _barBroadHalo'));
    expect(source, contains('(1.25 + amplitude * 1.65) * 1.5'));
    expect(source, contains('(.55 + amplitude * .68) * 1.5'));
    expect(source, contains('(.20 + amplitude * .32) * 1.5'));
    expect(
      source,
      contains('donutOuterRadius - donutThickness * .12'),
    );
    expect(source, contains('visibleThickness * (.26 + pulse * .045)'));
    expect(source, contains('drawCircle(point'));
    expect(source, isNot(contains('HtmlElementView')));
    expect(source, isNot(contains('.mp4')));
  });

  Future<void> pumpAmbient(
    WidgetTester tester, {
    required double width,
    bool enabled = true,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = Size(width, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              StatusRadialSpectrumAmbient(
                enabled: enabled,
                reducedMotion: reducedMotion,
              ),
              const Center(child: Text('STATUS CONTENT')),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('keeps STATUS content interactive above the radial spectrum', (
    tester,
  ) async {
    await pumpAmbient(tester, width: 390);

    final field = find.byKey(StatusRadialSpectrumAmbient.fieldKey);
    expect(field, findsOneWidget);
    expect(find.text('STATUS CONTENT'), findsOneWidget);
    final ignores = tester.widgetList<IgnorePointer>(
      find.ancestor(of: field, matching: find.byType(IgnorePointer)),
    );
    expect(ignores.any((widget) => widget.ignoring), isTrue);
  });

  testWidgets('renders a deterministic static reduced-motion composition', (
    tester,
  ) async {
    await pumpAmbient(tester, width: 390, reducedMotion: true);
    await expectLater(
      find.byKey(StatusRadialSpectrumAmbient.fieldKey),
      matchesGoldenFile('goldens/status_radial_spectrum_static.png'),
    );
  });

  testWidgets('animates the radial bars without rendering failures', (
    tester,
  ) async {
    await pumpAmbient(tester, width: 390);
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(StatusRadialSpectrumAmbient.fieldKey),
      matchesGoldenFile('goldens/status_radial_spectrum_phase.png'),
    );
  });

  testWidgets('keeps flame evolution stable across multiple lifecycle phases', (
    tester,
  ) async {
    await pumpAmbient(tester, width: 390);
    for (final elapsed in const [
      Duration(milliseconds: 700),
      Duration(milliseconds: 1500),
      Duration(milliseconds: 2300),
      Duration(milliseconds: 3100),
    ]) {
      await tester.pump(elapsed);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'renders the deterministic ambient pulse without moving STATUS UI',
    (tester) async {
      await pumpAmbient(tester, width: 390);
      // The first V2 power pulse begins at 3.42 seconds.
      await tester.pump(const Duration(milliseconds: 3500));
      expect(find.text('STATUS CONTENT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hides immediately when the ambient setting is disabled', (
    tester,
  ) async {
    await pumpAmbient(tester, width: 390, enabled: false);
    expect(find.byKey(StatusRadialSpectrumAmbient.fieldKey), findsNothing);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('fills the STATUS viewport at $width px', (tester) async {
      await pumpAmbient(tester, width: width, reducedMotion: true);
      final bounds = tester.getRect(
        find.byKey(StatusRadialSpectrumAmbient.fieldKey),
      );
      expect(bounds.width, closeTo(width, .01));
      expect(bounds.height, closeTo(760, .01));
      expect(tester.takeException(), isNull);
    });
  }
}
