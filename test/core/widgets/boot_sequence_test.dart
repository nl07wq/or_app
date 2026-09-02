import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/startup_initialization_service.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/boot_sequence.dart';
import 'package:or_app/core/widgets/startup_gate.dart';

const _timing = BootSequenceTiming(
  logoIntro: Duration(milliseconds: 10),
  typingCharacter: Duration(milliseconds: 10),
  systemBootTransition: Duration(milliseconds: 10),
  header: Duration(milliseconds: 10),
  row: Duration(milliseconds: 10),
  readyDelay: Duration(milliseconds: 10),
  readyHold: Duration(milliseconds: 10),
);

void main() {
  testWidgets('boot rows are revealed and completed in sequence', (
    tester,
  ) async {
    final controller = AppInitializationController();
    await tester.pumpWidget(_gate(controller));

    expect(find.byKey(const ValueKey('boot-brand-logo')), findsOneWidget);
    expect(find.text('SYSTEM BOOT'), findsNothing);
    expect(find.text('CORE SYSTEM'), findsNothing);
    expect(find.text('SYSTEM READY'), findsNothing);

    await tester.pump(_timing.logoIntro);
    await tester.pump(_timing.typingCharacter);
    expect(find.text('O'), findsOneWidget);
    expect(find.text('O.R.L.O.'), findsNothing);
    await tester.pump(_timing.typingCharacter * 7);
    await tester.pump(_timing.systemBootTransition);
    expect(find.text('O.R.L.O.'), findsOneWidget);
    expect(find.text('CORE SYSTEM'), findsOneWidget);
    expect(find.text('INITIALIZING'), findsOneWidget);
    expect(find.text('DATA INITIALIZATION'), findsNothing);

    await tester.pump(_timing.row);
    expect(find.text('CORE SYSTEM'), findsOneWidget);
    expect(find.text('DATA INITIALIZATION'), findsOneWidget);
    expect(find.text('OPERATION DATA'), findsNothing);
    expect(find.text('INITIALIZING'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await tester.pump(_timing.row);
    expect(find.text('OPERATION DATA'), findsOneWidget);
    expect(find.text('INITIALIZING'), findsOneWidget);
    expect(find.text('OK'), findsNWidgets(2));

    await tester.pump(_timing.row + _timing.readyDelay);
    expect(find.text('OK'), findsNWidgets(3));
    expect(find.text('SYSTEM READY'), findsNothing);
    expect(find.text('MAIN UI'), findsNothing);
  });

  testWidgets('system ready and main UI wait for real initialization', (
    tester,
  ) async {
    final controller = AppInitializationController();
    final events = <BootSequenceEventType>[];
    await tester.pumpWidget(
      _gate(controller, onEvent: (event) => events.add(event.type)),
    );

    await _advanceRows(tester);
    expect(find.text('SYSTEM READY'), findsNothing);
    expect(events, [BootSequenceEventType.bootStart]);

    controller.markReady();
    await tester.pump();
    expect(find.text('SYSTEM READY'), findsOneWidget);
    expect(find.text('MAIN UI'), findsNothing);
    expect(events, [
      BootSequenceEventType.bootStart,
      BootSequenceEventType.systemInitialized,
    ]);

    await tester.pump(_timing.readyHold);
    expect(find.text('MAIN UI'), findsOneWidget);
    expect(events, [
      BootSequenceEventType.bootStart,
      BootSequenceEventType.systemInitialized,
      BootSequenceEventType.bootComplete,
    ]);
  });

  testWidgets('initialization failure never shows ready or main UI', (
    tester,
  ) async {
    final controller = AppInitializationController();
    await tester.pumpWidget(_gate(controller));

    controller.markFailed(errorCode: 'test', errorMessage: 'failure');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DATA INITIALIZATION FAILED'), findsOneWidget);
    expect(find.text('SYSTEM READY'), findsNothing);
    expect(find.text('MAIN UI'), findsNothing);
  });

  testWidgets('a rebuild does not replay boot events', (tester) async {
    final controller = AppInitializationController()..markReady();
    final events = <BootSequenceEventType>[];
    await tester.pumpWidget(
      _gate(controller, onEvent: (event) => events.add(event.type)),
    );
    await _advanceRows(tester);
    await tester.pump(_timing.readyHold);
    await tester.pumpWidget(
      _gate(controller, onEvent: (event) => events.add(event.type)),
    );
    await tester.pump();

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(events, [
      BootSequenceEventType.bootStart,
      BootSequenceEventType.systemInitialized,
      BootSequenceEventType.bootComplete,
    ]);
  });

  testWidgets('a boot event listener failure does not block the main UI', (
    tester,
  ) async {
    final controller = AppInitializationController()..markReady();
    await tester.pumpWidget(
      _gate(controller, onEvent: (_) => throw StateError('audio unavailable')),
    );
    await _advanceRows(tester);
    await tester.pump(_timing.readyHold);

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _gate(
  AppInitializationController controller, {
  BootSequenceEventListener? onEvent,
}) {
  final service = StartupInitializationService(
    controller: controller,
    isWeb: false,
    restore: () async {},
  );
  return MaterialApp(
    home: StartupGate(
      key: const ValueKey('startup-gate'),
      service: service,
      showBootSequence: true,
      bootSequenceTiming: _timing,
      onBootEvent: onEvent,
      child: const Text('MAIN UI'),
    ),
  );
}

Future<void> _advanceRows(WidgetTester tester) async {
  await tester.pump(_timing.logoIntro);
  await tester.pump(_timing.typingCharacter * 7);
  await tester.pump(_timing.systemBootTransition);
  await tester.pump(_timing.header);
  await tester.pump(_timing.row);
  await tester.pump(_timing.row);
  await tester.pump(_timing.row + _timing.readyDelay);
}
