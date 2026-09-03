import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/boot_audio.dart';
import 'package:or_app/core/services/boot_presentation_session.dart';
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
    expect(find.text('TAP TO START'), findsNothing);

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

  testWidgets('full name types before system boot at the configured rate', (
    tester,
  ) async {
    const typedName = 'Operation Reasoning Lifesystem Orchestrator';
    const typingTiming = BootSequenceTiming(
      logoIntro: Duration(milliseconds: 1),
      typingCharacter: Duration(milliseconds: 1),
      fullNameCharacter: Duration(milliseconds: 17),
      identityHold: Duration(milliseconds: 1),
      systemBootTransition: Duration(milliseconds: 1),
      row: Duration(milliseconds: 1),
      readyDelay: Duration(milliseconds: 1),
      readyHold: Duration(milliseconds: 1),
    );
    final controller = AppInitializationController();
    await tester.pumpWidget(_gate(controller, timing: typingTiming));

    await _elapse(tester, typingTiming.logoIntro);
    await _advanceTyping(tester, typingTiming);
    expect(find.text('O.R.L.O.'), findsOneWidget);
    expect(find.text('SYSTEM BOOT'), findsNothing);

    expect(
      const BootSequenceTiming().fullNameCharacter,
      const Duration(milliseconds: 17),
    );
    await _elapse(tester, typingTiming.fullNameCharacter * 2);
    final partial = tester.widget<Text>(
      find.byKey(const ValueKey('boot-brand-full-name')),
    );
    expect(partial.data, typedName.substring(0, 2));
    expect(find.text('SYSTEM BOOT'), findsNothing);

    await _elapse(
      tester,
      typingTiming.fullNameCharacter * (typedName.length - 2),
    );
    expect(find.text(typedName), findsOneWidget);
    expect(find.text('SYSTEM BOOT'), findsNothing);
    await _elapse(tester, typingTiming.identityHold);
    expect(find.text('SYSTEM BOOT'), findsOneWidget);
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
    final w0 = tester
        .getSize(find.byKey(const ValueKey('boot-progress-fill')))
        .width;
    expect(
      tester.getSize(find.byKey(const ValueKey('boot-progress-bar'))).height,
      10,
    );

    await _elapse(tester, const Duration(milliseconds: 300));
    final p1 = _progressValue(tester);
    final w1 = tester
        .getSize(find.byKey(const ValueKey('boot-progress-fill')))
        .width;
    await _elapse(tester, const Duration(milliseconds: 300));
    final p2 = _progressValue(tester);
    final w2 = tester
        .getSize(find.byKey(const ValueKey('boot-progress-fill')))
        .width;
    await _elapse(tester, const Duration(milliseconds: 300));
    final p3 = _progressValue(tester);
    final w3 = tester
        .getSize(find.byKey(const ValueKey('boot-progress-fill')))
        .width;

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
    expect(find.byKey(const ValueKey('boot-signal-handoff')), findsOneWidget);
    expect(find.text('MAIN UI'), findsNothing);
    await _elapse(tester, const Duration(milliseconds: 120));
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
    expect(find.text('TAP TO START'), findsNothing);
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
    expect(find.byKey(const ValueKey('boot-signal-handoff')), findsOneWidget);
    await _elapse(tester, const Duration(milliseconds: 120));
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
    expect(find.byKey(const ValueKey('boot-signal-handoff')), findsOneWidget);
    await _elapse(tester, const Duration(milliseconds: 120));

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal boot leaves the official audio service idle', (
    tester,
  ) async {
    final controller = AppInitializationController();
    final audio = _RecordingBootAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: BootSequenceGate(
          initialization: controller,
          fallbackBuilder: (_) => const SizedBox(),
          bootAudio: audio,
          child: const Text('MAIN UI'),
        ),
      ),
    );
    await _elapse(tester, _timing.logoIntro);
    expect(audio.playCalls, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: BootSequenceGate(
          initialization: controller,
          fallbackBuilder: (_) => const SizedBox(),
          bootAudio: audio,
          child: const Text('MAIN UI'),
        ),
      ),
    );
    expect(audio.playCalls, 0);
  });

  testWidgets(
    'a reinitialization replaces an active signal handoff with loading',
    (tester) async {
      final controller = AppInitializationController()..markReady();
      await tester.pumpWidget(_gate(controller));
      await _advanceRows(tester);
      await _elapse(
        tester,
        _timing.readyDelay + const Duration(milliseconds: 1),
      );
      await _elapse(tester, _timing.readyHold);
      expect(find.byKey(const ValueKey('boot-signal-handoff')), findsOneWidget);

      controller.updateStage(InitializationStage.openingDatabase);
      await tester.pump();
      expect(find.text('INITIALIZING'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('startup-initializing-view'))),
        isNot(Size.zero),
      );
      expect(find.text('TAP TO START'), findsNothing);
      expect(find.byKey(const ValueKey('boot-signal-handoff')), findsNothing);

      controller.markReady();
      await tester.pump();
      expect(find.text('MAIN UI'), findsOneWidget);
    },
  );

  testWidgets('an unused boot audio service cannot affect automatic boot', (
    tester,
  ) async {
    final controller = AppInitializationController();
    await tester.pumpWidget(
      MaterialApp(
        home: BootSequenceGate(
          initialization: controller,
          fallbackBuilder: (_) => const SizedBox(),
          bootAudio: _ThrowingBootAudio(),
          child: const Text('MAIN UI'),
        ),
      ),
    );
    await _elapse(tester, _timing.logoIntro);
    expect(find.byKey(const ValueKey('boot-brand-logo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip goes directly to main when initialization is ready', (
    tester,
  ) async {
    final controller = AppInitializationController()..markReady();
    await tester.pumpWidget(_gate(controller));

    expect(find.byKey(const ValueKey('boot-tap-to-skip')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
    await tester.pump();

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-signal-handoff')), findsNothing);
    await _elapse(tester, const Duration(seconds: 2));
    expect(find.text('MAIN UI'), findsOneWidget);
    expect(find.text('SYSTEM READY'), findsNothing);
  });

  testWidgets(
    'skip waits visibly for initialization and ignores old callbacks',
    (tester) async {
      final controller = AppInitializationController();
      await tester.pumpWidget(_gate(controller));

      await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
      await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
      await tester.pump();

      expect(find.text('INITIALIZING'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('startup-initializing-view'))),
        isNot(Size.zero),
      );
      expect(find.byKey(const ValueKey('boot-signal-handoff')), findsNothing);
      await _elapse(tester, const Duration(seconds: 2));
      expect(find.text('INITIALIZING'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('startup-initializing-view'))),
        isNot(Size.zero),
      );
      expect(find.text('SYSTEM READY'), findsNothing);

      controller.markReady();
      await tester.pump();
      expect(find.text('MAIN UI'), findsOneWidget);
    },
  );

  testWidgets(
    'failure after skip remains failure and never shows the handoff',
    (tester) async {
      final controller = AppInitializationController();
      await tester.pumpWidget(_gate(controller));
      await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
      await tester.pump();
      controller.markFailed(errorCode: 'test', errorMessage: 'failure');
      await tester.pump();

      expect(find.text('DATA INITIALIZATION FAILED'), findsOneWidget);
      expect(find.text('MAIN UI'), findsNothing);
      expect(find.byKey(const ValueKey('boot-signal-handoff')), findsNothing);
    },
  );

  testWidgets(
    'a rebuilt startup gate uses loading, never a second boot handoff',
    (tester) async {
      final controller = AppInitializationController()..markReady();
      final trace = <BootStartupTraceEvent>[];
      await tester.pumpWidget(_gate(controller, onTrace: trace.add));
      await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
      await tester.pump();
      expect(find.text('MAIN UI'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      controller.updateStage(InitializationStage.openingDatabase);
      await tester.pumpWidget(_gate(controller, onTrace: trace.add));
      await tester.pump();

      expect(find.text('INITIALIZING'), findsOneWidget);
      expect(find.byKey(const ValueKey('boot-tap-to-skip')), findsNothing);
      expect(find.byKey(const ValueKey('boot-signal-handoff')), findsNothing);
      expect(
        trace.where(
          (event) => event.nextState == BootPresentationState.bootHandoffSignal,
        ),
        isEmpty,
      );
      controller.markReady();
      await tester.pump();
      expect(find.text('MAIN UI'), findsOneWidget);
    },
  );

  testWidgets('normal handoff uses a moving sync sweep', (tester) async {
    final controller = AppInitializationController()..markReady();
    await tester.pumpWidget(_gate(controller));
    await _advanceRows(tester);
    await _elapse(tester, _timing.readyDelay + const Duration(milliseconds: 1));
    await _elapse(tester, _timing.readyHold);

    final start = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('boot-signal-sync-sweep')),
    );
    final startFrame = (start.painter! as BootSignalHandoffPainter).frame;
    await _elapse(tester, const Duration(milliseconds: 40));
    final later = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('boot-signal-sync-sweep')),
    );
    final laterFrame = (later.painter! as BootSignalHandoffPainter).frame;

    expect(laterFrame, greaterThan(startFrame));
    expect(laterFrame, lessThanOrEqualTo(1));
    expect(bootSignalCoreColor, const Color(0xFFF1F8FA));
    expect((bootSignalHaloColor.a * 255).round(), greaterThan(0x55));
    expect((bootSignalFragmentColor.a * 255).round(), greaterThan(0x99));
  });

  testWidgets('a genuinely new controller receives the normal initial boot', (
    tester,
  ) async {
    await tester.pumpWidget(_gate(AppInitializationController()));

    expect(find.byKey(const ValueKey('boot-brand-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-tap-to-skip')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('startup-initializing-view')),
      findsNothing,
    );
  });

  testWidgets(
    'a recreated web-session controller renders canonical initializing',
    (tester) async {
      final session = BootPresentationSession();
      final initialController = AppInitializationController(
        bootPresentationSession: session,
      )..markReady();
      await tester.pumpWidget(_gate(initialController));
      await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
      await tester.pump();
      expect(find.text('MAIN UI'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final reloadedController = AppInitializationController(
        bootPresentationSession: session,
      );
      await tester.pumpWidget(_gate(reloadedController));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('startup-initializing-view')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('startup-initializing-text')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('boot-signal-handoff')), findsNothing);
      expect(find.byKey(const ValueKey('boot-tap-to-skip')), findsNothing);
    },
  );

  test('official boot audio asset is present', () {
    expect(File('assets/audio/boot/ORLO_Boot_v17.wav').existsSync(), isTrue);
    expect(bootAudioAssetUrl, 'assets/assets/audio/boot/ORLO_Boot_v17.wav');
  });
}

class _RecordingBootAudio implements BootAudio {
  int playCalls = 0;

  @override
  void playOnce() => playCalls += 1;
}

class _ThrowingBootAudio implements BootAudio {
  @override
  void playOnce() => throw StateError('autoplay blocked');
}

Widget _gate(
  AppInitializationController controller, {
  BootSequenceEventListener? onEvent,
  BootStartupTraceListener? onTrace,
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
      onBootTrace: onTrace,
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
