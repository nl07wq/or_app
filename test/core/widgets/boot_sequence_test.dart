import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/startup_initialization_service.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/boot_sequence.dart';
import 'package:or_app/core/widgets/startup_gate.dart';

const _timing = BootSequenceTiming(
  logoIntro: Duration(milliseconds: 10),
  typingCharacter: Duration(milliseconds: 10),
  fullNameCharacter: Duration(milliseconds: 10),
  identityHold: Duration(milliseconds: 10),
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

    await _elapse(tester, _timing.logoIntro);
    await _elapse(tester, _timing.typingCharacter);
    expect(find.text('O'), findsOneWidget);
    expect(find.text('O.R.L.O.'), findsNothing);
    await _advanceTyping(tester, _timing, count: 7);
    expect(find.byKey(const ValueKey('boot-brand-full-name')), findsOneWidget);
    expect(find.text('SYSTEM BOOT'), findsNothing);
    await _elapse(tester, _timing.identityHold);
    expect(find.byKey(const ValueKey('boot-progress-bar')), findsOneWidget);
    await _elapse(tester, _timing.systemBootTransition);
    expect(find.text('O.R.L.O.'), findsOneWidget);
    expect(find.text('CORE SYSTEM'), findsOneWidget);
    expect(find.text('INITIALIZING /'), findsOneWidget);
    expect(find.text('DATA INITIALIZATION'), findsNothing);

    await _elapse(tester, _timing.row * 2);
    expect(find.text('CORE SYSTEM'), findsOneWidget);
    expect(find.text('DATA INITIALIZATION'), findsOneWidget);
    expect(find.text('OPERATION DATA'), findsNothing);
    expect(find.textContaining('INITIALIZING'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await _elapse(tester, _timing.row);
    expect(find.text('OPERATION DATA'), findsOneWidget);
    expect(find.textContaining('INITIALIZING'), findsOneWidget);
    expect(find.text('OK'), findsNWidgets(2));

    await _elapse(tester, _timing.row);
    expect(find.text('OK'), findsNWidgets(3));
    expect(find.text('SYSTEM READY'), findsNothing);
    expect(find.text('MAIN UI'), findsNothing);
  });

  testWidgets('boot progress continuously advances through visual phases', (
    tester,
  ) async {
    const continuousTiming = BootSequenceTiming(
      logoIntro: Duration(milliseconds: 20),
      typingCharacter: Duration(milliseconds: 100),
      fullNameCharacter: Duration(milliseconds: 10),
      identityHold: Duration(milliseconds: 100),
      systemBootTransition: Duration(milliseconds: 1200),
      row: Duration(milliseconds: 600),
      readyDelay: Duration(milliseconds: 200),
      readyHold: Duration(milliseconds: 10),
    );
    final semantics = tester.ensureSemantics();
    final controller = AppInitializationController();
    await tester.pumpWidget(_gate(controller, timing: continuousTiming));

    await _elapse(tester, continuousTiming.logoIntro);
    await _advanceTyping(tester, continuousTiming);
    await _elapse(tester, continuousTiming.identityHold);
    final p0 = _progressValue(tester);
    final w0 = tester.getSize(find.byKey(const ValueKey('boot-progress-fill'))).width;
    expect(
      tester.getSize(find.byKey(const ValueKey('boot-progress-bar'))).height,
      10,
    );

    await _elapse(tester, const Duration(milliseconds: 300));
    final p1 = _progressValue(tester);
    final w1 = tester.getSize(find.byKey(const ValueKey('boot-progress-fill'))).width;
    await _elapse(tester, const Duration(milliseconds: 300));
    final p2 = _progressValue(tester);
    final w2 = tester.getSize(find.byKey(const ValueKey('boot-progress-fill'))).width;
    await _elapse(tester, const Duration(milliseconds: 300));
    final p3 = _progressValue(tester);
    final w3 = tester.getSize(find.byKey(const ValueKey('boot-progress-fill'))).width;

    expect(p0, lessThan(p1));
    expect(p1, lessThan(p2));
    expect(p2, lessThan(p3));
    expect(p3, lessThan(90));
    expect(w0, lessThan(w1));
    expect(w1, lessThan(w2));
    expect(w2, lessThan(w3));
    expect(w3, greaterThan(1));
    expect(find.text('SYSTEM READY'), findsNothing);
    semantics.dispose();
  });

  testWidgets('system ready and main UI wait for real initialization', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = AppInitializationController();
    final events = <BootSequenceEventType>[];
    await tester.pumpWidget(
      _gate(controller, onEvent: (event) => events.add(event.type)),
    );

    await _advanceRows(tester);
    expect(find.text('SYSTEM READY'), findsNothing);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('boot-progress-bar')))
          .value,
      '95%',
    );
    expect(events, [BootSequenceEventType.bootStart]);

    controller.markReady();
    await tester.pump();
    expect(find.text('SYSTEM READY'), findsNothing);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('boot-progress-bar')))
          .value,
      '95%',
    );
    await _elapse(tester, _timing.readyDelay + const Duration(milliseconds: 1));
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('boot-progress-bar')))
          .value,
      '100%',
    );
    expect(find.text('SYSTEM READY'), findsOneWidget);
    expect(find.text('MAIN UI'), findsNothing);
    expect(events, [
      BootSequenceEventType.bootStart,
      BootSequenceEventType.systemInitialized,
    ]);

    await _elapse(tester, _timing.readyHold);
    expect(find.text('MAIN UI'), findsOneWidget);
    expect(events, [
      BootSequenceEventType.bootStart,
      BootSequenceEventType.systemInitialized,
      BootSequenceEventType.bootComplete,
    ]);
    semantics.dispose();
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

  testWidgets('active boot row uses the terminal spinner sequence', (
    tester,
  ) async {
    const spinnerTiming = BootSequenceTiming(
      logoIntro: Duration(milliseconds: 10),
      typingCharacter: Duration(milliseconds: 10),
      fullNameCharacter: Duration(milliseconds: 10),
      identityHold: Duration(milliseconds: 10),
      systemBootTransition: Duration(milliseconds: 10),
      row: Duration(milliseconds: 800),
      readyDelay: Duration(milliseconds: 10),
      readyHold: Duration(milliseconds: 10),
    );
    final controller = AppInitializationController();
    await tester.pumpWidget(_gate(controller, timing: spinnerTiming));

    await _elapse(tester, spinnerTiming.logoIntro);
    await _advanceTyping(tester, spinnerTiming);
    await _elapse(tester, spinnerTiming.identityHold);
    await _elapse(tester, spinnerTiming.systemBootTransition);
    expect(find.text('INITIALIZING /'), findsOneWidget);
    await _elapse(tester, const Duration(milliseconds: 120));
    expect(find.text('INITIALIZING |'), findsOneWidget);
    await _elapse(tester, const Duration(milliseconds: 120));
    expect(find.text('INITIALIZING \\'), findsOneWidget);
    await _elapse(tester, const Duration(milliseconds: 120));
    expect(find.text('INITIALIZING -'), findsOneWidget);
  });

  testWidgets('a rebuild does not replay boot events', (tester) async {
    final controller = AppInitializationController()..markReady();
    final events = <BootSequenceEventType>[];
    await tester.pumpWidget(
      _gate(controller, onEvent: (event) => events.add(event.type)),
    );
    await _advanceRows(tester);
    await _elapse(tester, _timing.readyDelay + const Duration(milliseconds: 1));
    await _elapse(tester, _timing.readyHold);
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
    await _elapse(tester, _timing.readyDelay + const Duration(milliseconds: 1));
    await _elapse(tester, _timing.readyHold);

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _gate(
  AppInitializationController controller, {
  BootSequenceEventListener? onEvent,
  BootSequenceTiming timing = _timing,
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
      bootSequenceTiming: timing,
      onBootEvent: onEvent,
      child: const Text('MAIN UI'),
    ),
  );
}

Future<void> _advanceRows(WidgetTester tester) async {
  await _elapse(tester, _timing.logoIntro);
  await _advanceTyping(tester, _timing);
  await _elapse(tester, _timing.identityHold);
  await _elapse(tester, _timing.systemBootTransition);
  await _elapse(tester, _timing.row * 2);
  await _elapse(tester, _timing.row);
  await _elapse(tester, _timing.row);
}

Future<void> _advanceTyping(
  WidgetTester tester,
  BootSequenceTiming timing, {
  int count = 8,
}) async {
  for (var index = 0; index < count; index += 1) {
    await _elapse(tester, timing.typingCharacter);
  }
}

Future<void> _elapse(WidgetTester tester, Duration duration) async {
  await tester.pump(duration);
  await tester.pump();
}

int _progressValue(WidgetTester tester) {
  final value = tester
      .getSemantics(find.byKey(const ValueKey('boot-progress-bar')))
      .value;
  return int.parse(value.replaceAll('%', ''));
}
