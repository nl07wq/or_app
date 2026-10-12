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
    expect(StatusRadialSpectrumAmbient.indicatorStrokeWidthMultiplier, 1.5);
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
      StatusRadialSpectrumAmbient.pulseIntervalMinimum,
      const Duration(seconds: 3),
    );
    expect(
      StatusRadialSpectrumAmbient.pulseIntervalMaximum,
      const Duration(seconds: 10),
    );

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
    expect(source, contains('class _StatusPulse'));
    expect(source, contains('StatusRadialSpectrumAmbient.pulseIntervalMinimum'));
    expect(source, contains('StatusRadialSpectrumAmbient.pulseIntervalMaximum'));
    expect(source, contains('indicatorStrokeWidthMultiplier'));
    expect(source, contains('static const _updateHz'));
    expect(source, contains('static const _attackSeconds = .060'));
    expect(source, contains('static const _releaseSeconds = .140'));
    expect(source, contains('final neighborhood ='));
    expect(source, contains('final tallPeak ='));
    expect(source, contains('_spectrumMotion.amplitudeFor'));
    expect(source, isNot(contains('double _amplitude')));
    expect(source, contains('class _SpectrumLayout'));
    expect(source, contains('final _barBroadHalo'));
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
