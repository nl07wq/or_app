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

/// A small deterministic visual timeline. It does not represent persistence
/// work and remains independent from the real initialization state.
class BootSequenceTiming {
  final Duration logoIntro;
  final Duration typingCharacter;
  final Duration systemBootTransition;
  final Duration header;
  final Duration row;
  final Duration readyDelay;
  final Duration readyHold;

  const BootSequenceTiming({
    this.logoIntro = const Duration(milliseconds: 360),
    this.typingCharacter = const Duration(milliseconds: 90),
    this.systemBootTransition = const Duration(milliseconds: 180),
    this.header = const Duration(milliseconds: 180),
    this.row = const Duration(milliseconds: 320),
    this.readyDelay = const Duration(milliseconds: 180),
    this.readyHold = const Duration(milliseconds: 500),
  });
}

enum _BootVisualPhase {
  logo,
  identityTyping,
  systemBoot,
  coreInitializing,
  dataInitializing,
  operationInitializing,
  waitingForInitialization,
  systemReady,
}

class _BootSequenceVisual extends StatefulWidget {
  final _BootVisualPhase phase;
  final int typedLength;

  const _BootSequenceVisual({required this.phase, required this.typedLength});

  @override
  State<_BootSequenceVisual> createState() => _BootSequenceVisualState();
}

class _BootSequenceVisualState extends State<_BootSequenceVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final phase = widget.phase;
    final rows = <Widget>[
      if (phase.index >= _BootVisualPhase.coreInitializing.index)
        _BootStatusLine(
          key: const ValueKey('boot-row-core'),
          label: 'CORE SYSTEM',
          initializing: phase == _BootVisualPhase.coreInitializing,
        ),
      if (phase.index >= _BootVisualPhase.dataInitializing.index)
        _BootStatusLine(
          key: const ValueKey('boot-row-data'),
          label: 'DATA INITIALIZATION',
          initializing: phase == _BootVisualPhase.dataInitializing,
        ),
      if (phase.index >= _BootVisualPhase.operationInitializing.index)
        _BootStatusLine(
          key: const ValueKey('boot-row-operation'),
          label: 'OPERATION DATA',
          initializing: phase == _BootVisualPhase.operationInitializing,
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
                      'assets/icons/orlo_icon.png',
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
                      const SizedBox(height: 8),
                      const Text('SYSTEM BOOT'),
                    ],
                    if (rows.isNotEmpty) const SizedBox(height: 28),
                    ...rows,
                    if (hasActiveRow) const SizedBox(height: 8),
                    if (hasActiveRow)
                      FadeTransition(
                        opacity: _cursorController,
                        child: Text(
                          '▌',
                          key: const ValueKey('boot-active-cursor'),
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ),
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
}

class _BootStatusLine extends StatelessWidget {
  final String label;
  final bool initializing;

  const _BootStatusLine({
    super.key,
    required this.label,
    required this.initializing,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        initializing ? 'INITIALIZING' : 'OK',
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

class _BootSequenceGateState extends State<BootSequenceGate> {
  Timer? _timelineTimer;
  bool _systemInitialized = false;
  bool _readyDelayElapsed = false;
  bool _completed = false;
  int _typedLength = 0;
  _BootVisualPhase _phase = _BootVisualPhase.logo;

  @override
  void initState() {
    super.initState();
    _emit(BootSequenceEventType.bootStart);
    widget.initialization.addListener(_onInitializationChanged);
    _onInitializationChanged();
    _schedule(widget.timing.logoIntro, _startIdentityTyping);
  }

  @override
  void dispose() {
    widget.initialization.removeListener(_onInitializationChanged);
    _timelineTimer?.cancel();
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
    _typeNextCharacter();
  }

  void _typeNextCharacter() {
    const identity = 'O.R.L.O.';
    if (_typedLength >= identity.length) {
      setState(() => _phase = _BootVisualPhase.systemBoot);
      _schedule(widget.timing.systemBootTransition, _showCore);
      return;
    }
    _schedule(widget.timing.typingCharacter, () {
      setState(() => _typedLength += 1);
      _typeNextCharacter();
    });
  }

  void _showCore() {
    setState(() => _phase = _BootVisualPhase.coreInitializing);
    _schedule(widget.timing.row, _showData);
  }

  void _showData() {
    setState(() => _phase = _BootVisualPhase.dataInitializing);
    _schedule(widget.timing.row, _showOperation);
  }

  void _showOperation() {
    setState(() => _phase = _BootVisualPhase.operationInitializing);
    _schedule(widget.timing.row, _finishRows);
  }

  void _finishRows() {
    setState(() => _phase = _BootVisualPhase.waitingForInitialization);
    _schedule(widget.timing.readyDelay, () {
      _readyDelayElapsed = true;
      _tryShowSystemReady();
    });
  }

  void _onInitializationChanged() {
    final state = widget.initialization.value;
    if (state.mode == PersistenceMode.failed) {
      _timelineTimer?.cancel();
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
    _tryShowSystemReady();
  }

  void _tryShowSystemReady() {
    if (!_systemInitialized ||
        !_readyDelayElapsed ||
        _phase != _BootVisualPhase.waitingForInitialization) {
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
    return _BootSequenceVisual(phase: _phase, typedLength: _typedLength);
  }
}
