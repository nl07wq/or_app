import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/active_session_heartbeat.dart';
import 'package:or_app/core/services/boot_audio.dart';
import 'package:or_app/core/services/boot_presentation_session.dart';
import 'package:or_app/core/services/operation_system_metadata.dart';
import 'package:or_app/core/services/startup_initialization_service.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/boot_sequence.dart';
import 'package:or_app/core/widgets/startup_gate.dart';

const _timing = BootSequenceTiming(
  signalAcquisitionIntro: Duration.zero,
  preBootSignalIntro: Duration.zero,
  logoIntro: Duration(milliseconds: 10),
  waitForLogoDrawable: false,
  postLogoTimingFactor: 1,
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
  test(
    'production Boot timeline acquires signal before reconstruction and fade',
    () {
      const timing = BootSequenceTiming();

      expect(timing.signalAcquisitionIntro, const Duration(milliseconds: 300));
      expect(timing.preBootSignalIntro, const Duration(milliseconds: 450));
      expect(timing.logoIntro, const Duration(milliseconds: 600));
      expect(
        timing.postLogo(timing.typingCharacter),
        const Duration(milliseconds: 120),
      );
      expect(
        timing.postLogo(timing.systemBootTransition),
        const Duration(milliseconds: 190),
      );
      expect(
        timing.postLogo(timing.readyHold),
        const Duration(milliseconds: 400),
      );
      expect(
        timing.postLogo(const Duration(milliseconds: 120)),
        const Duration(milliseconds: 120),
      );
      const identity = [170, 160, 145, 135, 125, 115, 95, 75];
      final deterministicTotal =
          timing.logoIntro +
          Duration(
            milliseconds: identity.fold<int>(0, (sum, value) => sum + value),
          ) +
          timing.fullNameCharacter * 43 +
          timing.identityHold +
          timing.systemBootTransition +
          timing.row * 4 +
          timing.readyDelay +
          timing.readyHold +
          const Duration(milliseconds: 120);
      expect(
        timing.signalAcquisitionIntro +
            timing.preBootSignalIntro +
            deterministicTotal,
        const Duration(milliseconds: 5242),
      );
    },
  );

  test('Boot content restore and slices vary continuously', () {
    expect(bootSignalAcquisitionLineOpacity(0), 0);
    expect(bootSignalAcquisitionLineOpacity(.5), greaterThan(.16));
    expect(bootSignalAcquisitionLineOpacity(1), greaterThan(.75));
    expect(bootSignalAcquisitionInterferenceOpacity(.14), 0);
    expect(bootSignalAcquisitionInterferenceOpacity(.40), greaterThan(.75));
    expect(bootSignalAcquisitionInterferenceOpacity(.60), greaterThan(.75));
    expect(bootSignalAcquisitionInterferenceOpacity(.84), closeTo(0, .000001));
    expect(bootSignalRestoreProgress(.25), 0);
    expect(bootSignalRestoreProgress(.45), greaterThan(0));
    expect(
      bootSignalRestoreProgress(.55),
      greaterThan(bootSignalRestoreProgress(.45)),
    );
    expect(
      bootSignalRestoreProgress(.80),
      greaterThan(bootSignalRestoreProgress(.55)),
    );
    expect(bootSignalRestoreProgress(.95), 1);
    expect(bootSignalRestoreProgress(1), 1);
    expect(
      bootSignalContentScaleY(.25),
      lessThan(bootSignalContentScaleY(.50)),
    );
    expect(
      bootSignalContentScaleY(.50),
      lessThan(bootSignalContentScaleY(.75)),
    );
    expect(bootSignalContentScaleY(.25), closeTo(.02, .001));
    expect(bootSignalContentScaleY(.75), greaterThan(.80));
    expect(bootSignalSliceOffset(.10, 0), isNot(bootSignalSliceOffset(.22, 0)));
    expect(bootSignalSliceOffset(.22, 0), greaterThan(0));
    expect(bootSignalSliceOffset(.22, 1), lessThan(0));
    expect(bootSignalSliceOffset(.95, 0), closeTo(0, .000001));
    expect(bootSignalSliceOffset(.95, 5), closeTo(0, .000001));
    expect(bootSignalLineOpacity(.95), 0);
    expect(bootSignalLineOpacity(1), 0);
    expect(bootIntroSilhouetteOpacity(.10), greaterThan(.08));
    expect(bootIntroSilhouetteOpacity(.35), closeTo(.35, .000001));
    expect(bootIntroSilhouetteOpacity(.35), inInclusiveRange(.30, .35));
    expect(bootIntroSilhouetteOpacity(.20), greaterThan(.30));
    expect(bootIntroSilhouetteOpacity(.95), closeTo(0, .000001));
  });

  testWidgets('signal acquisition completes before ghost reconstruction', (
    tester,
  ) async {
    const timing = BootSequenceTiming(
      signalAcquisitionIntro: Duration(milliseconds: 300),
      preBootSignalIntro: Duration(milliseconds: 450),
      logoIntro: Duration(milliseconds: 10),
      waitForLogoDrawable: false,
      typingCharacter: Duration(milliseconds: 10),
      fullNameCharacter: Duration(milliseconds: 10),
      identityHold: Duration(milliseconds: 10),
      systemBootTransition: Duration(milliseconds: 10),
      row: Duration(milliseconds: 10),
      readyDelay: Duration(milliseconds: 10),
      readyHold: Duration(milliseconds: 10),
    );
    await tester.pumpWidget(
      _gate(AppInitializationController(), timing: timing),
    );

    expect(
      find.byKey(const ValueKey('boot-signal-acquisition')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsNothing);
    await _elapse(tester, const Duration(milliseconds: 301));
    expect(find.byKey(const ValueKey('boot-signal-acquisition')), findsNothing);
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-content-transform')),
      findsOneWidget,
    );
  });

  testWidgets('signal intro completes before the logo fade begins', (
    tester,
  ) async {
    const timing = BootSequenceTiming(
      signalAcquisitionIntro: Duration.zero,
      preBootSignalIntro: Duration(milliseconds: 450),
      logoIntro: Duration(milliseconds: 10),
      waitForLogoDrawable: false,
      typingCharacter: Duration(milliseconds: 10),
      fullNameCharacter: Duration(milliseconds: 10),
      identityHold: Duration(milliseconds: 10),
      systemBootTransition: Duration(milliseconds: 10),
      row: Duration(milliseconds: 10),
      readyDelay: Duration(milliseconds: 10),
      readyHold: Duration(milliseconds: 10),
    );
    await tester.pumpWidget(
      _gate(AppInitializationController(), timing: timing),
    );

    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsOneWidget);
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('boot-brand-logo-fade')),
          )
          .opacity
          .value,
      0,
    );
    await _elapse(tester, const Duration(milliseconds: 220));
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-content-transform')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('boot-content-slice-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-content-slice-5')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-intro-logo-silhouette')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('boot-intro-logo-silhouette')),
          )
          .opacity,
      inInclusiveRange(.30, .35),
    );
    expect(find.text('O.R.L.O.'), findsNothing);
    await _elapse(tester, const Duration(milliseconds: 231));
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsNothing);
    expect(find.byKey(const ValueKey('boot-content-normal')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-intro-logo-silhouette')),
      findsNothing,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('boot-brand-logo-fade')),
          )
          .opacity
          .value,
      0,
    );
    await _elapse(tester, timing.logoIntro + const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('boot-brand-identity')), findsOneWidget);
  });

  testWidgets('skip during signal intro removes the overlay immediately', (
    tester,
  ) async {
    const timing = BootSequenceTiming(
      signalAcquisitionIntro: Duration.zero,
      preBootSignalIntro: Duration(milliseconds: 450),
      waitForLogoDrawable: false,
    );
    await tester.pumpWidget(
      _gate(AppInitializationController()..markReady(), timing: timing),
    );
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
    await tester.pump();

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsNothing);
    expect(
      find.byKey(const ValueKey('boot-intro-logo-silhouette')),
      findsNothing,
    );
  });

  testWidgets('skip during signal acquisition remains immediate', (
    tester,
  ) async {
    const timing = BootSequenceTiming(
      signalAcquisitionIntro: Duration(milliseconds: 300),
      preBootSignalIntro: Duration(milliseconds: 450),
      waitForLogoDrawable: false,
    );
    await tester.pumpWidget(
      _gate(AppInitializationController()..markReady(), timing: timing),
    );
    expect(
      find.byKey(const ValueKey('boot-signal-acquisition')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
    await tester.pump();

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-signal-acquisition')), findsNothing);
    expect(find.byKey(const ValueKey('boot-content-transform')), findsNothing);
  });

  testWidgets('skip during signal restore removes the overlay immediately', (
    tester,
  ) async {
    const timing = BootSequenceTiming(
      signalAcquisitionIntro: Duration.zero,
      preBootSignalIntro: Duration(milliseconds: 450),
      waitForLogoDrawable: false,
    );
    await tester.pumpWidget(
      _gate(AppInitializationController()..markReady(), timing: timing),
    );
    await _elapse(tester, const Duration(milliseconds: 330));
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
    await tester.pump();

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsNothing);
    expect(
      find.byKey(const ValueKey('boot-intro-logo-silhouette')),
      findsNothing,
    );
  });

  testWidgets('skip during the heavy glitch stage removes the overlay', (
    tester,
  ) async {
    const timing = BootSequenceTiming(
      signalAcquisitionIntro: Duration.zero,
      preBootSignalIntro: Duration(milliseconds: 450),
      waitForLogoDrawable: false,
    );
    await tester.pumpWidget(
      _gate(AppInitializationController()..markReady(), timing: timing),
    );
    await _elapse(tester, const Duration(milliseconds: 170));
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
    await tester.pump();

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsNothing);
    expect(
      find.byKey(const ValueKey('boot-intro-logo-silhouette')),
      findsNothing,
    );
  });

  testWidgets('skip during late signal settle removes all content slices', (
    tester,
  ) async {
    const timing = BootSequenceTiming(
      signalAcquisitionIntro: Duration.zero,
      preBootSignalIntro: Duration(milliseconds: 450),
      waitForLogoDrawable: false,
    );
    await tester.pumpWidget(
      _gate(AppInitializationController()..markReady(), timing: timing),
    );
    await _elapse(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('boot-content-slice-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-content-slice-5')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
    await tester.pump();

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-content-transform')), findsNothing);
    expect(find.byKey(const ValueKey('boot-pre-signal-intro')), findsNothing);
    expect(
      find.byKey(const ValueKey('boot-intro-logo-silhouette')),
      findsNothing,
    );
  });

  testWidgets('boot rows are revealed and completed in sequence', (
    tester,
  ) async {
    final controller = AppInitializationController();
    await tester.pumpWidget(_gate(controller));

    expect(find.byKey(const ValueKey('boot-brand-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-brand-logo-fade')), findsOneWidget);
    expect(find.text('SYSTEM BOOT'), findsNothing);
    expect(find.text('CORE SYSTEM'), findsNothing);
    expect(find.text('SYSTEM READY'), findsNothing);
    expect(find.text('TAP TO START'), findsNothing);

    await _advanceLogoFade(tester, _timing);
    await _elapse(tester, _timing.typingCharacter);
    expect(find.text('O'), findsOneWidget);
    expect(find.text('O.R.L.O.'), findsNothing);
    await _advanceTyping(tester, _timing, count: 7);
    expect(find.byKey(const ValueKey('boot-brand-full-name')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-operation-system-version')),
      findsOneWidget,
    );
    expect(find.text(OperationSystemMetadata.version), findsOneWidget);
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
      signalAcquisitionIntro: Duration.zero,
      preBootSignalIntro: Duration.zero,
      logoIntro: Duration(milliseconds: 1),
      waitForLogoDrawable: false,
      postLogoTimingFactor: 1,
      typingCharacter: Duration(milliseconds: 1),
      fullNameCharacter: Duration(milliseconds: 17),
      identityHold: Duration(milliseconds: 230),
      systemBootTransition: Duration(milliseconds: 1),
      row: Duration(milliseconds: 1),
      readyDelay: Duration(milliseconds: 1),
      readyHold: Duration(milliseconds: 1),
    );
    final controller = AppInitializationController();
    await tester.pumpWidget(_gate(controller, timing: typingTiming));

    await _advanceLogoFade(tester, typingTiming);
    await _advanceTyping(tester, typingTiming);
    expect(find.text('O.R.L.O.'), findsOneWidget);
    expect(find.text(OperationSystemMetadata.version), findsNothing);
    expect(find.text('SYSTEM BOOT'), findsNothing);

    expect(
      const BootSequenceTiming().fullNameCharacter,
      const Duration(milliseconds: 14),
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
    final axis = tester.widget<Text>(
      find.byKey(const ValueKey('boot-operation-system-version')),
    );
    expect(axis.data, isEmpty);
    expect(find.text('SYSTEM BOOT'), findsNothing);
    await _elapse(tester, const Duration(milliseconds: 81));
    expect(find.text('AX '), findsOneWidget);
    expect(find.text('SYSTEM BOOT'), findsNothing);
    await _elapse(tester, const Duration(milliseconds: 135));
    expect(find.text(OperationSystemMetadata.version), findsOneWidget);
    expect(find.text('SYSTEM BOOT'), findsNothing);
    await _elapse(tester, const Duration(milliseconds: 14));
    expect(find.text('SYSTEM BOOT'), findsOneWidget);
  });

  testWidgets('skip bypasses AX typing immediately', (tester) async {
    const timing = BootSequenceTiming(
      signalAcquisitionIntro: Duration.zero,
      preBootSignalIntro: Duration.zero,
      logoIntro: Duration(milliseconds: 1),
      waitForLogoDrawable: false,
      typingCharacter: Duration(milliseconds: 1),
      fullNameCharacter: Duration(milliseconds: 17),
      identityHold: Duration(milliseconds: 230),
      systemBootTransition: Duration(milliseconds: 1),
      row: Duration(milliseconds: 1),
      readyDelay: Duration(milliseconds: 1),
      readyHold: Duration(milliseconds: 1),
    );
    await tester.pumpWidget(
      _gate(AppInitializationController()..markReady(), timing: timing),
    );

    await _advanceLogoFade(tester, timing);
    await _advanceTyping(tester, timing);
    await _elapse(tester, timing.fullNameCharacter * 43);
    expect(
      find.byKey(const ValueKey('boot-operation-system-version')),
      findsOneWidget,
    );
    await _elapse(tester, const Duration(milliseconds: 81));
    expect(find.text('AX '), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
    await tester.pump();

    expect(find.text('MAIN UI'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-operation-system-version')),
      findsNothing,
    );
  });

  testWidgets('boot progress continuously advances through visual phases', (
    tester,
  ) async {
    const continuousTiming = BootSequenceTiming(
      signalAcquisitionIntro: Duration.zero,
      preBootSignalIntro: Duration.zero,
      logoIntro: Duration(milliseconds: 20),
      waitForLogoDrawable: false,
      postLogoTimingFactor: 1,
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
    await _advanceLogoFade(tester, continuousTiming);
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
      signalAcquisitionIntro: Duration.zero,
      preBootSignalIntro: Duration.zero,
      logoIntro: Duration(milliseconds: 10),
      waitForLogoDrawable: false,
      postLogoTimingFactor: 1,
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
    await _advanceLogoFade(tester, spinnerTiming);
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
    await tester.pump();
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
    await tester.pump();
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
    expect(bootSignalCoreColor, const Color(0xFFF4FAFC));
    expect((bootSignalHaloColor.a * 255).round(), greaterThan(0x66));
    expect((bootSignalFragmentColor.a * 255).round(), greaterThan(0xB0));
  });

  testWidgets(
    'completed and skipped boot presentations are disposed before same-session loading',
    (tester) async {
      final completedController = AppInitializationController()..markReady();
      await tester.pumpWidget(_gate(completedController));
      await _advanceRows(tester);
      await _elapse(
        tester,
        _timing.readyDelay + const Duration(milliseconds: 1),
      );
      await _elapse(tester, _timing.readyHold);
      await _elapse(tester, const Duration(milliseconds: 120));
      expect(find.text('MAIN UI'), findsOneWidget);

      completedController.updateStage(InitializationStage.openingDatabase);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('startup-initializing-view')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('boot-signal-handoff')), findsNothing);
      expect(find.byKey(const ValueKey('boot-brand-logo')), findsNothing);

      final skippedController = AppInitializationController()..markReady();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(_gate(skippedController));
      await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
      await tester.pump();
      expect(find.text('MAIN UI'), findsOneWidget);

      skippedController.updateStage(InitializationStage.openingDatabase);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('startup-initializing-view')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('boot-brand-logo')), findsNothing);
      expect(find.byKey(const ValueKey('boot-signal-handoff')), findsNothing);
    },
  );

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

  testWidgets(
    'recent active-session heartbeat suppresses Boot when session storage is absent',
    (tester) async {
      final now = DateTime(2026, 9, 4, 12);
      final storage = InMemoryActiveSessionStorage({
        ActiveSessionHeartbeat.storageKey:
            '{"version":1,"lastAliveAtMs":${now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch}}',
      });
      final heartbeat = ActiveSessionHeartbeat(
        now: () => now,
        storage: storage,
      );
      heartbeat.classifyAtStartup();
      final controller = AppInitializationController(
        bootPresentationSession: BootPresentationSession(
          activeSessionHeartbeat: heartbeat,
        ),
      );

      await tester.pumpWidget(_gate(controller));

      expect(
        find.byKey(const ValueKey('startup-initializing-view')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('boot-brand-logo')), findsNothing);
      expect(find.byKey(const ValueKey('boot-tap-to-skip')), findsNothing);
      expect(find.byKey(const ValueKey('boot-signal-handoff')), findsNothing);
    },
  );

  testWidgets(
    'full Boot followed by active-session document recreation shows initializing',
    (tester) async {
      final completedController = AppInitializationController()..markReady();
      await tester.pumpWidget(_gate(completedController));
      await _advanceRows(tester);
      await _elapse(
        tester,
        _timing.readyDelay + const Duration(milliseconds: 1),
      );
      await _elapse(tester, _timing.readyHold);
      await _elapse(tester, const Duration(milliseconds: 120));
      expect(find.text('MAIN UI'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(_gate(_activeSessionReentryController()));

      expect(
        find.byKey(const ValueKey('startup-initializing-view')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('boot-brand-logo')), findsNothing);
      expect(find.byKey(const ValueKey('boot-signal-handoff')), findsNothing);
    },
  );

  testWidgets(
    'skipped Boot followed by active-session document recreation shows initializing',
    (tester) async {
      final skippedController = AppInitializationController()..markReady();
      await tester.pumpWidget(_gate(skippedController));
      await tester.tap(find.byKey(const ValueKey('boot-tap-to-skip')));
      await tester.pump();
      expect(find.text('MAIN UI'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(_gate(_activeSessionReentryController()));

      expect(
        find.byKey(const ValueKey('startup-initializing-view')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('boot-brand-logo')), findsNothing);
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

AppInitializationController _activeSessionReentryController() {
  final now = DateTime(2026, 9, 4, 12);
  final heartbeat = ActiveSessionHeartbeat(
    now: () => now,
    storage: InMemoryActiveSessionStorage({
      ActiveSessionHeartbeat.storageKey:
          '{"version":1,"lastAliveAtMs":${now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch}}',
    }),
  )..classifyAtStartup();
  return AppInitializationController(
    bootPresentationSession: BootPresentationSession(
      activeSessionHeartbeat: heartbeat,
    ),
  );
}

Future<void> _advanceRows(WidgetTester tester) async {
  await _advanceLogoFade(tester, _timing);
  await _advanceTyping(tester, _timing);
  await _elapse(tester, _timing.identityHold);
  await _elapse(tester, _timing.systemBootTransition);
  await _elapse(tester, _timing.row * 2);
  await _elapse(tester, _timing.row);
  await _elapse(tester, _timing.row);
}

Future<void> _advanceLogoFade(
  WidgetTester tester,
  BootSequenceTiming timing,
) async {
  await tester.pump();
  expect(find.text('O.R.L.O.'), findsNothing);
  await _elapse(
    tester,
    timing.preBootSignalIntro + const Duration(milliseconds: 1),
  );
  await _elapse(tester, timing.logoIntro);
  expect(
    tester
        .widget<FadeTransition>(
          find.byKey(const ValueKey('boot-brand-logo-fade')),
        )
        .opacity
        .value,
    1,
  );
  await _elapse(tester, const Duration(milliseconds: 1));
  expect(find.byKey(const ValueKey('boot-brand-identity')), findsOneWidget);
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
