import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state/app_initialization_state.dart';

enum BootSequenceEventType { bootStart, systemInitialized, bootComplete }

class BootSequenceEvent {
  final BootSequenceEventType type;
  final DateTime occurredAt;

  const BootSequenceEvent({required this.type, required this.occurredAt});
}

typedef BootSequenceEventListener = void Function(BootSequenceEvent event);

const _fullName = 'Operation Reasoning Lifesystem Orchestrator';

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
    this.fullNameCharacter = const Duration(milliseconds: 40),
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

class _BootSequenceVisual extends StatefulWidget {
  final _BootVisualPhase phase;
  final int typedLength;
  final int typedNameLength;
  final double progress;

  const _BootSequenceVisual({
    required this.phase,
    required this.typedLength,
    required this.typedNameLength,
    required this.progress,
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
        child: Center(
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
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
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
                    if (phase.index >= _BootVisualPhase.systemBoot.index) ...[
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
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  key: const ValueKey('boot-progress-fill'),
                  width: constraints.maxWidth * value.clamp(0, 1),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .95),
                      borderRadius: BorderRadius.circular(2),
                    ),
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

/// Coordinates the visual without owning initialization or persistence.
class BootSequenceGate extends StatefulWidget {
  final ValueListenable<AppInitializationState> initialization;
  final Widget child;
  final Widget Function(AppInitializationState state) fallbackBuilder;
  final BootSequenceTiming timing;
  final BootSequenceEventListener? onEvent;

  const BootSequenceGate({
    super.key,
    required this.initialization,
    required this.child,
    required this.fallbackBuilder,
    this.timing = const BootSequenceTiming(),
    this.onEvent,
  });

  @override
  State<BootSequenceGate> createState() => _BootSequenceGateState();
}

class _BootSequenceGateState extends State<BootSequenceGate>
    with SingleTickerProviderStateMixin {
  Timer? _timelineTimer;
  late final AnimationController _progressController;
  bool _systemInitialized = false;
  bool _visualRowsComplete = false;
  bool _finalProgressStarted = false;
  bool _readyDelayElapsed = false;
  bool _completed = false;
  int _typedLength = 0;
  int _typedNameLength = 0;
  _BootVisualPhase _phase = _BootVisualPhase.logo;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this);
    _emit(BootSequenceEventType.bootStart);
    widget.initialization.addListener(_onInitializationChanged);
    _onInitializationChanged();
    _schedule(widget.timing.logoIntro, _startIdentityTyping);
  }

  @override
  void dispose() {
    widget.initialization.removeListener(_onInitializationChanged);
    _timelineTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _schedule(Duration duration, VoidCallback action) {
    _timelineTimer?.cancel();
    _timelineTimer = Timer(duration, () {
      if (mounted) {
        action();
      }
    });
  }

  void _startIdentityTyping() {
    setState(() => _phase = _BootVisualPhase.identityTyping);
    _animateProgressTo(.2, const Duration(milliseconds: 1500));
    _typeNextCharacter();
  }

  void _typeNextCharacter() {
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
    if (widget.timing.fullNameCharacter < const Duration(milliseconds: 20)) {
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
    setState(() => _phase = _BootVisualPhase.systemBoot);
    _animateProgressTo(.25, widget.timing.systemBootTransition);
    _schedule(widget.timing.systemBootTransition, _showCore);
  }

  void _showCore() {
    setState(() => _phase = _BootVisualPhase.coreInitializing);
    final coreDuration = widget.timing.row * 2;
    _animateProgressTo(.45, coreDuration);
    _schedule(coreDuration, _showData);
  }

  void _showData() {
    setState(() => _phase = _BootVisualPhase.dataInitializing);
    _animateProgressTo(.65, widget.timing.row);
    _schedule(widget.timing.row, _showOperation);
  }

  void _showOperation() {
    setState(() => _phase = _BootVisualPhase.operationInitializing);
    _animateProgressTo(.95, widget.timing.row);
    _schedule(widget.timing.row, _finishRows);
  }

  void _finishRows() {
    setState(() => _phase = _BootVisualPhase.waitingForInitialization);
    _visualRowsComplete = true;
    _tryStartFinalProgress();
  }

  void _tryStartFinalProgress() {
    if (!_visualRowsComplete || !_systemInitialized || _finalProgressStarted) {
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
    if (state.mode == PersistenceMode.failed) {
      _timelineTimer?.cancel();
      _progressController.stop();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (state.mode == PersistenceMode.initializing || _systemInitialized) {
      return;
    }
    _systemInitialized = true;
    _emit(BootSequenceEventType.systemInitialized);
    _tryStartFinalProgress();
  }

  void _tryShowSystemReady() {
    if (!_systemInitialized ||
        !_readyDelayElapsed ||
        _phase != _BootVisualPhase.finalizing) {
      return;
    }
    setState(() => _phase = _BootVisualPhase.systemReady);
    _schedule(widget.timing.readyHold, () {
      setState(() => _completed = true);
      _emit(BootSequenceEventType.bootComplete);
    });
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
    final state = widget.initialization.value;
    if (state.mode == PersistenceMode.failed) {
      return widget.fallbackBuilder(state);
    }
    if (_completed) return widget.child;
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) => _BootSequenceVisual(
        phase: _phase,
        typedLength: _typedLength,
        typedNameLength: _typedNameLength,
        progress: _progressController.value,
      ),
    );
  }
}
