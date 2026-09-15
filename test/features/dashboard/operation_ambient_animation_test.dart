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
      expect(
        OperationAmbientPulsePainter.ecgPulseEndFraction -
            OperationAmbientPulsePainter.ecgPulseStartFraction,
        lessThan(.5),
      );
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

  testWidgets('loop repeats without accumulating a translated offset', (
    tester,
  ) async {
    await tester.pumpWidget(subject(OperationStatus.red));
    await tester.pump(const Duration(seconds: 2));
    final firstPhase = painter(tester).phase.value;
    await tester.pump(OperationAmbientAnimation.loopDuration);

    expect(painter(tester).phase.value, moreOrLessEquals(firstPhase));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ECG baseline coverage extends beyond both lane edges at every phase',
    (tester) async {
      const phases = [0.0, .25, .5, .75, .99, 1.0];
      for (final width in [320.0, 390.0, 900.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(subject(OperationStatus.green, width: width));
        final activePainter = painter(tester);

        for (final phase in phases) {
          final coverage = activePainter.coverageFor(
            Size(width, OperationAmbientAnimation.height),
            phaseValue: phase,
          );
          expect(coverage.left, lessThanOrEqualTo(0));
          expect(coverage.right, greaterThanOrEqualTo(width));
          expect(coverage.left, lessThan(0));
          expect(coverage.right, greaterThan(width));
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('ECG coverage has identical bounds at the loop seam', (
    tester,
  ) async {
    await tester.pumpWidget(subject(OperationStatus.red));
    final activePainter = painter(tester);
    final zero = activePainter.coverageFor(
      const Size(390, OperationAmbientAnimation.height),
      phaseValue: 0,
    );
    final wrap = activePainter.coverageFor(
      const Size(390, OperationAmbientAnimation.height),
      phaseValue: 1,
    );

    expect(wrap.left, zero.left);
    expect(wrap.right, zero.right);
  });

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
