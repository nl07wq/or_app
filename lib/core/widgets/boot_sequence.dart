import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/boot_audio.dart';
import '../services/startup_diagnostic.dart';
import '../state/app_initialization_state.dart';

enum BootSequenceEventType { bootStart, systemInitialized, bootComplete }

class BootSequenceEvent {
  final BootSequenceEventType type;
  final DateTime occurredAt;

  const BootSequenceEvent({required this.type, required this.occurredAt});
}

typedef BootSequenceEventListener = void Function(BootSequenceEvent event);

const _fullName = 'Operation Reasoning Lifesystem Orchestrator';
const _bootSignalHandoffDuration = Duration(milliseconds: 120);
const bootSignalCoreColor = Color(0xFFF4FAFC);
const bootSignalHaloColor = Color(0x707FADBA);
const bootSignalFragmentColor = Color(0xB8A4C4CE);

/// A small deterministic visual timeline. It does not represent persistence
/// work and remains independent from the real initialization state.
class BootSequenceTiming {
  final Duration logoIntro;
  final Duration typingCharacter;
  final Duration fullNameCharacter;
  final Duration identityHold;
  final Duration systemBootTransition;
  final Duration header;
  final Duration row;
  final Duration readyDelay;
  final Duration readyHold;

  const BootSequenceTiming({
    this.logoIntro = const Duration(milliseconds: 360),
    this.typingCharacter = const Duration(milliseconds: 130),
    this.fullNameCharacter = const Duration(milliseconds: 17),
    this.identityHold = const Duration(milliseconds: 320),
    this.systemBootTransition = const Duration(milliseconds: 240),
    this.header = const Duration(milliseconds: 180),
    this.row = const Duration(milliseconds: 360),
    this.readyDelay = const Duration(milliseconds: 300),
    this.readyHold = const Duration(milliseconds: 500),
  });
}

enum _BootVisualPhase {
  logo,
  identityTyping,
  identityName,
  systemBoot,
  coreInitializing,
  dataInitializing,
  operationInitializing,
  waitingForInitialization,
  finalizing,
  systemReady,
}

enum BootPresentationState {
  initialBootPresentation,
  systemReadyPresentation,
  bootHandoffSignal,
  skipped,
  reinitializationLoading,
  mainUi,
  failure,
}

class BootStartupTraceEvent {
  final DateTime occurredAt;
  final String event;
  final BootPresentationState previousState;
  final BootPresentationState nextState;
  final PersistenceMode initializationMode;
  final String visualPhase;
  final int session;

  const BootStartupTraceEvent({
    required this.occurredAt,
    required this.event,
    required this.previousState,
    required this.nextState,
    required this.initializationMode,
    required this.visualPhase,
    required this.session,
  });

  @override
  String toString() =>
      'STARTUP_TRACE t=$occurredAt event=$event session=$session '
      'startup=${initializationMode.name} boot=${nextState.name} '
      'visual=$visualPhase';
}

typedef BootStartupTraceListener = void Function(BootStartupTraceEvent event);

class _BootSequenceVisual extends StatefulWidget {
  final _BootVisualPhase phase;
  final int typedLength;
  final int typedNameLength;
  final double progress;
  final VoidCallback onSkip;

  const _BootSequenceVisual({
    required this.phase,
    required this.typedLength,
    required this.typedNameLength,
    required this.progress,
    required this.onSkip,
  });

  @override
  State<_BootSequenceVisual> createState() => _BootSequenceVisualState();
}

