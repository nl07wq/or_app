import 'dart:async';

import 'package:flutter/material.dart';

import '../services/startup_initialization_service.dart';
import '../services/font_readiness_service.dart';
import '../services/startup_diagnostic.dart';
import '../state/app_initialization_state.dart';
import 'boot_sequence.dart';
import 'operation_button.dart';
import 'loading/or_loading_surface.dart';
import 'loading/or_loading_tokens.dart';

class StartupGate extends StatefulWidget {
  final StartupInitializationService service;
  final Widget child;
  final bool showBootSequence;
  final BootSequenceEventListener? onBootEvent;
  final BootStartupTraceListener? onBootTrace;
  final BootSequenceTiming bootSequenceTiming;

  const StartupGate({
    super.key,
    required this.service,
    required this.child,
    this.showBootSequence = false,
    this.onBootEvent,
    this.onBootTrace,
    this.bootSequenceTiming = const BootSequenceTiming(),
  });

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final bool _isInitialBootPresentation;
  late bool _bootPresentationMounted;
  bool _allowFontFallback = false;
  String? _lastDiagnosticPresentation;

  @override
  void initState() {
    super.initState();
    final diagnostic = StartupDiagnostic.instance;
    diagnostic.record(
      'FLUTTER',
      'STARTUP_GATE_INIT',
      state: widget.service.controller.value.mode.name,
      fields: {
        'startupGate': identityHashCode(this),
        'controller': identityHashCode(widget.service.controller),
        'bootSessionClaim': diagnostic.bootSessionClaim(),
      },
    );
    _isInitialBootPresentation =
        widget.showBootSequence &&
        widget.service.controller.claimInitialBootPresentation();
    _bootPresentationMounted = _isInitialBootPresentation;
    diagnostic.record(
      'STARTUP_GATE',
      'STARTUP_GATE_INITIAL_CLAIM',
      presentation: _bootPresentationMounted ? 'BOOT' : 'INITIALIZING',
      fields: {
        'initialBootClaimed': _isInitialBootPresentation,
        'reason': widget.service.controller.initialBootClaimReason,
        'bootSessionClaim': diagnostic.bootSessionClaim(),
      },
    );
    diagnostic.record(
      'STARTUP_GATE',
      'BOOT_PRESENTATION_DECISION',
      presentation: _bootPresentationMounted ? 'BOOT' : 'INITIALIZING',
      fields: {
        'allowed': _isInitialBootPresentation,
        'reason': widget.service.controller.initialBootClaimReason,
      },
    );
  }

  @override
  void dispose() {
    StartupDiagnostic.instance.record('FLUTTER', 'STARTUP_GATE_DISPOSE');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _recordPresentation(
      _bootPresentationMounted
          ? 'BOOT'
          : _presentationFor(widget.service.controller.value),
    );
    assert(() {
      debugPrint(
        'STARTUP_TRACE event=startup_gate_build '
        'controller=${identityHashCode(widget.service.controller)} '
        'initialBoot=$_isInitialBootPresentation '
        'state=${widget.service.controller.value.mode.name}',
      );
      return true;
    }());
    // Startup owns the functional presentation.  Boot is an explicitly
    // temporary presentation child: once it releases, it is disposed rather
    // than being retained as a possible loading fallback.
    if (_bootPresentationMounted) {
      return BootSequenceGate(
        initialization: widget.service.controller,
        isInitialBootPresentation: _isInitialBootPresentation,
        fallbackBuilder: (state) => _stateChild(context, state),
        onPresentationReleased: _releaseBootPresentation,
        onEvent: widget.onBootEvent,
        onTrace: widget.onBootTrace,
        timing: widget.bootSequenceTiming,
        child: ValueListenableBuilder<AppInitializationState>(
          valueListenable: widget.service.controller,
          builder: (context, state, _) => _stateChild(context, state),
        ),
      );
    }
    return _canonicalStartupPresentation();
  }

