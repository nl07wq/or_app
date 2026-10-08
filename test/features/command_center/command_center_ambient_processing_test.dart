import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/command_center/widgets/command_center_ambient_processing.dart';

void main() {
  test('exposes V2.10 MID-REAR density and speed models', () {
    expect(CommandCenterAmbientProcessing.foregroundColumnsAt390, 30);
    expect(CommandCenterAmbientProcessing.midFrontColumnsAt390, 33);
    expect(CommandCenterAmbientProcessing.midRearColumnsAt390, 12);
    expect(CommandCenterAmbientProcessing.totalColumnsAt390, 75);
    expect(
      CommandCenterAmbientProcessing.midRearColumnsAt390For(
        CommandCenterMidRearDensity.medium,
      ),
      21,
    );
    expect(
      CommandCenterAmbientProcessing.midRearColumnsAt390For(
        CommandCenterMidRearDensity.high,
      ),
      31,
    );
    final speeds = CommandCenterAmbientProcessing.speeds;
    expect(speeds[DataRainSpeed.slow], lessThan(speeds[DataRainSpeed.normal]!));
    expect(speeds[DataRainSpeed.normal], lessThan(speeds[DataRainSpeed.fast]!));
    expect(speeds[DataRainSpeed.fast], lessThan(speeds[DataRainSpeed.burst]!));
  });

  test('allocates exact real streams for each MID-REAR density at 390', () {
    for (final entry in const {
      CommandCenterMidRearDensity.low: (12, 75),
      CommandCenterMidRearDensity.medium: (21, 84),
      CommandCenterMidRearDensity.high: (31, 94),
    }.entries) {
      final density = entry.key;
      final placements = [
        for (final layer in DataRainLayer.values)
          ...CommandCenterAmbientProcessing.streamPlacementsFor(
            layer: layer,
            width: 390,
            midRearDensity: density,
          ),
      ];
      int count(DataRainHorizontalBand band) =>
          placements.where((placement) => placement.band == band).length;
      expect(placements.length, entry.value.$2);
      expect(count(DataRainHorizontalBand.left), greaterThan(0));
      expect(count(DataRainHorizontalBand.center), greaterThan(0));
      expect(count(DataRainHorizontalBand.right), greaterThan(0));
      expect(
        CommandCenterAmbientProcessing.streamPlacementsFor(
          layer: DataRainLayer.foreground,
          width: 390,
          midRearDensity: density,
        ).length,
        30,
      );
      expect(
        CommandCenterAmbientProcessing.streamPlacementsFor(
          layer: DataRainLayer.midFront,
          width: 390,
          midRearDensity: density,
        ).length,
        33,
      );
      expect(
        CommandCenterAmbientProcessing.streamPlacementsFor(
          layer: DataRainLayer.midRear,
          width: 390,
          midRearDensity: density,
        ).length,
        entry.value.$1,
      );
    }
  });

  test(
    'scales all three density levels responsively without surplus streams',
    () {
      final expected = {
        320.0: {
          CommandCenterMidRearDensity.low: (10, 62),
          CommandCenterMidRearDensity.medium: (17, 69),
          CommandCenterMidRearDensity.high: (25, 77),
        },
        390.0: {
          CommandCenterMidRearDensity.low: (12, 75),
          CommandCenterMidRearDensity.medium: (21, 84),
          CommandCenterMidRearDensity.high: (31, 94),
        },
        900.0: {
          CommandCenterMidRearDensity.low: (17, 109),
          CommandCenterMidRearDensity.medium: (30, 122),
          CommandCenterMidRearDensity.high: (45, 137),
        },
      };
      for (final width in expected.keys) {
        for (final entry in expected[width]!.entries) {
          final density = entry.key;
          expect(
            CommandCenterAmbientProcessing.streamPlacementsFor(
              layer: DataRainLayer.midRear,
              width: width,
              midRearDensity: density,
            ).length,
            entry.value.$1,
          );
          expect(
            CommandCenterAmbientProcessing.totalColumnsFor(
              width,
              midRearDensity: density,
            ),
            entry.value.$2,
          );
        }
      }
    },
  );

  test('uses linear constant-speed stream offsets', () {
    const speed = 22.0;
    final first = CommandCenterAmbientProcessing.constantSpeedOffset(
      elapsed: .1,
      pixelsPerSecond: speed,
    );
    final second = CommandCenterAmbientProcessing.constantSpeedOffset(
      elapsed: .2,
      pixelsPerSecond: speed,
    );
    final third = CommandCenterAmbientProcessing.constantSpeedOffset(
      elapsed: .3,
      pixelsPerSecond: speed,
    );

    expect(second - first, closeTo(third - second, .000001));
    expect(first, closeTo(2.2, .000001));
    expect(second, closeTo(4.4, .000001));
    expect(third, closeTo(6.6, .000001));
  });

  test('uses a fixed industrial glyph sequence with the requested mix', () {
    final sequence = CommandCenterAmbientProcessing.glyphSequenceForStream(
      layer: DataRainLayer.foreground,
      streamIndex: 7,
      recycleIndex: 3,
      length: CommandCenterAmbientProcessing.glyphCategoryPeriod,
    );
    final repeated = CommandCenterAmbientProcessing.glyphSequenceForStream(
      layer: DataRainLayer.foreground,
      streamIndex: 7,
      recycleIndex: 3,
      length: CommandCenterAmbientProcessing.glyphCategoryPeriod,
    );

    expect(repeated, sequence);
    expect(
      sequence
          .where(
            (glyph) =>
                CommandCenterAmbientProcessing.glyphCategoryFor(glyph) ==
                DataRainGlyphCategory.letter,
          )
          .length,
      CommandCenterAmbientProcessing.letterSlotsPerPeriod,
    );
    expect(
      sequence
          .where(
            (glyph) =>
                CommandCenterAmbientProcessing.glyphCategoryFor(glyph) ==
                DataRainGlyphCategory.number,
          )
          .length,
      CommandCenterAmbientProcessing.numberSlotsPerPeriod,
    );
    expect(
      sequence
          .where(
            (glyph) =>
                CommandCenterAmbientProcessing.glyphCategoryFor(glyph) ==
                DataRainGlyphCategory.symbol,
          )
          .length,
      CommandCenterAmbientProcessing.symbolSlotsPerPeriod,
    );
  });

  test('supports all industrial glyph categories and overlapping layers', () {
    final glyphs = <String>{};
    for (var streamIndex = 0; streamIndex < 200; streamIndex++) {
      glyphs.addAll(
        CommandCenterAmbientProcessing.glyphSequenceForStream(
          layer: DataRainLayer.foreground,
          streamIndex: streamIndex,
          recycleIndex: streamIndex % 5,
          length: 20,
        ),
      );
    }
    expect(glyphs, containsAll('ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')));
    expect(glyphs, containsAll('0123456789'.split('')));
    expect(
      glyphs,
      containsAll(const ['+', '-', '/', '\\', '=', ':', '[', ']', '<', '>']),
    );

    var overlaps = false;
    for (
      var foreground = 0;
      foreground < CommandCenterAmbientProcessing.foregroundColumnsAt390;
      foreground++
    ) {
      final foregroundX = CommandCenterAmbientProcessing.columnXFraction(
        layer: DataRainLayer.foreground,
        streamIndex: foreground,
        count: CommandCenterAmbientProcessing.foregroundColumnsAt390,
      );
      for (
        var midground = 0;
        midground < CommandCenterAmbientProcessing.midFrontColumnsAt390;
        midground++
      ) {
        final midgroundX = CommandCenterAmbientProcessing.columnXFraction(
          layer: DataRainLayer.midFront,
          streamIndex: midground,
          count: CommandCenterAmbientProcessing.midFrontColumnsAt390,
        );
        overlaps |= (foregroundX - midgroundX).abs() < .012;
      }
    }
    expect(overlaps, isTrue);
  });

  test('assigns both upward and downward independent light pulses', () {
    final directions = <DataRainPulseDirection>{
      for (var index = 0; index < 40; index++)
        ...DataRainLayer.values.map(
          (layer) => CommandCenterAmbientProcessing.pulseDirectionForStream(
            layer: layer,
            streamIndex: index,
          ),
        ),
    };
    expect(directions, contains(DataRainPulseDirection.upward));
    expect(directions, contains(DataRainPulseDirection.downward));
  });

  test('uses thick rectangular MID-REAR blocks with clear inter-cell gaps', () {
    expect(
      CommandCenterAmbientProcessing.midRearSegmentWidth,
      closeTo(
        CommandCenterAmbientProcessing.glyphSizeFor(DataRainLayer.midFront) *
            .78,
        .000001,
      ),
    );
    final previousThinLine =
        CommandCenterAmbientProcessing.glyphDotSizeFor(DataRainLayer.midFront) *
        .78;
    expect(
      CommandCenterAmbientProcessing.midRearSegmentHeight,
      closeTo(
        CommandCenterAmbientProcessing.midRearSegmentWidth * .82,
        .000001,
      ),
    );
    expect(
      CommandCenterAmbientProcessing.midRearSegmentHeight,
      greaterThan(previousThinLine * 4),
    );
    expect(CommandCenterAmbientProcessing.midRearInterCellGap, greaterThan(1));
    expect(
      CommandCenterAmbientProcessing.midRearInterCellGap,
      lessThan(
        CommandCenterAmbientProcessing.glyphVerticalPitchFor(
          DataRainLayer.midRear,
        ),
      ),
    );
    expect(
      CommandCenterAmbientProcessing.glyphVerticalPitchFor(
        DataRainLayer.midRear,
      ),
      closeTo(
        CommandCenterAmbientProcessing.glyphSizeFor(DataRainLayer.midRear) *
            1.72,
        .000001,
      ),
    );
    final lengths = <DataRainStreamLength, int>{
      for (final kind in DataRainStreamLength.values) kind: 0,
    };
    for (var index = 0; index < 20; index++) {
      final length = CommandCenterAmbientProcessing.streamLengthFor(
        layer: DataRainLayer.midRear,
        streamIndex: index,
      );
      lengths[length] = lengths[length]! + 1;
    }
    expect(lengths[DataRainStreamLength.long], 15);
    expect(lengths[DataRainStreamLength.medium], 4);
    expect(lengths[DataRainStreamLength.short], 1);
  });

  test(
    'uses the V2.2 long-medium-short stream distribution and dimensions',
    () {
      final lengths = <DataRainStreamLength, int>{
        for (final kind in DataRainStreamLength.values) kind: 0,
      };
      for (var index = 0; index < 20; index++) {
        final kind = CommandCenterAmbientProcessing.streamLengthFor(
          layer: DataRainLayer.foreground,
          streamIndex: index,
        );
        lengths[kind] = lengths[kind]! + 1;
      }
      expect(lengths[DataRainStreamLength.long], 15);
      expect(lengths[DataRainStreamLength.medium], 4);
      expect(lengths[DataRainStreamLength.short], 1);
      expect(CommandCenterAmbientProcessing.glyphScale, .65);
      expect(
        CommandCenterAmbientProcessing.glyphSizeFor(DataRainLayer.foreground),
        closeTo(5.2, .000001),
      );
      expect(
        CommandCenterAmbientProcessing.glyphDotSizeFor(
          DataRainLayer.foreground,
        ),
        closeTo(.78, .000001),
      );
      expect(
        CommandCenterAmbientProcessing.glyphDotPitchFor(
          DataRainLayer.foreground,
        ),
        closeTo(1.131, .000001),
      );
      expect(
        CommandCenterAmbientProcessing.glyphVerticalPitchFor(
          DataRainLayer.foreground,
        ),
        closeTo(7.904, .000001),
      );
      expect(
        CommandCenterAmbientProcessing.glyphSizeFor(DataRainLayer.midFront) /
            CommandCenterAmbientProcessing.glyphSizeFor(
              DataRainLayer.foreground,
            ),
        closeTo(.6, .000001),
      );
      for (final layer in DataRainLayer.values) {
        for (var streamIndex = 0; streamIndex < 20; streamIndex++) {
          expect(
            CommandCenterAmbientProcessing.initialEntryHeadFor(
              layer: layer,
              streamIndex: streamIndex,
            ),
            lessThanOrEqualTo(
              -CommandCenterAmbientProcessing.glyphSizeFor(layer),
            ),
          );
        }
      }
    },
  );

  Future<void> pumpProcessing(
    WidgetTester tester, {
    required double width,
    required bool enabled,
    CommandCenterMidRearDensity midRearDensity =
        CommandCenterMidRearDensity.low,
    bool reducedMotion = false,
    DataRainLayer? debugOnlyLayer,
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
                  child: CommandCenterAmbientProcessing(
                    enabled: enabled,
                    midRearDensity: midRearDensity,
                    debugOnlyLayer: debugOnlyLayer,
                  ),
                ),
                const Center(child: Text('OPERATIONAL CONTENT')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders foreground, MID-FRONT glyphs and MID-REAR segments', (
    tester,
  ) async {
    await pumpProcessing(tester, width: 390, enabled: true);

    expect(find.byKey(CommandCenterAmbientProcessing.rootKey), findsOneWidget);
    expect(
      find.byKey(CommandCenterAmbientProcessing.foregroundKey),
      findsOneWidget,
    );
    expect(
      find.byKey(CommandCenterAmbientProcessing.midFrontKey),
      findsOneWidget,
    );
    expect(
      find.byKey(CommandCenterAmbientProcessing.midRearKey),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('command-center-data-rain-background')),
      findsNothing,
    );
    expect(find.text('OPERATIONAL CONTENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suppresses all processing layers when disabled', (tester) async {
    await pumpProcessing(tester, width: 390, enabled: false);

    expect(find.byKey(CommandCenterAmbientProcessing.rootKey), findsNothing);
    expect(
      find.byKey(CommandCenterAmbientProcessing.foregroundKey),
      findsNothing,
    );
    expect(
      find.byKey(CommandCenterAmbientProcessing.midFrontKey),
      findsNothing,
    );
    expect(find.byKey(CommandCenterAmbientProcessing.midRearKey), findsNothing);
  });

  testWidgets('remains valid as a static field for reduced motion', (
    tester,
  ) async {
    await pumpProcessing(
      tester,
      width: 390,
      enabled: true,
      reducedMotion: true,
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(CommandCenterAmbientProcessing.rootKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses segment-only MID-REAR drawing with bounded debug paint metrics',
    (tester) async {
      await pumpProcessing(
        tester,
        width: 390,
        enabled: true,
        reducedMotion: true,
      );
      await tester.pump();

      final foreground = CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.foreground,
      );
      final midFront = CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.midFront,
      );
      final midRear = CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.midRear,
      );
      expect(foreground?.activeStreams, 30);
      expect(midFront?.activeStreams, 33);
      expect(midRear?.activeStreams, 12);
      expect(midRear?.glyphDrawAttempts, 0);
      expect(midRear?.canvasTransforms, 0);
      expect(midRear?.segmentDrawAttempts, greaterThan(0));
      expect(midRear?.visibleCells, midRear?.segmentDrawAttempts);
      expect(foreground?.glyphDrawAttempts, greaterThan(0));
      expect(midFront?.glyphDrawAttempts, greaterThan(0));
      expect(
        (foreground?.offscreenStreams ?? 0) +
            (midFront?.offscreenStreams ?? 0) +
            (midRear?.offscreenStreams ?? 0),
        greaterThan(0),
      );
    },
  );

  testWidgets('switches only real MID-REAR stream allocation live', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> pumpDensity(CommandCenterMidRearDensity density) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: CommandCenterAmbientProcessing(
                      enabled: true,
                      midRearDensity: density,
                    ),
                  ),
                  const Center(child: Text('OPERATIONAL CONTENT')),
                ],
              ),
            ),
          ),
        );

    await pumpDensity(CommandCenterMidRearDensity.low);
    await tester.pump();
    final foregroundBefore =
        CommandCenterAmbientProcessing.debugPaintMetricsFor(
          DataRainLayer.foreground,
        );
    final midFrontBefore = CommandCenterAmbientProcessing.debugPaintMetricsFor(
      DataRainLayer.midFront,
    );
    expect(
      CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.midRear,
      )?.activeStreams,
      12,
    );

    await pumpDensity(CommandCenterMidRearDensity.medium);
    await tester.pump();
    expect(
      CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.midRear,
      )?.activeStreams,
      21,
    );
    expect(
      CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.foreground,
      )?.activeStreams,
      foregroundBefore?.activeStreams,
    );
    expect(
      CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.midFront,
      )?.activeStreams,
      midFrontBefore?.activeStreams,
    );
    expect(
      CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.foreground,
      )?.streamIdentitySignature,
      foregroundBefore?.streamIdentitySignature,
    );
    expect(
      CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.midFront,
      )?.streamIdentitySignature,
      midFrontBefore?.streamIdentitySignature,
    );

    await pumpDensity(CommandCenterMidRearDensity.high);
    await tester.pump();
    expect(
      CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.midRear,
      )?.activeStreams,
      31,
    );
    await pumpDensity(CommandCenterMidRearDensity.low);
    await tester.pump();
    expect(
      CommandCenterAmbientProcessing.debugPaintMetricsFor(
        DataRainLayer.midRear,
      )?.activeStreams,
      12,
    );
    expect(tester.takeException(), isNull);
  });

  for (final density in CommandCenterMidRearDensity.values) {
    testWidgets('renders deterministic MID-REAR ${density.name} density', (
      tester,
    ) async {
      await pumpProcessing(
        tester,
        width: 390,
        enabled: true,
        reducedMotion: true,
        debugOnlyLayer: DataRainLayer.midRear,
        midRearDensity: density,
      );
      await expectLater(
        find.byKey(CommandCenterAmbientProcessing.rootKey),
        matchesGoldenFile(
          'goldens/command_center_data_rain_mid_rear_${density.name}.png',
        ),
      );
    });
  }

  testWidgets('renders visible discrete MID-REAR data segments', (
    tester,
  ) async {
    await pumpProcessing(
      tester,
      width: 390,
      enabled: true,
      reducedMotion: true,
      debugOnlyLayer: DataRainLayer.midRear,
    );

    await expectLater(
      find.byKey(CommandCenterAmbientProcessing.rootKey),
      matchesGoldenFile('goldens/command_center_data_rain_mid_rear.png'),
    );
  });

  testWidgets('renders the production industrial glyph Data Rain field', (
    tester,
  ) async {
    await pumpProcessing(
      tester,
      width: 390,
      enabled: true,
      reducedMotion: true,
    );

    await expectLater(
      find.byKey(CommandCenterAmbientProcessing.rootKey),
      matchesGoldenFile(
        'goldens/command_center_data_rain_industrial_glyphs.png',
      ),
    );
  });

  testWidgets('renders the isolated unchanged foreground glyph layer', (
    tester,
  ) async {
    await pumpProcessing(
      tester,
      width: 390,
      enabled: true,
      reducedMotion: true,
      debugOnlyLayer: DataRainLayer.foreground,
    );

    await expectLater(
      find.byKey(CommandCenterAmbientProcessing.rootKey),
      matchesGoldenFile('goldens/command_center_data_rain_foreground_v29.png'),
    );
  });

  testWidgets('starts a new ambient session with an empty production field', (
    tester,
  ) async {
    await pumpProcessing(tester, width: 390, enabled: true);

    await expectLater(
      find.byKey(CommandCenterAmbientProcessing.rootKey),
      matchesGoldenFile('goldens/command_center_data_rain_initial_empty.png'),
    );
  });

  testWidgets('physically enters streams from above asynchronously', (
    tester,
  ) async {
    await pumpProcessing(tester, width: 390, enabled: true);
    await tester.pump(const Duration(seconds: 3));

    await expectLater(
      find.byKey(CommandCenterAmbientProcessing.rootKey),
      matchesGoldenFile('goldens/command_center_data_rain_top_entry.png'),
    );
  });

  testWidgets('renders active production glyph pulses independently', (
    tester,
  ) async {
    await pumpProcessing(tester, width: 390, enabled: true);
    await tester.pump(const Duration(seconds: 12));

    await expectLater(
      find.byKey(CommandCenterAmbientProcessing.rootKey),
      matchesGoldenFile(
        'goldens/command_center_data_rain_industrial_glyphs_active.png',
      ),
    );
  });

  testWidgets('does not restart initial entry on an ordinary rebuild', (
    tester,
  ) async {
    await pumpProcessing(tester, width: 390, enabled: true);
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: CommandCenterAmbientProcessing(enabled: true),
              ),
              Center(child: Text('OPERATIONAL CONTENT')),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(CommandCenterAmbientProcessing.rootKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('has bounded processing layers at width $width', (
      tester,
    ) async {
      await pumpProcessing(tester, width: width, enabled: true);
      final bounds = tester.getRect(
        find.byKey(CommandCenterAmbientProcessing.rootKey),
      );
      expect(bounds.width, closeTo(width, 1));
      expect(bounds.height, greaterThan(300));
      expect(tester.takeException(), isNull);
    });
  }
}
