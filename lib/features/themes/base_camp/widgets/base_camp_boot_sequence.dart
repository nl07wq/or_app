import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/device_settings_controller.dart';
import '../../../../core/services/system_diagnostics.dart';
import '../../../../core/state/app_initialization_state.dart';
import '../../../../core/widgets/boot_sequence.dart';
import '../base_camp_retro_terminal.dart';
import '../base_camp_retro_theme.dart';

/// BASE CAMP-only startup presentation. Initialization remains entirely owned
/// by [AppInitializationController]; this widget only renders verified state.
class BaseCampBootSequenceGate extends StatefulWidget {
  const BaseCampBootSequenceGate({
    super.key,
    required this.initialization,
    required this.fallbackBuilder,
    required this.onPresentationReleased,
    this.onEvent,
  });

  final ValueListenable<AppInitializationState> initialization;
  final Widget Function(AppInitializationState state) fallbackBuilder;
  final VoidCallback onPresentationReleased;
  final BootSequenceEventListener? onEvent;

  @override
  State<BaseCampBootSequenceGate> createState() =>
      _BaseCampBootSequenceGateState();
}

class _BaseCampBootSequenceGateState extends State<BaseCampBootSequenceGate> {
  bool _releaseScheduled = false;
  bool _systemInitializedEmitted = false;
  InitializationStage? _lastRecordedStage;
  PersistenceMode? _lastRecordedMode;

  @override
  void initState() {
    super.initState();
    widget.onEvent?.call(
      BootSequenceEvent(
        type: BootSequenceEventType.bootStart,
        occurredAt: DateTime.now(),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemDiagnostics.instance.record(
        'STARTUP',
        'BASE_CAMP_BOOT_FIRST_FRAME',
        fields: <String, Object?>{
          'stage': widget.initialization.value.currentStage.name,
          'mode': widget.initialization.value.mode.name,
        },
      );
    });
  }

  void _recordState(AppInitializationState state) {
    if (_lastRecordedStage == state.currentStage &&
        _lastRecordedMode == state.mode) {
      return;
    }
    _lastRecordedStage = state.currentStage;
    _lastRecordedMode = state.mode;
    SystemDiagnostics.instance.record(
      'STARTUP',
      'BASE_CAMP_BOOT_STATE',
      fields: <String, Object?>{
        'stage': state.currentStage.name,
        'mode': state.mode.name,
        'phase': baseCampBootPhaseFor(state).name,
      },
    );
  }

  void _scheduleRelease(AppInitializationState state) {
    if (_releaseScheduled || state.mode == PersistenceMode.initializing) return;
    if (state.mode == PersistenceMode.failed) return;
    _releaseScheduled = true;
    if (state.mode == PersistenceMode.indexedDbReadWrite &&
        !_systemInitializedEmitted) {
      _systemInitializedEmitted = true;
      widget.onEvent?.call(
        BootSequenceEvent(
          type: BootSequenceEventType.systemInitialized,
          occurredAt: DateTime.now(),
        ),
      );
    }
    // One frame makes the verified terminal state observable. There is no
    // completion timer: the existing StartupGate resumes immediately after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onEvent?.call(
        BootSequenceEvent(
          type: BootSequenceEventType.bootComplete,
          occurredAt: DateTime.now(),
        ),
      );
      widget.onPresentationReleased();
    });
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<AppInitializationState>(
        valueListenable: widget.initialization,
        builder: (context, state, _) {
          _recordState(state);
          if (state.mode == PersistenceMode.failed) {
            return widget.fallbackBuilder(state);
          }
          _scheduleRelease(state);
          return ValueListenableBuilder<DeviceSettings>(
            valueListenable: DeviceSettingsController.instance,
            builder: (context, settings, _) {
              final palette = BaseCampTerminalPalette(
                negative: settings.baseCampLcdNegative,
              );
              return BaseCampTerminalPaletteScope(
                palette: palette,
                child: _BaseCampBootTerminal(state: state, palette: palette),
              );
            },
          );
        },
      );
}

enum BaseCampBootPhase { powerOn, systemCheck, baseCampLink, systemReady }

