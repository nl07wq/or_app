import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/boot_send_sequence_sandbox.dart';

void main() {
  test('fixed six-second phases use the shared timeline boundaries', () {
    expect(bootSendSequencePhase(0), BootSendSequencePhase.initializing);
    expect(bootSendSequencePhase(.2), BootSendSequencePhase.buildingData);
    expect(
      bootSendSequencePhase(2800 / 6000),
      BootSendSequencePhase.integrating,
    );
    expect(bootSendSequencePhase(4600 / 6000), BootSendSequencePhase.complete);
    expect(bootSendSequencePhase(1), BootSendSequencePhase.complete);
  });

  testWidgets('three selectors reset the comparison monitor and replay', (
    tester,
  ) async {
    await _pumpSandbox(tester);

    expect(find.text('ASSEMBLY MATRIX'), findsWidgets);
    expect(find.text('VOXEL INTEGRATION'), findsOneWidget);
    expect(find.text('POLYHEDRAL FOLD'), findsOneWidget);
    await tester.tap(find.text('VOXEL INTEGRATION'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('boot-send-sequence-monitor')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.tap(find.byKey(const ValueKey('boot-send-sequence-replay')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion renders each completed scene without ticking', (
    tester,
  ) async {
    await _pumpSandbox(tester, reducedMotion: true);
    expect(
      find.byKey(const ValueKey('boot-send-sequence-monitor')),
      findsOneWidget,
    );
    await tester.tap(find.text('POLYHEDRAL FOLD'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  const frames = [0, 1200, 2800, 4600, 6000];
  for (final concept in BootSendSequenceConcept.values) {
    for (final milliseconds in frames) {
      testWidgets('${concept.name} ${milliseconds}ms golden', (tester) async {
        await _pumpSandbox(tester);
        if (concept != BootSendSequenceConcept.assemblyMatrix) {
          await tester.tap(find.text(_selectorText(concept)));
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

String _selectorText(BootSendSequenceConcept concept) => switch (concept) {
  BootSendSequenceConcept.assemblyMatrix => 'ASSEMBLY MATRIX',
  BootSendSequenceConcept.voxelIntegration => 'VOXEL INTEGRATION',
  BootSendSequenceConcept.polyhedralFold => 'POLYHEDRAL FOLD',
};

Future<void> _pumpSandbox(
  WidgetTester tester, {
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: const Scaffold(body: BootSendSequenceSandbox()),
      ),
    ),
  );
  await tester.pump();
}
