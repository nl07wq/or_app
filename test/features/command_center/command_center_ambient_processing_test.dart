import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_center/widgets/command_center_ambient_processing.dart';

void main() {
  test('exposes the denser connected processing topology', () {
    expect(CommandCenterAmbientProcessing.nodeCount, 14);
    expect(CommandCenterAmbientProcessing.dataBusCount, 21);
    expect(CommandCenterAmbientProcessing.memoryBankCount, 5);
    expect(CommandCenterAmbientProcessing.memoryCellsPerBank, 6);
    expect(
      CommandCenterAmbientProcessing.geometryFamilies,
      containsAll(<AmbientBusGeometry>[
        AmbientBusGeometry.straight,
        AmbientBusGeometry.stepped,
        AmbientBusGeometry.curvedBypass,
        AmbientBusGeometry.parallelLane,
        AmbientBusGeometry.transport,
      ]),
    );
  });

  test('keeps all V2 sequences and packet models deterministic', () {
    const sequences = [
      AmbientProcessingSequence.ingestRoute,
      AmbientProcessingSequence.parallelProcessing,
      AmbientProcessingSequence.bufferWriteFlush,
      AmbientProcessingSequence.verifyAcknowledge,
      AmbientProcessingSequence.routeBranch,
      AmbientProcessingSequence.highLoadBurst,
    ];

    expect(sequences, hasLength(6));
    expect(AmbientPacketModel.values, hasLength(4));
    expect(AmbientPacketModel.values, contains(AmbientPacketModel.light));
    expect(AmbientPacketModel.values, contains(AmbientPacketModel.standard));
    expect(AmbientPacketModel.values, contains(AmbientPacketModel.heavy));
    expect(AmbientPacketModel.values, contains(AmbientPacketModel.priority));
    final durations = CommandCenterAmbientProcessing.packetTravelDurations;
    expect(
      durations[AmbientPacketModel.priority],
      lessThan(durations[AmbientPacketModel.light]!),
    );
    expect(
      durations[AmbientPacketModel.light],
      lessThan(durations[AmbientPacketModel.standard]!),
    );
    expect(
      durations[AmbientPacketModel.standard],
      lessThan(durations[AmbientPacketModel.heavy]!),
    );
  });

  test('uses linear constant-speed packet progress', () {
    const duration = .4;
    final first = CommandCenterAmbientProcessing.constantSpeedProgress(
      elapsed: .1,
      travelDuration: duration,
    );
    final second = CommandCenterAmbientProcessing.constantSpeedProgress(
      elapsed: .2,
      travelDuration: duration,
    );
    final third = CommandCenterAmbientProcessing.constantSpeedProgress(
      elapsed: .3,
      travelDuration: duration,
    );

    expect(second - first, closeTo(third - second, .000001));
    expect(first, closeTo(.25, .000001));
    expect(second, closeTo(.5, .000001));
    expect(third, closeTo(.75, .000001));
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

  testWidgets('renders the three processing layers behind content', (
    tester,
  ) async {
    await pumpProcessing(tester, width: 390, enabled: true);

    expect(find.byKey(CommandCenterAmbientProcessing.rootKey), findsOneWidget);
    expect(find.byKey(CommandCenterAmbientProcessing.nodesKey), findsOneWidget);
    expect(
      find.byKey(CommandCenterAmbientProcessing.dataBusKey),
      findsOneWidget,
    );
    expect(
      find.byKey(CommandCenterAmbientProcessing.memoryBlocksKey),
      findsOneWidget,
    );
    expect(find.text('OPERATIONAL CONTENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suppresses all processing layers when disabled', (tester) async {
    await pumpProcessing(tester, width: 390, enabled: false);

    expect(find.byKey(CommandCenterAmbientProcessing.rootKey), findsNothing);
    expect(find.byKey(CommandCenterAmbientProcessing.nodesKey), findsNothing);
    expect(find.byKey(CommandCenterAmbientProcessing.dataBusKey), findsNothing);
    expect(
      find.byKey(CommandCenterAmbientProcessing.memoryBlocksKey),
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

  testWidgets('renders the production Data Bus as thin open traces', (
    tester,
  ) async {
    await pumpProcessing(
      tester,
      width: 390,
      enabled: true,
      reducedMotion: true,
    );

    await expectLater(
      find.byKey(CommandCenterAmbientProcessing.dataBusKey),
      matchesGoldenFile('goldens/command_center_data_bus_thin_traces.png'),
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
