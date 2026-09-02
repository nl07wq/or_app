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
  final Duration header;
  final Duration row;
  final Duration readyDelay;
  final Duration readyHold;

  const BootSequenceTiming({
    this.header = const Duration(milliseconds: 180),
    this.row = const Duration(milliseconds: 220),
    this.readyDelay = const Duration(milliseconds: 180),
    this.readyHold = const Duration(milliseconds: 360),
  });
}

enum _BootVisualPhase {
  header,
  coreInitializing,
  dataInitializing,
  operationInitializing,
  waitingForInitialization,
  systemReady,
}

class _BootSequenceVisual extends StatefulWidget {
  final _BootVisualPhase phase;

  const _BootSequenceVisual({required this.phase});

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
      if (phase != _BootVisualPhase.header)
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
                    Text(
                      'OPERATION REBOOT',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: colorScheme.primary,
                        fontFamily: 'monospace',
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('SYSTEM BOOT'),
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
  _BootVisualPhase _phase = _BootVisualPhase.header;

  @override
  void initState() {
    super.initState();
    _emit(BootSequenceEventType.bootStart);
    widget.initialization.addListener(_onInitializationChanged);
    _onInitializationChanged();
    _schedule(widget.timing.header, _showCore);
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
    return _BootSequenceVisual(phase: _phase);
  }
}