  void _releaseBootPresentation() {
    if (!mounted || !_bootPresentationMounted) return;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'STARTUP_GATE_BOOT_RELEASED',
      presentation: _presentationFor(widget.service.controller.value),
    );
    setState(() => _bootPresentationMounted = false);
  }

  String _presentationFor(AppInitializationState state) => switch (state.mode) {
    PersistenceMode.initializing => 'INITIALIZING',
    PersistenceMode.failed => 'FAILURE',
    PersistenceMode.maintenance => 'MAINTENANCE',
    PersistenceMode.legacyReadOnly => 'READ_ONLY',
    PersistenceMode.indexedDbReadWrite => 'MAIN_UI',
  };

  void _recordPresentation(String presentation) {
    if (_lastDiagnosticPresentation == presentation) return;
    _lastDiagnosticPresentation = presentation;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'STARTUP_GATE_PRESENTATION_SELECTED',
      state: widget.service.controller.value.mode.name,
      presentation: presentation,
    );
    if (presentation == 'INITIALIZING') {
      StartupDiagnostic.instance.record(
        'FLUTTER',
        'INITIALIZING_BUILD',
        presentation: presentation,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastDiagnosticPresentation != 'INITIALIZING') return;
        StartupDiagnostic.instance.record(
          'FLUTTER',
          'INITIALIZING_POST_FRAME',
          presentation: 'INITIALIZING',
        );
      });
    }
  }

  Widget _canonicalStartupPresentation() =>
      ValueListenableBuilder<AppInitializationState>(
        valueListenable: widget.service.controller,
        builder: (context, state, _) => _stateChild(context, state),
      );

  Widget _stateChild(BuildContext context, AppInitializationState state) {
    _recordPresentation(_presentationFor(state));
    return switch (state.mode) {
      PersistenceMode.initializing => _InitializingView(state: state),
      PersistenceMode.failed => _FailedView(
        state: state,
        onRetry: widget.service.retry,
        onReadOnly: widget.service.openReadOnly,
      ),
      PersistenceMode.legacyReadOnly => _ReadOnlyShell(
        state: state,
        child: widget.child,
      ),
      PersistenceMode.maintenance => _MaintenanceView(child: widget.child),
      PersistenceMode.indexedDbReadWrite => _fontReadyChild(),
    };
  }

  Widget _fontReadyChild() => AnimatedBuilder(
    animation: FontReadinessService.instance,
    builder: (context, _) {
      final readiness = FontReadinessService.instance;
      if (readiness.isReady || _allowFontFallback) return widget.child;
      if (readiness.state == FontReadinessState.failed) {
        return OrLoadingSurface(
          scope: OrLoadingScope.fullscreen,
          title: 'FONT INITIALIZATION FAILED',
          subtitle: 'Japanese text resources could not be prepared.',
          state: OrLoadingPhase.failed,
          onRetry: () => unawaited(readiness.retry()),
          child: TextButton(
            onPressed: () => setState(() => _allowFontFallback = true),
            child: const Text('CONTINUE WITH SYSTEM FONT'),
          ),
        );
      }
      return const OrLoadingSurface(
        key: ValueKey('font-readiness-loading'),
        scope: OrLoadingScope.fullscreen,
        title: 'INITIALIZING',
        subtitle: 'Preparing application resources',
      );
    },
  );
}

class _MaintenanceView extends StatelessWidget {
  final Widget child;

  const _MaintenanceView({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const ModalBarrier(dismissible: false, color: Colors.black54),
        Center(
          child: Material(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const OrLoadingSurface(
                    title: 'RESTORING BACKUP',
                    subtitle: 'Do not close this window.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InitializingView extends StatelessWidget {
  final AppInitializationState state;

  const _InitializingView({required this.state});

  @override
  Widget build(BuildContext context) {
    return OrLoadingSurface(
      key: const ValueKey('startup-initializing-view'),
      scope: OrLoadingScope.fullscreen,
      title: 'INITIALIZING',
      subtitle: state.currentStage.name
          .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
          .trim()
          .toUpperCase(),
    );
  }
}

class _FailedView extends StatelessWidget {
  final AppInitializationState state;
  final Future<void> Function() onRetry;
  final Future<void> Function() onReadOnly;

  const _FailedView({
    required this.state,
    required this.onRetry,
    required this.onReadOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'DATA INITIALIZATION FAILED',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text('保存データの初期化に失敗しました。', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Error Code: ${state.errorCode ?? 'unknown'}',
                  textAlign: TextAlign.center,
                ),
                if (state.failedMigrationId != null)
                  Text(
                    'Migration: ${state.failedMigrationId}',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 24),
                OperationButton(
                  icon: Icons.refresh,
                  text: 'RETRY',
                  onPressed: onRetry,
                ),
                const SizedBox(height: 12),
                OperationButton(
                  icon: Icons.visibility_outlined,
                  text: 'OPEN READ ONLY',
                  onPressed: onReadOnly,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyShell extends StatelessWidget {
  final AppInitializationState state;
  final Widget child;

  const _ReadOnlyShell({required this.state, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  [
                    'READ ONLY\nRECOVERY MODE',
                    if (state.errorMessage != null) state.errorMessage!,
                  ].join('\n'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
