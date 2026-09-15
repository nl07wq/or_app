import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/operation_status.dart';
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

  testWidgets('GREEN uses the calm canonical pulse preset', (tester) async {
    await tester.pumpWidget(subject(OperationStatus.green));

    expect(painter(tester).preset, OperationAmbientPulsePreset.green);
    expect(painter(tester).staticFrame, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(painter(tester).phase.value, greaterThan(0));
  });

  testWidgets('YELLOW and RED update the waveform preset while mounted', (
    tester,
  ) async {
    await tester.pumpWidget(subject(OperationStatus.green));
    expect(painter(tester).preset, OperationAmbientPulsePreset.green);

    await tester.pumpWidget(subject(OperationStatus.yellow));
    expect(painter(tester).preset, OperationAmbientPulsePreset.yellow);

    await tester.pumpWidget(subject(OperationStatus.red));
    expect(painter(tester).preset, OperationAmbientPulsePreset.red);
  });

  testWidgets(
    'unknown status uses neutral fallback and reduced motion is static',
    (tester) async {
      await tester.pumpWidget(subject(null, reducedMotion: true));

      expect(painter(tester).preset, OperationAmbientPulsePreset.neutral);
      expect(painter(tester).staticFrame, isTrue);
      final phase = painter(tester).phase.value;
      await tester.pump(const Duration(seconds: 8));
      expect(painter(tester).phase.value, phase);
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

  testWidgets('slot remains a thin responsive non-interactive layer', (
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