@visibleForTesting
BaseCampBootPhase baseCampBootPhaseFor(AppInitializationState state) {
  if (state.mode == PersistenceMode.indexedDbReadWrite) {
    return BaseCampBootPhase.systemReady;
  }
  return switch (state.currentStage) {
    InitializationStage.openingDatabase => BaseCampBootPhase.powerOn,
    InitializationStage.verifyingRepositories ||
    InitializationStage.restoringDailyState ||
    InitializationStage.complete => BaseCampBootPhase.baseCampLink,
    _ => BaseCampBootPhase.systemCheck,
  };
}

enum _TerminalCheckState { checking, ready }

class _BaseCampBootTerminal extends StatelessWidget {
  const _BaseCampBootTerminal({required this.state, required this.palette});

  final AppInitializationState state;
  final BaseCampTerminalPalette palette;

  @override
  Widget build(BuildContext context) {
    final phase = baseCampBootPhaseFor(state);
    final database = _databaseState(state);
    final status = _statusState(state);
    final system = state.mode == PersistenceMode.indexedDbReadWrite
        ? _TerminalCheckState.ready
        : _TerminalCheckState.checking;
    return ColoredBox(
      key: const ValueKey('base-camp-boot'),
      color: const Color(0xff11150f),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                key: const ValueKey('base-camp-boot-housing'),
                decoration: BoxDecoration(
                  color: const Color(0xff788a66),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xff273326), width: 3),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0xaa0b0f09),
                      blurRadius: 12,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Stack(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _TerminalHeader(phase: phase),
                          const SizedBox(height: 11),
                          BaseCampLcdSurface(
                            palette: palette,
                            padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 278),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Text(
                                    'OPERATION REBOOT',
                                    key: const ValueKey(
                                      'base-camp-boot-identification',
                                    ),
                                    style: _lcdText(
                                      palette.primaryText,
                                      15,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    'BASE CAMP / COMMAND TERMINAL',
                                    style: _lcdText(
                                      palette.auxiliaryText,
                                      8,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _CheckLine(
                                    label: 'DATABASE',
                                    state: database,
                                    palette: palette,
                                  ),
                                  const SizedBox(height: 9),
                                  _CheckLine(
                                    label: 'STATUS',
                                    state: status,
                                    palette: palette,
                                  ),
                                  const SizedBox(height: 9),
                                  _CheckLine(
                                    label: 'SYSTEM',
                                    state: system,
                                    palette: palette,
                                  ),
                                  const SizedBox(height: 24),
                                  _LinkReadout(phase: phase, palette: palette),
                                  const SizedBox(height: 12),
                                  _VerifiedProgress(
                                    phase: phase,
                                    palette: palette,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 11),
                          const _TerminalFooter(),
                        ],
                      ),
                    ),
                    const Positioned(left: 8, top: 8, child: _HousingScrew()),
                    const Positioned(right: 8, top: 8, child: _HousingScrew()),
                    const Positioned(
                      left: 8,
                      bottom: 8,
                      child: _HousingScrew(),
                    ),
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: _HousingScrew(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader({required this.phase});

  final BaseCampBootPhase phase;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff273326),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: const Color(0xff485c3f)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'COMMAND TERMINAL',
              style: _lcdText(const Color(0xffaeb894), 9),
            ),
          ),
          Text(
            _phaseLabel(phase),
            key: const ValueKey('base-camp-boot-phase'),
            style: _lcdText(const Color(0xffaeb894), 8),
          ),
        ],
      ),
    ),
  );
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.label,
    required this.state,
    required this.palette,
  });

  final String label;
  final _TerminalCheckState state;
  final BaseCampTerminalPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: state == _TerminalCheckState.ready
              ? palette.primaryText
              : Colors.transparent,
          border: Border.all(color: palette.primaryText),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(child: Text(label, style: _lcdText(palette.primaryText, 9))),
      Text(
        state == _TerminalCheckState.ready ? 'READY' : 'CHECKING',
        key: ValueKey<String>('base-camp-boot-${label.toLowerCase()}-state'),
        style: _lcdText(
          state == _TerminalCheckState.ready
              ? palette.primaryText
              : palette.auxiliaryText,
          8,
        ),
      ),
    ],
  );
}

