import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/boot_send_sequence_sandbox.dart';

void main() {
  test('fixed send phases reach complete without random timing', () {
    expect(bootSendSequencePhase(0), BootSendSequencePhase.initializing);
    expect(bootSendSequencePhase(.2), BootSendSequencePhase.buildingData);
    expect(bootSendSequencePhase(.5), BootSendSequencePhase.transmitting);
    expect(bootSendSequencePhase(1), BootSendSequencePhase.complete);
  });

  testWidgets('three fixed concepts compare, replay, and stop complete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BootSendSequenceSandbox())),
    );

    expect(find.text('TERMINAL SEND'), findsWidgets);
    await tester.tap(find.text('PACKET'));
    await tester.pump();
    expect(find.text('PACKET UPLINK'), findsWidgets);
    await tester.tap(find.text('ARCHIVE'));
    await tester.pump();
    expect(find.text('ARCHIVE DISPATCH'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 6100));
    expect(
      find.byKey(const ValueKey('boot-send-sequence-monitor')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('boot-send-sequence-replay')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('boot-send-sequence-monitor')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion uses the complete static representation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: BootSendSequenceSandbox()),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('boot-send-sequence-monitor')),
      findsOneWidget,
    );
  });

  const frames = [0, 800, 1600, 3000, 4100, 5200, 6000];
  for (final concept in BootSendSequenceConcept.values) {
    for (final milliseconds in frames) {
      testWidgets('${concept.name} industrial frame ${milliseconds}ms', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: BootSendSequenceSandbox())),
        );
        if (concept != BootSendSequenceConcept.terminalSend) {
          await tester.tap(
            find.text(switch (concept) {
              BootSendSequenceConcept.packetUplink => 'PACKET',
              BootSendSequenceConcept.archiveDispatch => 'ARCHIVE',
              BootSendSequenceConcept.terminalSend => 'TERMINAL',
            }),
          );
          await tester.pump();
        }
        await tester.pump(Duration(milliseconds: milliseconds));
        await expectLater(
          find.byKey(const ValueKey('boot-send-sequence-monitor')),
          matchesGoldenFile(
            'goldens/boot_send_${concept.name}_${milliseconds}ms.png',
          ),
        );
      });
    }
  }
}
