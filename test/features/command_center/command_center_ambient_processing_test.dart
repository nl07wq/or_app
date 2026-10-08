import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_center/widgets/command_center_ambient_processing.dart';

void main() {
  test('exposes dense independent data rain speed models', () {
    expect(CommandCenterAmbientProcessing.streamCount, 48);
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

  testWidgets('renders dense data rain behind content', (tester) async {
    await pumpProcessing(tester, width: 390, enabled: true);

    expect(find.byKey(CommandCenterAmbientProcessing.rootKey), findsOneWidget);
    expect(
      find.byKey(CommandCenterAmbientProcessing.dataRainKey),
      findsOneWidget,
    );
    expect(find.text('OPERATIONAL CONTENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suppresses all processing layers when disabled', (tester) async {
    await pumpProcessing(tester, width: 390, enabled: false);

    expect(find.byKey(CommandCenterAmbientProcessing.rootKey), findsNothing);
    expect(
      find.byKey(CommandCenterAmbientProcessing.dataRainKey),
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

  testWidgets('renders the production Data Rain field', (tester) async {
    await pumpProcessing(
      tester,
      width: 390,
      enabled: true,
      reducedMotion: true,
    );

    await expectLater(
      find.byKey(CommandCenterAmbientProcessing.dataRainKey),
      matchesGoldenFile('goldens/command_center_data_rain_static.png'),
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