class _LinkReadout extends StatelessWidget {
  const _LinkReadout({required this.phase, required this.palette});

  final BaseCampBootPhase phase;
  final BaseCampTerminalPalette palette;

  @override
  Widget build(BuildContext context) {
    final active =
        phase == BaseCampBootPhase.baseCampLink ||
        phase == BaseCampBootPhase.systemReady;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.field,
        border: Border.all(color: palette.auxiliaryText),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                phase == BaseCampBootPhase.systemReady
                    ? 'SYSTEM READY'
                    : 'BASE CAMP LINK',
                key: const ValueKey('base-camp-boot-link-label'),
                style: _lcdText(palette.primaryText, 8),
              ),
            ),
            ...List<Widget>.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.only(left: 3),
                child: SizedBox(
                  width: 4,
                  height: 9,
                  child: ColoredBox(
                    color: active && index.isEven
                        ? palette.primaryText
                        : palette.auxiliaryText.withValues(alpha: .45),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedProgress extends StatelessWidget {
  const _VerifiedProgress({required this.phase, required this.palette});

  final BaseCampBootPhase phase;
  final BaseCampTerminalPalette palette;

  @override
  Widget build(BuildContext context) {
    final completed = phase.index + 1;
    return Row(
      key: const ValueKey('base-camp-boot-progress'),
      children: List<Widget>.generate(
        BaseCampBootPhase.values.length,
        (index) => Expanded(
          child: Container(
            height: 8,
            margin: EdgeInsets.only(
              right: index == BaseCampBootPhase.values.length - 1 ? 0 : 4,
            ),
            decoration: BoxDecoration(
              color: index < completed
                  ? palette.primaryText
                  : Colors.transparent,
              border: Border.all(color: palette.auxiliaryText),
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalFooter extends StatelessWidget {
  const _TerminalFooter();

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xffaeb894),
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xff273326), width: 2),
          ),
        ),
        child: SizedBox.square(
          key: ValueKey('base-camp-boot-power-indicator'),
          dimension: 9,
        ),
      ),
      const SizedBox(width: 6),
      Text('PWR', style: _lcdText(const Color(0xff273326), 7)),
      const Spacer(),
      Text('OR-BC / CT-01', style: _lcdText(const Color(0xff273326), 7)),
    ],
  );
}

class _HousingScrew extends StatelessWidget {
  const _HousingScrew();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(color: Color(0xff273326), shape: BoxShape.circle),
    child: SizedBox.square(dimension: 4),
  );
}

_TerminalCheckState _databaseState(AppInitializationState state) =>
    switch (state.currentStage) {
      InitializationStage.verifyingRepositories ||
      InitializationStage.restoringDailyState ||
      InitializationStage.complete => _TerminalCheckState.ready,
      _ => _TerminalCheckState.checking,
    };

_TerminalCheckState _statusState(AppInitializationState state) =>
    switch (state.currentStage) {
      InitializationStage.migratingActivity ||
      InitializationStage.migratingFood ||
      InitializationStage.migratingTraining ||
      InitializationStage.migratingCustomTrainingExercises ||
      InitializationStage.migratingConfirmation ||
      InitializationStage.verifyingCustomTrainingExercises ||
      InitializationStage.verifyingRepositories ||
      InitializationStage.restoringDailyState ||
      InitializationStage.complete => _TerminalCheckState.ready,
      _ => _TerminalCheckState.checking,
    };

String _phaseLabel(BaseCampBootPhase phase) => switch (phase) {
  BaseCampBootPhase.powerOn => 'POWER ON',
  BaseCampBootPhase.systemCheck => 'SYSTEM CHECK',
  BaseCampBootPhase.baseCampLink => 'BASE CAMP LINK',
  BaseCampBootPhase.systemReady => 'SYSTEM READY',
};

TextStyle _lcdText(Color color, double size, {double height = 1.25}) =>
    TextStyle(
      color: color,
      fontFamily: baseCampPixelFontFamily,
      fontFamilyFallback: const <String>[baseCampJapaneseFontFallback],
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: height,
    );
