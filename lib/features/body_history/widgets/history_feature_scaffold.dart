import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import 'history_data_vault_background.dart';
import 'history_memory_module_title.dart';

class HistoryFeatureScaffold extends StatefulWidget {
  const HistoryFeatureScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.actions,
  });
  final String title;
  final Widget body;
  final Widget? leading;
  final List<Widget>? actions;

  /// Test-only switch for deterministic widget tests. Production always uses
  /// the 36-second DATA VAULT cadence.
  static bool debugDisableAmbientAnimation = false;
  @override
  State<HistoryFeatureScaffold> createState() => _HistoryFeatureScaffoldState();
}

class _HistoryFeatureScaffoldState extends State<HistoryFeatureScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Stopwatch _clock = Stopwatch();
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    );
    if (!HistoryFeatureScaffold.debugDisableAmbientAnimation) {
      _controller.repeat();
    }
    _clock.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      extensions: [
        ...Theme.of(context).extensions.values,
        const OperationSurfaceTheme(useDashboardGlass: true),
      ],
      chipTheme: Theme.of(context).chipTheme.copyWith(
        backgroundColor: const Color(0xff14222f).withValues(alpha: .19),
        selectedColor: const Color(0xff3a526c).withValues(alpha: .48),
        side: BorderSide(color: const Color(0xff678ba7).withValues(alpha: .28)),
      ),
    ),
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          HistoryDataVaultBackground(
            seconds:
                _clock.elapsedMicroseconds / Duration.microsecondsPerSecond,
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: widget.leading,
              actions: widget.actions,
              title: HistoryMemoryModuleTitle(
                variant: HistoryTitleVariant.memoryModule,
                seconds:
                    _clock.elapsedMicroseconds / Duration.microsecondsPerSecond,
                label: widget.title,
              ),
            ),
            body: widget.body,
          ),
        ],
      ),
    ),
  );
}
