import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_center/widgets/command_center_ambient_processing.dart';

void main() {
  test('uses six deterministic processing sequences with quiet intervals', () {
    const sequences = [
      AmbientProcessingSequence.ingestRoute,
      AmbientProcessingSequence.parallelProcessing,
      AmbientProcessingSequence.bufferWriteFlush,
      AmbientProcessingSequence.verifyAcknowledge,
      AmbientProcessingSequence.routeBranch,
      AmbientProcessingSequence.highLoadBurst,
    ];

    for (var index = 0; index < sequences.length; index++) {
      final active = CommandCenterAmbientProcessing.frameAt(
        (index + .35) / sequences.length,
      );
      final idle = CommandCenterAmbientProcessing.frameAt(
        (index + .9) / sequences.length,
      );
      expect(active.sequence, sequences[index]);
      expect(active.isIdle, isFalse);
      expect(active.progress, inInclusiveRange(0.0, 1.0));
      expect(idle.sequence, AmbientProcessingSequence.idle);
      expect(idle.isIdle, isTrue);
    }
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
