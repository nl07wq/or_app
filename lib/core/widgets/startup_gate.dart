import 'package:flutter/material.dart';

import '../services/startup_initialization_service.dart';
import '../state/app_initialization_state.dart';
import 'operation_button.dart';

class StartupGate extends StatelessWidget {
  final StartupInitializationService service;
  final Widget child;

  const StartupGate({super.key, required this.service, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppInitializationState>(
      valueListenable: service.controller,
      builder: (context, state, _) {
        return switch (state.mode) {
          PersistenceMode.initializing => _InitializingView(state: state),
          PersistenceMode.failed => _FailedView(
            state: state,
            onRetry: service.retry,
            onReadOnly: service.openReadOnly,
          ),
          PersistenceMode.legacyReadOnly => _ReadOnlyShell(
            state: state,
            child: child,
          ),
          PersistenceMode.maintenance => _MaintenanceView(child: child),
          PersistenceMode.indexedDbReadWrite => child,
        };
      },
    );
  }
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
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'RESTORING BACKUP',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Do not close this window.'),
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
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'INITIALIZING',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Operation Rebootのデータを準備しています。'),
              const SizedBox(height: 16),
              Text(
                state.currentStage.name
                    .replaceAllMapped(
                      RegExp(r'([A-Z])'),
                      (match) => ' ${match.group(1)}',
                    )
                    .trim()
                    .toUpperCase(),
              ),
            ],
          ),
        ),
      ),
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
