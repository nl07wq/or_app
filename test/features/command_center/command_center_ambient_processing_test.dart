import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_center/widgets/command_center_ambient_processing.dart';

void main() {
  test('exposes high-density independent data rain speed models', () {
    expect(
      CommandCenterAmbientProcessing.foregroundColumnsAt390,
      inInclusiveRange(32, 48),
    );
    expect(
      CommandCenterAmbientProcessing.midgroundColumnsAt390,
      inInclusiveRange(48, 72),
    );
    expect(
      CommandCenterAmbientProcessing.backgroundColumnsAt390,
      inInclusiveRange(40, 80),
    );
    expect(CommandCenterAmbientProcessing.totalColumnsAt390, 171);
    final speeds = CommandCenterAmbientProcessing.speeds;
    expect(speeds[DataRainSpeed.slow], lessThan(speeds[DataRainSpeed.normal]!));
    expect(speeds[DataRainSpeed.normal], lessThan(speeds[DataRainSpeed.fast]!));
    expect(speeds[DataRainSpeed.fast], lessThan(speeds[DataRainSpeed.burst]!));
  });

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
        midground < CommandCenterAmbientProcessing.midgroundColumnsAt390;
        midground++
      ) {
        final midgroundX = CommandCenterAmbientProcessing.columnXFraction(
          layer: DataRainLayer.midground,
          streamIndex: midground,
          count: CommandCenterAmbientProcessing.midgroundColumnsAt390,
        );
        overlaps |= (foregroundX - midgroundX).abs() < .012;
      }
    }
    expect(overlaps, isTrue);
  });

  test('assigns both upward and downward independent light pulses', () {
    final directions = <DataRainPulseDirection>{
      for (var index = 0; index < 40; index++)
        CommandCenterAmbientProcessing.pulseDirectionForStream(
          layer: DataRainLayer.foreground,
          streamIndex: index,
        ),
    };
    expect(directions, contains(DataRainPulseDirection.upward));
    expect(directions, contains(DataRainPulseDirection.downward));
  });

  test('uses the V2.1 long-medium-short stream distribution', () {
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
    expect(CommandCenterAmbientProcessing.glyphScale, .8);
  });

  Future<void> pumpProcessing(
    WidgetTester tester, {
    required double width,
    required bool enabled,
    bool reducedMotion = false,
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
                  child: CommandCenterAmbientProcessing(enabled: enabled),
                ),
                const Center(child: Text('OPERATIONAL CONTENT')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders three industrial glyph layers behind content', (
    tester,
  ) async {
    await pumpProcessing(tester, width: 390, enabled: true);

    expect(find.byKey(CommandCenterAmbientProcessing.rootKey), findsOneWidget);
    expect(
      find.byKey(CommandCenterAmbientProcessing.foregroundKey),
      findsOneWidget,
    );
    expect(
      find.byKey(CommandCenterAmbientProcessing.midgroundKey),
      findsOneWidget,
    );
    expect(
      find.byKey(CommandCenterAmbientProcessing.backgroundKey),
      findsOneWidget,
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
      find.byKey(CommandCenterAmbientProcessing.midgroundKey),
      findsNothing,
    );
    expect(
      find.byKey(CommandCenterAmbientProcessing.backgroundKey),
      findsNothing,
    );
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
    await tester.pump(const Duration(milliseconds: 900));
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
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(seconds: 3));

    await expectLater(
      find.byKey(CommandCenterAmbientProcessing.rootKey),
      matchesGoldenFile(
        'goldens/command_center_data_rain_industrial_glyphs_active.png',
      ),
    );
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
