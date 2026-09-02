import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/startup_initialization_service.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/boot_sequence.dart';
import 'package:or_app/core/widgets/startup_gate.dart';

void main() {
  testWidgets('boot sequence covers startup then exposes the main UI once', (
    tester,
  ) async {
    final controller = AppInitializationController();
    final events = <BootSequenceEventType>[];
    final service = StartupInitializationService(
      controller: controller,
      isWeb: false,
      restore: () async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StartupGate(
          service: service,
          showBootSequence: true,
          bootMinimumDisplayDuration: Duration.zero,
          onBootEvent: (event) => events.add(event.type),
          child: const Text('MAIN UI'),
        ),
      ),
    );

    expect(find.text('OPERATION REBOOT'), findsOneWidget);
    expect(find.text('INITIALIZING...'), findsOneWidget);
    expect(find.text('MAIN UI'), findsNothing);
    expect(events, [BootSequenceEventType.bootStart]);

    controller.markReady();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(events, [
      BootSequenceEventType.bootStart,
      BootSequenceEventType.systemInitialized,
      BootSequenceEventType.bootComplete,
    ]);
  });

  testWidgets('a rebuild does not replay boot events', (tester) async {
    final controller = AppInitializationController()..markReady();
    final events = <BootSequenceEventType>[];
    final service = StartupInitializationService(
      controller: controller,
      isWeb: false,
      restore: () async {},
    );
    Widget build() => MaterialApp(
      home: StartupGate(
        key: const ValueKey('startup-gate'),
        service: service,
        showBootSequence: true,
        bootMinimumDisplayDuration: Duration.zero,
        onBootEvent: (event) => events.add(event.type),
        child: const Text('MAIN UI'),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pumpWidget(build());
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(events, hasLength(3));
    expect(events.first, BootSequenceEventType.bootStart);
  });

  testWidgets('a boot event listener failure does not block the main UI', (
    tester,
  ) async {
    final controller = AppInitializationController();
    final service = StartupInitializationService(
      controller: controller,
      isWeb: false,
      restore: () async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StartupGate(
          service: service,
          showBootSequence: true,
          bootMinimumDisplayDuration: Duration.zero,
          onBootEvent: (_) => throw StateError('audio hook unavailable'),
          child: const Text('MAIN UI'),
        ),
      ),
    );
    controller.markReady();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