class _BootSequenceVisualState extends State<_BootSequenceVisual>
    with TickerProviderStateMixin {
  late final AnimationController _cursorController;
  late final AnimationController _spinnerController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void didUpdateWidget(covariant _BootSequenceVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = _isInitializing(oldWidget.phase);
    final isActive = _isInitializing(widget.phase);
    if (isActive && oldWidget.phase != widget.phase) {
      _spinnerController
        ..reset()
        ..repeat();
    } else if (wasActive && !isActive) {
      _spinnerController.stop();
    }
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _spinnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _spinnerController,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final phase = widget.phase;
    final rows = <Widget>[
      if (phase.index >= _BootVisualPhase.coreInitializing.index)
        _BootStatusLine(
          key: const ValueKey('boot-row-core'),
          label: 'CORE SYSTEM',
          initializing: phase == _BootVisualPhase.coreInitializing,
          spinner: _spinnerCharacter,
        ),
      if (phase.index >= _BootVisualPhase.dataInitializing.index)
        _BootStatusLine(
          key: const ValueKey('boot-row-data'),
          label: 'DATA INITIALIZATION',
          initializing: phase == _BootVisualPhase.dataInitializing,
          spinner: _spinnerCharacter,
        ),
      if (phase.index >= _BootVisualPhase.operationInitializing.index)
        _BootStatusLine(
          key: const ValueKey('boot-row-operation'),
          label: 'OPERATION DATA',
          initializing: phase == _BootVisualPhase.operationInitializing,
          spinner: _spinnerCharacter,
        ),
    ];
    final hasActiveRow =
        phase == _BootVisualPhase.coreInitializing ||
        phase == _BootVisualPhase.dataInitializing ||
        phase == _BootVisualPhase.operationInitializing;
    return ColoredBox(
      color: const Color(0xFF101010),
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/icons/orlo_logo_1024_transparent.png',
                          key: const ValueKey('boot-brand-logo'),
                          height: 128,
                          width: 220,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox(height: 72),
                        ),
                        if (phase.index >=
                            _BootVisualPhase.identityTyping.index) ...[
                          const SizedBox(height: 16),
                          Text(
                            'O.R.L.O.'.substring(0, widget.typedLength),
                            key: const ValueKey('boot-brand-identity'),
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  color: colorScheme.primary,
                                  fontFamily: 'monospace',
                                  letterSpacing: 2,
                                ),
                          ),
                        ],
                        if (phase.index >= _BootVisualPhase.identityName.index)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _fullName.substring(0, widget.typedNameLength),
                                key: const ValueKey('boot-brand-full-name'),
                                style: Theme.of(context).textTheme.labelSmall!
                                    .copyWith(
                                      color: colorScheme.primary.withValues(
                                        alpha: .7,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        if (phase == _BootVisualPhase.identityTyping)
                          FadeTransition(
                            opacity: _cursorController,
                            child: Text(
                              '▌',
                              key: const ValueKey('boot-typing-cursor'),
                              style: TextStyle(color: colorScheme.primary),
                            ),
                          ),
                        if (phase.index >=
                            _BootVisualPhase.systemBoot.index) ...[
                          const SizedBox(height: 16),
                          const Text('SYSTEM BOOT'),
                          const SizedBox(height: 8),
                          _BootProgressBar(value: widget.progress),
                        ],
                        if (rows.isNotEmpty) const SizedBox(height: 28),
                        ...rows,
                        if (hasActiveRow) const SizedBox(height: 8),
                        if (phase == _BootVisualPhase.systemReady) ...[
                          const SizedBox(height: 28),
                          Text(
                            'SYSTEM READY',
                            key: const ValueKey('boot-system-ready'),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 12,
              child: Semantics(
                button: true,
                label: 'TAP TO SKIP',
                child: SizedBox(
                  height: 48,
                  child: TextButton(
                    key: const ValueKey('boot-tap-to-skip'),
                    onPressed: widget.onSkip,
                    child: Text(
                      'TAP TO SKIP',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary.withValues(alpha: .72),
                        fontFamily: 'monospace',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _spinnerCharacter {
    return switch ((_spinnerController.value * 4).floor().clamp(0, 3)) {
      0 => '/',
      1 => '|',
      2 => '\\',
      _ => '-',
    };
  }

  bool _isInitializing(_BootVisualPhase phase) =>
      phase == _BootVisualPhase.coreInitializing ||
      phase == _BootVisualPhase.dataInitializing ||
      phase == _BootVisualPhase.operationInitializing;
}

class _BootStatusLine extends StatelessWidget {
  final String label;
  final bool initializing;
  final String spinner;

  const _BootStatusLine({
    super.key,
    required this.label,
    required this.initializing,
    required this.spinner,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        initializing ? 'INITIALIZING $spinner' : 'OK',
        style: TextStyle(
          color: initializing
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _BootProgressBar extends StatelessWidget {
  const _BootProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Boot progress',
      value: '${(value * 100).round()}%',
      child: Container(
        key: const ValueKey('boot-progress-bar'),
        height: 10,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: .45)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                key: const ValueKey('boot-progress-track'),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: constraints.maxWidth * value.clamp(0, 1),
                child: DecoratedBox(
                  key: const ValueKey('boot-progress-fill'),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .95),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootSignalHandoff extends StatefulWidget {
  const _BootSignalHandoff();

  @override
  State<_BootSignalHandoff> createState() => _BootSignalHandoffState();
}

class _BootSignalHandoffState extends State<_BootSignalHandoff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _bootSignalHandoffDuration,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('boot-signal-handoff'),
    color: Colors.black,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => CustomPaint(
        key: const ValueKey('boot-signal-sync-sweep'),
        painter: BootSignalHandoffPainter(_controller.value),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class BootSignalHandoffPainter extends CustomPainter {
  const BootSignalHandoffPainter(this.frame);
  final double frame;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * frame;
    final core = Paint()..color = bootSignalCoreColor;
    final halo = Paint()..color = bootSignalHaloColor;
    canvas.drawRect(Rect.fromLTWH(0, y - 2, size.width, 5), halo);
    canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.5), core);

    // A few short fragments immediately trail the sync line. They establish
    // motion without turning the entire frame into static or placeholder bars.
    final fragments = Paint()..color = bootSignalFragmentColor;
    for (var index = 0; index < 3; index += 1) {
      final start =
          (size.width * (.12 + index * .27) + frame * 43) % size.width;
      final width = size.width * (.08 + index * .025);
      canvas.drawRect(
        Rect.fromLTWH(start, y + 4 + index * 2, width, 1),
        fragments,
      );
    }
  }

  @override
  bool shouldRepaint(BootSignalHandoffPainter oldDelegate) =>
      oldDelegate.frame != frame;
}

/// Coordinates the visual without owning initialization or persistence.
class BootSequenceGate extends StatefulWidget {
  final ValueListenable<AppInitializationState> initialization;
  final Widget child;
  final Widget Function(AppInitializationState state) fallbackBuilder;
  final BootSequenceTiming timing;
  final BootSequenceEventListener? onEvent;
  final bool isInitialBootPresentation;
  final BootStartupTraceListener? onTrace;
  final VoidCallback? onPresentationReleased;

  /// Reserved for a future explicit audio experience. Boot currently does not
  /// invoke audio playback.
  final BootAudio? bootAudio;

  const BootSequenceGate({
    super.key,
    required this.initialization,
    required this.child,
    required this.fallbackBuilder,
    this.timing = const BootSequenceTiming(),
    this.onEvent,
    this.isInitialBootPresentation = true,
    this.onTrace,
    this.onPresentationReleased,
    this.bootAudio,
  });

  @override
  State<BootSequenceGate> createState() => _BootSequenceGateState();
}

class _BootSequenceGateState extends State<BootSequenceGate>
    with SingleTickerProviderStateMixin {
  Timer? _timelineTimer;
  late final AnimationController _progressController;
  int _session = 0;
  bool _systemInitialized = false;
  bool _visualRowsComplete = false;
  bool _finalProgressStarted = false;
  bool _readyDelayElapsed = false;
  bool _skipRequested = false;
  bool _presentationReleased = false;
  String? _lastDiagnosticPresentation;
  BootPresentationState _presentation =
      BootPresentationState.initialBootPresentation;
  int _typedLength = 0;
  int _typedNameLength = 0;
  _BootVisualPhase _phase = _BootVisualPhase.logo;

  @override
  void initState() {
    super.initState();
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_GATE_INIT',
      presentation: widget.isInitialBootPresentation ? 'BOOT' : 'INITIALIZING',
      fields: {
        'bootGate': identityHashCode(this),
        'initialBootPresentation': widget.isInitialBootPresentation,
      },
    );
    _progressController = AnimationController(vsync: this);
    widget.initialization.addListener(_onInitializationChanged);
    if (!widget.isInitialBootPresentation) {
      _transition(
        BootPresentationState.reinitializationLoading,
        'gate_created_after_initial_boot_claim',
      );
      return;
    }
    _emit(BootSequenceEventType.bootStart);
    _trace('boot_gate_created');
    _onInitializationChanged();
    _schedule(widget.timing.logoIntro, _startIdentityTyping);
  }

  @override
  void dispose() {
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_GATE_DISPOSE',
      presentation: _diagnosticPresentation,
      fields: {'presentationReleased': _presentationReleased},
    );
    widget.initialization.removeListener(_onInitializationChanged);
    _invalidateSession('gate_disposed');
    _progressController.dispose();
    super.dispose();
  }

  void _schedule(Duration duration, VoidCallback action) {
    _timelineTimer?.cancel();
    final scheduledSession = _session;
    _timelineTimer = Timer(duration, () {
      if (!mounted || scheduledSession != _session) {
        _trace('obsolete_callback_ignored');
        return;
      }
      action();
    });
  }

  void _invalidateSession(String event) {
    _timelineTimer?.cancel();
    _timelineTimer = null;
    _progressController.stop();
    _session += 1;
    _trace(event);
  }

  bool get _isPresentationActive =>
      widget.isInitialBootPresentation &&
      (_presentation == BootPresentationState.initialBootPresentation ||
          _presentation == BootPresentationState.systemReadyPresentation);

  bool get _isInitializationReady {
    final mode = widget.initialization.value.mode;
    return mode != PersistenceMode.initializing &&
        mode != PersistenceMode.failed;
  }

  void _startIdentityTyping() {
    if (!_isPresentationActive) return;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_PHASE_TYPING',
      presentation: 'BOOT',
    );
    setState(() => _phase = _BootVisualPhase.identityTyping);
    _animateProgressTo(.2, const Duration(milliseconds: 1500));
    _typeNextCharacter();
  }

  void _typeNextCharacter() {
    if (!_isPresentationActive) return;
    const identity = 'O.R.L.O.';
    if (_typedLength >= identity.length) {
      setState(() => _phase = _BootVisualPhase.identityName);
      _typeNextNameCharacter();
      return;
    }
    _schedule(_identityCharacterDelay(_typedLength), () {
      setState(() => _typedLength += 1);
      _typeNextCharacter();
    });
  }

  Duration _identityCharacterDelay(int index) {
    // Compact injected timings keep controlled widget tests fast.
    if (widget.timing.typingCharacter <= const Duration(milliseconds: 100)) {
      return widget.timing.typingCharacter;
    }
    return const [
      Duration(milliseconds: 260),
      Duration(milliseconds: 230),
      Duration(milliseconds: 210),
      Duration(milliseconds: 190),
      Duration(milliseconds: 170),
      Duration(milliseconds: 150),
      Duration(milliseconds: 140),
      Duration(milliseconds: 130),
    ][index.clamp(0, 7)];
  }

  void _typeNextNameCharacter() {
    if (!_isPresentationActive) return;
    if (widget.timing.fullNameCharacter <= const Duration(milliseconds: 10)) {
      setState(() => _typedNameLength = _fullName.length);
      _schedule(widget.timing.identityHold, _showSystemBoot);
      return;
    }
    if (_typedNameLength >= _fullName.length) {
      _schedule(widget.timing.identityHold, _showSystemBoot);
      return;
    }
    _schedule(widget.timing.fullNameCharacter, () {
      setState(() => _typedNameLength += 1);
      _typeNextNameCharacter();
    });
  }

  void _showSystemBoot() {
    if (!_isPresentationActive) return;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_PHASE_PROGRESS',
      presentation: 'BOOT',
    );
    setState(() => _phase = _BootVisualPhase.systemBoot);
    _animateProgressTo(.25, widget.timing.systemBootTransition);
    _schedule(widget.timing.systemBootTransition, _showCore);
  }

  void _showCore() {
    if (!_isPresentationActive) return;
    setState(() => _phase = _BootVisualPhase.coreInitializing);
    final coreDuration = widget.timing.row * 2;
    _animateProgressTo(.45, coreDuration);
    _schedule(coreDuration, _showData);
  }

  void _showData() {
    if (!_isPresentationActive) return;
    setState(() => _phase = _BootVisualPhase.dataInitializing);
    _animateProgressTo(.65, widget.timing.row);
    _schedule(widget.timing.row, _showOperation);
  }

  void _showOperation() {
    if (!_isPresentationActive) return;
    setState(() => _phase = _BootVisualPhase.operationInitializing);
    _animateProgressTo(.95, widget.timing.row);
    _schedule(widget.timing.row, _finishRows);
  }

  void _finishRows() {
    if (!_isPresentationActive) return;
    setState(() => _phase = _BootVisualPhase.waitingForInitialization);
    _visualRowsComplete = true;
    _tryStartFinalProgress();
  }

  void _tryStartFinalProgress() {
    if (!_isPresentationActive ||
        !_visualRowsComplete ||
        !_systemInitialized ||
        _finalProgressStarted) {
      return;
    }
    _finalProgressStarted = true;
    setState(() => _phase = _BootVisualPhase.finalizing);
    _animateProgressTo(1, widget.timing.readyDelay);
    _schedule(widget.timing.readyDelay + const Duration(milliseconds: 1), () {
      _readyDelayElapsed = true;
      _tryShowSystemReady();
    });
  }

  void _animateProgressTo(double target, Duration duration) {
    _progressController.animateTo(target, duration: duration);
  }

  void _onInitializationChanged() {
    final state = widget.initialization.value;
    _trace('initialization_changed');
    if (!widget.isInitialBootPresentation) return;
    if (state.mode == PersistenceMode.failed) {
      _invalidateSession('initialization_failed');
      _transition(BootPresentationState.failure, 'initialization_failed');
      if (mounted) {
        setState(() {});
      }
      _releasePresentation('failure_presentation_released');
      return;
    }
    if (state.mode == PersistenceMode.initializing) {
      if (_systemInitialized ||
          _presentation == BootPresentationState.bootHandoffSignal ||
          _presentation == BootPresentationState.mainUi) {
        _invalidateSession('reinitialization_begins');
        _transition(
          BootPresentationState.reinitializationLoading,
          'initialization_returned_to_loading',
        );
        if (mounted) setState(() {});
        _releasePresentation('reinitialization_presentation_released');
      }
      return;
    }
    if (_presentation == BootPresentationState.reinitializationLoading) {
      _transition(BootPresentationState.mainUi, 'reinitialization_ready');
      if (mounted) setState(() {});
      return;
    }
    if (_systemInitialized) {
      if (mounted && _presentation == BootPresentationState.mainUi) {
        setState(() {});
      }
      return;
    }
    _systemInitialized = true;
    _emit(BootSequenceEventType.systemInitialized);
    _tryStartFinalProgress();
  }

  void _tryShowSystemReady() {
    if (!_isPresentationActive ||
        !_systemInitialized ||
        !_readyDelayElapsed ||
        _phase != _BootVisualPhase.finalizing) {
      return;
    }
    setState(() => _phase = _BootVisualPhase.systemReady);
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_PHASE_SYSTEM_READY',
      presentation: 'BOOT',
    );
    _transition(BootPresentationState.systemReadyPresentation, 'system_ready');
    _schedule(widget.timing.readyHold, () {
      if (!_isPresentationActive || _skipRequested) return;
      _transition(
        BootPresentationState.bootHandoffSignal,
        'signal_handoff_started',
      );
      StartupDiagnostic.instance.record(
        'FLUTTER',
        'BOOT_PHASE_HANDOFF',
        presentation: 'BOOT',
      );
      setState(() {});
      _schedule(_bootSignalHandoffDuration, () {
        if (_presentation != BootPresentationState.bootHandoffSignal) return;
        _transition(BootPresentationState.mainUi, 'signal_handoff_finished');
        StartupDiagnostic.instance.record(
          'FLUTTER',
          'BOOT_PHASE_MAIN_UI',
          presentation: 'MAIN_UI',
        );
        setState(() {});
        _emit(BootSequenceEventType.bootComplete);
        _releasePresentation('normal_boot_presentation_released');
      });
    });
  }

  void _requestSkip() {
    if (!_isPresentationActive || _skipRequested) return;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_SKIP_TAPPED',
      presentation: 'BOOT',
    );
    _skipRequested = true;
    _invalidateSession('boot_skip_requested');
    if (widget.initialization.value.mode == PersistenceMode.failed) {
      StartupDiagnostic.instance.record(
        'FLUTTER',
        'BOOT_SKIP_TARGET_FAILURE',
        presentation: 'FAILURE',
      );
      _transition(BootPresentationState.failure, 'skip_after_failure');
    } else if (_isInitializationReady) {
      StartupDiagnostic.instance.record(
        'FLUTTER',
        'BOOT_SKIP_TARGET_MAIN',
        presentation: 'MAIN_UI',
      );
      _transition(
        BootPresentationState.mainUi,
        'skip_with_initialization_ready',
      );
    } else {
      StartupDiagnostic.instance.record(
        'FLUTTER',
        'BOOT_SKIP_TARGET_INITIALIZING',
        presentation: 'INITIALIZING',
      );
      _transition(
        BootPresentationState.reinitializationLoading,
        'skip_waiting_for_initialization',
      );
    }
    if (mounted) setState(() {});
    _releasePresentation('skip_presentation_released');
  }

  void _releasePresentation(String event) {
    if (_presentationReleased) return;
    _presentationReleased = true;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_GATE_RELEASE_REQUEST',
      presentation: _diagnosticPresentation,
      fields: {'reason': event},
    );
    _trace(event);
    widget.onPresentationReleased?.call();
  }

  void _transition(BootPresentationState next, String event) {
    final previous = _presentation;
    _presentation = next;
    _trace(event, previous: previous);
  }

  void _trace(String event, {BootPresentationState? previous}) {
    final trace = BootStartupTraceEvent(
      occurredAt: DateTime.now(),
      event: event,
      previousState: previous ?? _presentation,
      nextState: _presentation,
      initializationMode: widget.initialization.value.mode,
      visualPhase: _phase.name,
      session: _session,
    );
    widget.onTrace?.call(trace);
    assert(() {
      debugPrint(trace.toString());
      return true;
    }());
  }

  void _emit(BootSequenceEventType type) {
    try {
      widget.onEvent?.call(
        BootSequenceEvent(type: type, occurredAt: DateTime.now()),
      );
    } catch (_) {
      // Future audio hooks must never block access to the application.
    }
  }

  @override
  Widget build(BuildContext context) {
    _recordDiagnosticBuild();
    final state = widget.initialization.value;
    if (state.mode == PersistenceMode.failed) {
      return widget.fallbackBuilder(state);
    }
    if (!widget.isInitialBootPresentation) {
      return ValueListenableBuilder<AppInitializationState>(
        valueListenable: widget.initialization,
        builder: (context, loadingState, _) =>
            widget.fallbackBuilder(loadingState),
      );
    }
    if (_presentation == BootPresentationState.reinitializationLoading) {
      return widget.fallbackBuilder(state);
    }
    if (_presentation == BootPresentationState.mainUi) return widget.child;
    if (_presentation == BootPresentationState.bootHandoffSignal) {
      return const _BootSignalHandoff();
    }
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) => _BootSequenceVisual(
        phase: _phase,
        typedLength: _typedLength,
        typedNameLength: _typedNameLength,
        progress: _progressController.value,
        onSkip: _requestSkip,
      ),
    );
  }

  String get _diagnosticPresentation => switch (_presentation) {
    BootPresentationState.reinitializationLoading => 'INITIALIZING',
    BootPresentationState.mainUi => 'MAIN_UI',
    BootPresentationState.failure => 'FAILURE',
    _ => 'BOOT',
  };

  void _recordDiagnosticBuild() {
    final presentation = _diagnosticPresentation;
    if (_lastDiagnosticPresentation == presentation) return;
    _lastDiagnosticPresentation = presentation;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_GATE_BUILD',
      state: widget.initialization.value.mode.name,
      presentation: presentation,
      fields: {
        'bootPresentationState': _presentation.name,
        'phase': _phase.name,
      },
    );
  }
}
