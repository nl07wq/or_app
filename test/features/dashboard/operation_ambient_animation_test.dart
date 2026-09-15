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
    TextScaler textScaler = TextScaler.noScaling,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        textScaler: textScaler,
      ),
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

  testWidgets('recorded labels share the left quiet-zone center axis', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      for (final entry in const <(OperationStatus, String, Color)>[
        (OperationStatus.green, 'FINE', AppColors.success),
        (OperationStatus.yellow, 'CAUTION', AppColors.warning),
        (OperationStatus.red, 'DANGER', AppColors.danger),
      ]) {
        await tester.pumpWidget(subject(entry.$1, width: width));
        final label = find.text(entry.$2);
        final slot = find.byKey(
          const ValueKey('operation-ambient-animation-slot'),
        );
        expect(label, findsOneWidget);
        expect(
          find.byKey(const ValueKey('operation-ambient-status-label')),
          findsOneWidget,
        );
        expect(tester.widget<Text>(label).style?.color, entry.$3);
        expect(tester.widget<Text>(label).style?.fontSize, 9);
        expect(tester.widget<Text>(label).style?.fontFamily, 'ShareTechMono');
        expect(tester.widget<Text>(label).style?.fontWeight, FontWeight.w400);
        expect(tester.widget<Text>(label).style?.letterSpacing, .25);
        final labelBounds = tester.getRect(label);
        final slotBounds = tester.getRect(slot);
        final expectedCenter =
            slotBounds.left + OperationAmbientStatusLabel.noWaveZoneWidth() / 2;
        expect(labelBounds.center.dx, closeTo(expectedCenter, .01));
        expect(OperationAmbientStatusLabel.bottomPadding, 0);
        expect(labelBounds.bottom, slotBounds.bottom);
        expect(labelBounds.left, greaterThanOrEqualTo(slotBounds.left));
        expect(
          labelBounds.right,
          lessThanOrEqualTo(
            slotBounds.left + OperationAmbientStatusLabel.noWaveZoneWidth(),
          ),
        );
      }
    }

    await tester.pumpWidget(subject(null));
    expect(find.text('FINE'), findsNothing);
    expect(find.text('CAUTION'), findsNothing);
    expect(find.text('DANGER'), findsNothing);
    expect(
      find.byKey(const ValueKey('operation-ambient-status-label')),
      findsNothing,
    );
  });

  testWidgets('reduced motion retains the recorded status label', (
    tester,
  ) async {
    await tester.pumpWidget(subject(OperationStatus.red, reducedMotion: true));
    expect(find.text('DANGER'), findsOneWidget);
    expect(painter(tester).staticFrame, isTrue);
  });

  testWidgets('scaled status text stays centered in its scaled quiet zone', (
    tester,
  ) async {
    const textScaler = TextScaler.linear(1.4);
    await tester.pumpWidget(
      subject(OperationStatus.yellow, textScaler: textScaler),
    );
    final labelBounds = tester.getRect(find.text('CAUTION'));
    final slotBounds = tester.getRect(
      find.byKey(const ValueKey('operation-ambient-animation-slot')),
    );
    final zoneWidth = OperationAmbientStatusLabel.noWaveZoneWidth(textScaler);
    expect(
      labelBounds.center.dx,
      closeTo(slotBounds.left + zoneWidth / 2, .01),
    );
    expect(labelBounds.right, lessThanOrEqualTo(slotBounds.left + zoneWidth));
  });

  testWidgets('GREEN uses the strongest canonical ECG pulse preset', (
    tester,
  ) async {
    await tester.pumpWidget(subject(OperationStatus.green));

    final activePainter = painter(tester);
    expect(activePainter.preset, OperationAmbientPulsePreset.green);
    expect(activePainter.geometry.waveform, OperationAmbientWaveform.ecg);
    expect(activePainter.geometry.color, AppColors.success);
    expect(activePainter.geometry.amplitude, 12);
    expect(activePainter.staticFrame, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(activePainter.phase.value, greaterThan(0));
  });

  testWidgets(
    'recorded statuses use inverse amplitude and activity-density semantics',
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
      expect(geometries[0].waveLength, greaterThan(geometries[1].waveLength));
      expect(geometries[1].waveLength, greaterThan(geometries[2].waveLength));
      expect(geometries[0].waveLength, 80);
      expect(geometries[1].waveLength, 40);
      expect(geometries[2].waveLength, 15);
      expect(geometries.map((geometry) => geometry.amplitude), [12, 10, 5]);
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
      expect(activePainter.currentTraceIndex, 0);
      expect(activePainter.nextTraceIndex, 1);

      const size = Size(390, OperationAmbientAnimation.height);
      for (final progress in [0.0, .25, .5, .75]) {
        final regions = activePainter.sweepRegionsFor(
          size,
          phaseValue: progress,
        );
        expect(regions.newTrace.width + regions.oldTrace.width, greaterThan(0));
        expect(regions.clear.width, lessThanOrEqualTo(8));
      }
      final complete = activePainter.sweepRegionsFor(size, phaseValue: 1);
      expect(complete.newTrace.right, size.width);
      expect(complete.clear, Rect.zero);
      expect(complete.oldTrace, Rect.zero);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('traces are deterministic, organic, and vary by generation', (
    tester,
  ) async {
    await tester.pumpWidget(subject(OperationStatus.green));
    final activePainter = painter(tester);
    const size = Size(900, OperationAmbientAnimation.height);
    final first = activePainter.traceEventsFor(size, 3);
    final repeated = activePainter.traceEventsFor(size, 3);
    final next = activePainter.traceEventsFor(size, 4);
    expect(_signature(first), _signature(repeated));
    expect(_signature(first), isNot(_signature(next)));
    expect(first.map((event) => event.family).toSet().length, greaterThan(1));
    expect(
      List.generate(
        12,
        (index) => activePainter.traceEventsFor(size, index),
      ).expand((events) => events).map((event) => event.family).toSet(),
      containsAll(OperationAmbientEcgFamily.values.take(4)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      _signature(activePainter.traceEventsFor(size, 3)),
      _signature(first),
    );
  });

  testWidgets('status-specific traces get denser as vitality weakens', (
    tester,
  ) async {
    const size = Size(390, OperationAmbientAnimation.height);
    final counts = <int>[];
    for (final status in const [
      OperationStatus.green,
      OperationStatus.yellow,
      OperationStatus.red,
    ]) {
      await tester.pumpWidget(subject(status));
      final activePainter = painter(tester);
      counts.add(
        activePainter.eventCountFor(size, activePainter.currentTraceIndex),
      );
    }
    expect(counts[0], lessThan(counts[1]));
    expect(counts[1], lessThan(counts[2]));
    expect(counts[0], inInclusiveRange(3, 5));
    // Edge zones intentionally reduce absolute full-lane counts without
    // changing the status density contract inside the active range.
    expect(counts[1], greaterThanOrEqualTo(6));
    expect(counts[2], greaterThanOrEqualTo(15));
  });

  testWidgets('organic events use bounded irregular spacing and envelopes', (
    tester,
  ) async {
    const size = Size(900, OperationAmbientAnimation.height);
    for (final status in const [
      OperationStatus.green,
      OperationStatus.yellow,
      OperationStatus.red,
    ]) {
      await tester.pumpWidget(subject(status));
      final activePainter = painter(tester);
      final events = activePainter.traceEventsFor(size, 5);
      final intervals = [
        for (var index = 1; index < events.length; index++)
          events[index].x - events[index - 1].x,
      ];
      expect(intervals.toSet().length, greaterThan(1));
      final nominal = activePainter.geometry.waveLength;
      final range = switch (activePainter.preset) {
        OperationAmbientPulsePreset.green ||
        OperationAmbientPulsePreset.yellow => (
          minimum: nominal * .70,
          maximum: nominal * 1.30,
        ),
        OperationAmbientPulsePreset.red => (minimum: 11.0, maximum: 20.0),
        OperationAmbientPulsePreset.neutral => (
          minimum: nominal,
          maximum: nominal,
        ),
      };
      expect(
        intervals.every(
          (interval) => interval >= range.minimum && interval <= range.maximum,
        ),
        isTrue,
      );
      final average =
          intervals.reduce((sum, interval) => sum + interval) /
          intervals.length;
      expect(average, closeTo(nominal, nominal * .20));
      expect(events.map((event) => event.width).toSet().length, greaterThan(1));
      expect(
        events.map((event) => event.heightFactor).toSet().length,
        greaterThan(1),
      );
      expect(events.every((event) => event.heightFactor >= .65), isTrue);
      expect(events.every((event) => event.heightFactor <= 1), isTrue);
      expect(
        events.every((event) => event.width > 0 && event.right <= size.width),
        isTrue,
      );
      for (var index = 1; index < events.length; index++) {
        expect(events[index].x, greaterThan(events[index - 1].right));
      }
      expect(
        events.map((event) => event.positiveFirst).toSet().length,
        greaterThan(1),
      );
    }
  });

  testWidgets('recorded events reserve symmetric label-safe baseline zones', (
    tester,
  ) async {
    final expectedZone = OperationAmbientStatusLabel.noWaveZoneWidth();
    for (final width in [320.0, 390.0, 900.0]) {
      final size = Size(width, OperationAmbientAnimation.height);
      for (final status in const [
        OperationStatus.green,
        OperationStatus.yellow,
        OperationStatus.red,
      ]) {
        await tester.pumpWidget(subject(status, width: width));
        final activePainter = painter(tester);
        final activeRange = activePainter.activeEventRangeFor(size);
        expect(activePainter.noWaveInset, expectedZone);
        expect(activeRange.left, expectedZone);
        expect(size.width - activeRange.right, expectedZone);
        final events = activePainter.traceEventsFor(size, 4);
        expect(events, isNotEmpty);
        expect(events.every((event) => event.x >= activeRange.left), isTrue);
        expect(
          events.every((event) => event.right <= activeRange.right),
          isTrue,
        );
        expect(events.first.x, greaterThanOrEqualTo(activeRange.left));
        expect(events.last.right, lessThanOrEqualTo(activeRange.right));
      }
    }
  });

  testWidgets('steady sweep keeps an eight pixel clear window and local head', (
    tester,
  ) async {
    await tester.pumpWidget(subject(OperationStatus.red));
    await tester.pump(
      OperationAmbientAnimation.drawDuration + const Duration(milliseconds: 20),
    );
    await tester.pump();
    final activePainter = painter(tester);
    const size = Size(390, OperationAmbientAnimation.height);
    final regions = activePainter.sweepRegionsFor(size, phaseValue: .5);
    final head = activePainter.activeHeadRegionFor(size, phaseValue: .5);
    expect(regions.clear.width, OperationAmbientPulsePainter.clearWindowWidth);
    expect(OperationAmbientPulsePainter.clearWindowWidth, 8);
    expect(head.width, OperationAmbientPulsePainter.activeHeadLength);
    expect(head.right, regions.clear.left);
    expect(
      OperationAmbientPulsePainter.activeHeadStrokeWidth,
      greaterThan(OperationAmbientPulsePainter.traceStrokeWidth),
    );
    expect(
      OperationAmbientPulsePainter.activeHeadStrokeWidth -
          OperationAmbientPulsePainter.traceStrokeWidth,
      lessThanOrEqualTo(1),
    );
  });

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
      for (final status in const [
        OperationStatus.green,
        OperationStatus.yellow,
        OperationStatus.red,
      ]) {
        await tester.pumpWidget(subject(status, width: width));
        final slot = find.byKey(
          const ValueKey('operation-ambient-animation-slot'),
        );
        expect(tester.getSize(slot).height, OperationAmbientAnimation.height);
        expect(tester.getSize(slot).width, width);
        final geometry = painter(tester).geometry;
        final center = OperationAmbientAnimation.height / 2;
        expect(center - geometry.amplitude, greaterThanOrEqualTo(.5));
        expect(
          center + geometry.amplitude,
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
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('reduced motion uses a deterministic static status trace', (
    tester,
  ) async {
    await tester.pumpWidget(subject(OperationStatus.red, reducedMotion: true));
    final activePainter = painter(tester);
    const size = Size(390, OperationAmbientAnimation.height);
    expect(activePainter.staticFrame, isTrue);
    expect(activePainter.activeHeadRegionFor(size), Rect.zero);
    expect(
      activePainter.eventCountFor(size, activePainter.currentTraceIndex),
      greaterThan(0),
    );
  });
}

String _signature(List<OperationAmbientEcgEvent> events) => events
    .map(
      (event) =>
          '${event.family.name}:${event.x.toStringAsFixed(3)}:${event.width.toStringAsFixed(3)}:${event.heightFactor.toStringAsFixed(3)}:${event.secondaryFactor.toStringAsFixed(3)}',
    )
    .join('|');
