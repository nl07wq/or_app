import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/operation_status.dart';
import 'package:or_app/core/theme/app_colors.dart';
import 'package:or_app/features/dashboard/widgets/operation_ambient_animation.dart';

void main() {
  Widget subject(
    OperationStatus? status, {
    bool reducedMotion = false,
    double width = 390,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: SizedBox(
          width: width,
          child: OperationAmbientAnimation(status: status),
        ),
      ),
    ),
  );

  OperationAmbientPulsePainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('operation-ambient-animation-paint')),
              )
              .painter!
          as OperationAmbientPulsePainter;

  testWidgets('GREEN uses the strongest canonical ECG pulse preset', (
    tester,
  ) async {
    await tester.pumpWidget(subject(OperationStatus.green));

    final activePainter = painter(tester);
    expect(activePainter.preset, OperationAmbientPulsePreset.green);
    expect(activePainter.geometry.waveform, OperationAmbientWaveform.ecg);
    expect(activePainter.geometry.color, AppColors.success);
    expect(activePainter.geometry.amplitude, 4);
    expect(activePainter.staticFrame, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(activePainter.phase.value, greaterThan(0));
  });

  testWidgets(
    'recorded statuses use one calm ECG period with descending amplitude',
    (tester) async {
      final geometries = <OperationAmbientPulseGeometry>[];
      for (final status in const [
        OperationStatus.green,
        OperationStatus.yellow,
        OperationStatus.red,
      ]) {
        await tester.pumpWidget(subject(status));
        geometries.add(painter(tester).geometry);
      }

      expect(
        geometries.every(
          (geometry) => geometry.waveform == OperationAmbientWaveform.ecg,
        ),
        isTrue,
      );
      expect(geometries[0].waveLength, geometries[1].waveLength);
      expect(geometries[1].waveLength, geometries[2].waveLength);
      expect(geometries.first.waveLength, 240);
      final fractions = painter(
        tester,
      ).pulseFractionsFor(OperationAmbientEcgVariant.a);
      expect(fractions.last - fractions.first, lessThan(.5));
      expect(geometries[0].amplitude, greaterThan(geometries[1].amplitude));
      expect(geometries[1].amplitude, greaterThan(geometries[2].amplitude));
      expect(geometries.map((geometry) => geometry.color), [
        AppColors.success,
        AppColors.warning,
        AppColors.danger,
      ]);
      expect(
        OperationAmbientAnimation.loopDuration,
        const Duration(seconds: 6),
      );
    },
  );

  testWidgets('status transitions replace both waveform geometry and color', (
    tester,
  ) async {
    await tester.pumpWidget(subject(null));
    expect(painter(tester).geometry.waveform, OperationAmbientWaveform.sine);
    expect(painter(tester).geometry.color, AppColors.secondary);

    await tester.pumpWidget(subject(OperationStatus.yellow));
    expect(painter(tester).preset, OperationAmbientPulsePreset.yellow);
    expect(painter(tester).geometry.waveform, OperationAmbientWaveform.ecg);
    expect(painter(tester).geometry.color, AppColors.warning);

    await tester.pumpWidget(subject(OperationStatus.red));
    expect(painter(tester).preset, OperationAmbientPulsePreset.red);
    expect(painter(tester).geometry.color, AppColors.danger);

    await tester.pumpWidget(subject(null));
    expect(painter(tester).preset, OperationAmbientPulsePreset.neutral);
    expect(painter(tester).geometry.waveform, OperationAmbientWaveform.sine);
    expect(painter(tester).geometry.color, AppColors.secondary);
  });

  testWidgets(
    'unknown status uses neutral fallback and reduced motion is static',
    (tester) async {
      await tester.pumpWidget(subject(null, reducedMotion: true));

      final activePainter = painter(tester);
      expect(activePainter.preset, OperationAmbientPulsePreset.neutral);
      expect(activePainter.geometry.waveform, OperationAmbientWaveform.sine);
      expect(activePainter.geometry.color, AppColors.secondary);
      expect(activePainter.staticFrame, isTrue);
      final phase = activePainter.phase.value;
      await tester.pump(const Duration(seconds: 8));
      expect(activePainter.phase.value, phase);
    },
  );

  testWidgets('recorded ECG initializes from the left to the right edge', (
    tester,
  ) async {
    await tester.pumpWidget(subject(OperationStatus.green));
    final activePainter = painter(tester);
    const size = Size(390, OperationAmbientAnimation.height);
    var previous = -1.0;
    for (final progress in [0.0, .25, .5, .75, 1.0]) {
      final extent = activePainter.coverageFor(size, phaseValue: progress);
      expect(extent.left, 0);
      expect(extent.right, greaterThanOrEqualTo(previous));
      expect(extent.right, moreOrLessEquals(size.width * progress));
      previous = extent.right;
    }
    expect(activePainter.coverageFor(size, phaseValue: 1).right, size.width);
    expect(activePainter.sweepPhase, OperationAmbientSweepPhase.initialize);
  });

  testWidgets(
    'initial trace becomes a continuous rewrite sweep without a blank reset',
    (tester) async {
      await tester.pumpWidget(subject(OperationStatus.red));
      await tester.pump(
        OperationAmbientAnimation.drawDuration +
            const Duration(milliseconds: 20),
      );
      await tester.pump();
      final activePainter = painter(tester);
      expect(activePainter.sweepPhase, OperationAmbientSweepPhase.sweep);
      expect(activePainter.currentVariant, OperationAmbientEcgVariant.a);
      expect(activePainter.nextVariant, OperationAmbientEcgVariant.b);

      const size = Size(390, OperationAmbientAnimation.height);
      for (final progress in [0.0, .25, .5, .75]) {
        final regions = activePainter.sweepRegionsFor(
          size,
          phaseValue: progress,
        );
        expect(regions.newTrace.width + regions.oldTrace.width, greaterThan(0));
        expect(
          regions.clear.width,
          lessThanOrEqualTo(OperationAmbientPulsePainter.clearWindowWidth),
        );
      }
      final complete = activePainter.sweepRegionsFor(size, phaseValue: 1);
      expect(complete.newTrace.right, size.width);
      expect(complete.clear, Rect.zero);
      expect(complete.oldTrace, Rect.zero);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'variants are distinct, deterministic, and never change per frame',
    (tester) async {
      await tester.pumpWidget(subject(OperationStatus.green));
      final activePainter = painter(tester);
      expect(
        activePainter.pulseFractionsFor(OperationAmbientEcgVariant.a),
        isNot(activePainter.pulseFractionsFor(OperationAmbientEcgVariant.b)),
      );
      expect(
        activePainter.pulseFractionsFor(OperationAmbientEcgVariant.b),
        isNot(activePainter.pulseFractionsFor(OperationAmbientEcgVariant.c)),
      );
      final current = activePainter.currentVariant;
      final next = activePainter.nextVariant;
      await tester.pump(const Duration(seconds: 1));
      expect(activePainter.currentVariant, current);
      expect(activePainter.nextVariant, next);

      final sequence = [
        OperationAmbientEcgVariant.a,
        OperationAmbientEcgVariant.b,
        OperationAmbientEcgVariant.c,
        OperationAmbientEcgVariant.a,
      ];
      for (var index = 0; index < sequence.length - 1; index++) {
        expect(
          OperationAmbientPulsePainter.nextVariantAfter(sequence[index]),
          sequence[index + 1],
        );
      }
    },
  );

  testWidgets(
    'complete fixed trace reaches the right edge at responsive widths',
    (tester) async {
      for (final width in [320.0, 390.0, 900.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(subject(OperationStatus.yellow, width: width));
        final extent = painter(tester).sweepRegionsFor(
          Size(width, OperationAmbientAnimation.height),
          phaseValue: 1,
        );
        expect(extent.newTrace.left, 0);
        expect(extent.newTrace.right, width);
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('ECG extrema remain inside the responsive non-interactive lane', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(subject(OperationStatus.yellow, width: width));
      final slot = find.byKey(
        const ValueKey('operation-ambient-animation-slot'),
      );
      expect(tester.getSize(slot).height, OperationAmbientAnimation.height);
      expect(tester.getSize(slot).width, width);
      final geometry = painter(tester).geometry;
      final center = OperationAmbientAnimation.height / 2;
      expect(center - geometry.amplitude, greaterThanOrEqualTo(.5));
      expect(
        center + geometry.amplitude * .55,
        lessThanOrEqualTo(OperationAmbientAnimation.height - .5),
      );
      expect(
        find.descendant(
          of: find.byType(OperationAmbientAnimation),
          matching: find.byWidgetPredicate(
            (widget) => widget is IgnorePointer && widget.ignoring,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
