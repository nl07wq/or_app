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

/// Lightweight, presentation-only system boot visual.
///
/// Events are intentionally independent from playback so a future boot-sound
/// integration can synchronize without making startup depend on audio.
class BootSequenceVisual extends StatefulWidget {
  final InitializationStage stage;
  final bool systemInitialized;

  const BootSequenceVisual({
    super.key,
    required this.stage,
    required this.systemInitialized,
  });

  @override
  State<BootSequenceVisual> createState() => _BootSequenceVisualState();
}

class _BootSequenceVisualState extends State<BootSequenceVisual>
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
    final ready = widget.systemInitialized;
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
                    const SizedBox(height: 28),
                    _BootStatusLine(
                      label: 'CORE SYSTEM',
                      status: 'OK',
                      complete: true,
                    ),
                    _BootStatusLine(
                      label: 'DATA INITIALIZATION',
                      status: _stageLabel(widget.stage),
                      complete: ready,
                    ),
                    _BootStatusLine(
                      label: 'OPERATION DATA',
                      status: ready ? 'OK' : 'WAIT',
                      complete: ready,
                    ),
                    const SizedBox(height: 28),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Text(
                        ready ? 'SYSTEM READY' : 'INITIALIZING...',
                        key: ValueKey(ready),
                        style: TextStyle(
                          color: ready ? colorScheme.primary : Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FadeTransition(
                      opacity: _cursorController,
                      child: Text(
                        '▌',
                        style: TextStyle(color: colorScheme.primary),
                      ),
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

class _BootStatusLine extends StatelessWidget {
  final String label;
  final String status;
  final bool complete;

  const _BootStatusLine({
    required this.label,
    required this.status,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        status,
        style: TextStyle(
          color: complete
              ? Theme.of(context).colorScheme.primary
              : Colors.white70,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

String _stageLabel(InitializationStage stage) => switch (stage) {
  InitializationStage.openingDatabase => 'START',
  InitializationStage.upgradingSchema => 'CHECK',
  InitializationStage.checkingMigrations => 'CHECK',
  InitializationStage.restoringDailyState => 'RESTORE',
  InitializationStage.complete => 'OK',
  _ => 'WORKING',
};

/// Coordinates the visual without owning initialization or persistence.
class BootSequenceGate extends StatefulWidget {
  final ValueListenable<AppInitializationState> initialization;
  final Widget child;
  final Widget Function(AppInitializationState state) fallbackBuilder;
  final Duration minimumDisplayDuration;
  final BootSequenceEventListener? onEvent;

  const BootSequenceGate({
    super.key,
    required this.initialization,
    required this.child,
    required this.fallbackBuilder,
    this.minimumDisplayDuration = const Duration(milliseconds: 950),
    this.onEvent,
  });

  @override
  State<BootSequenceGate> createState() => _BootSequenceGateState();
}

class _BootSequenceGateState extends State<BootSequenceGate> {
  late final DateTime _startedAt;
  Timer? _completionTimer;
  bool _systemInitialized = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _emit(BootSequenceEventType.bootStart);
    widget.initialization.addListener(_onInitializationChanged);
    _onInitializationChanged();
  }

  @override
  void dispose() {
    widget.initialization.removeListener(_onInitializationChanged);
    _completionTimer?.cancel();
    super.dispose();
  }

  void _onInitializationChanged() {
    final state = widget.initialization.value;
    if (state.mode == PersistenceMode.failed) {
      _completionTimer?.cancel();
      return;
    }
    if (state.mode == PersistenceMode.initializing || _systemInitialized) {
      return;
    }
    _systemInitialized = true;
    _emit(BootSequenceEventType.systemInitialized);
    final elapsed = DateTime.now().difference(_startedAt);
    final remaining = widget.minimumDisplayDuration - elapsed;
    _completionTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        if (!mounted) {
          return;
        }
        setState(() => _completed = true);
        _emit(BootSequenceEventType.bootComplete);
      },
    );
    if (mounted) setState(() {});
  }

  void _emit(BootSequenceEventType type) {
    try {
      widget.onEvent?.call(
        BootSequenceEvent(type: type, occurredAt: DateTime.now()),
      );
    } catch (_) {
      // Audio/telemetry hooks must never block access to the application.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.initialization.value;
    if (state.mode == PersistenceMode.failed) {
      return widget.fallbackBuilder(state);
    }
    if (_completed) return widget.child;
    return BootSequenceVisual(
      stage: state.currentStage,
      systemInitialized: _systemInitialized,
    );
  }
}
