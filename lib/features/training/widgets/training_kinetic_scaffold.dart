import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/loading/or_loading_surface.dart';
import '../../../core/widgets/loading/or_loading_tokens.dart';

import 'training_ambient_comparison.dart';

/// Keeps the KINETIC ENGINE in viewport coordinates while the route body
/// scrolls above it. The wrapper deliberately preserves Scaffold's normal
/// body origin so existing TRAINING layouts do not shift under the AppBar.
class TrainingKineticScaffold extends StatefulWidget {
  const TrainingKineticScaffold({super.key, this.appBar, required this.body});

  final PreferredSizeWidget? appBar;
  final Widget body;

  @override
  State<TrainingKineticScaffold> createState() =>
      _TrainingKineticScaffoldState();
}

class _TrainingKineticScaffoldState extends State<TrainingKineticScaffold> {
  var _backgroundReady = KineticBackgroundReadiness.isReady;
  var _backgroundFailed = false;
  var _preparationGeneration = 0;

  @override
  void initState() {
    super.initState();
    KineticFirstFrameInstrumentation.routeInit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_backgroundReady || _backgroundFailed) return;
    _prepareBackground();
  }

  Future<void> _prepareBackground() async {
    final generation = ++_preparationGeneration;
    try {
      await KineticBackgroundReadiness.prepare(context);
      if (!mounted || generation != _preparationGeneration) return;
      setState(() => _backgroundReady = true);
      KineticFirstFrameInstrumentation.routePresentedWithReadyBackground();
    } catch (_) {
      // The ambient's established synchronous fallback remains available for
      // a genuine asset failure; do not block route recovery indefinitely.
      if (!mounted || generation != _preparationGeneration) return;
      setState(() => _backgroundFailed = true);
    }
  }

  @override
  void dispose() {
    KineticFirstFrameInstrumentation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    KineticFirstFrameInstrumentation.firstScaffoldBuild();
    if (!_backgroundReady && !_backgroundFailed) {
      return const Scaffold(
        backgroundColor: Color(0xff030914),
        body: OrLoadingSurface(
          scope: OrLoadingScope.fullscreen,
          title: 'PREPARING KINETIC ENGINE',
          subtitle: 'Preparing training ambient resources',
        ),
      );
    }
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final inheritedTheme = Theme.of(context);
    return Theme(
      data: inheritedTheme.copyWith(
        extensions: [
          ...inheritedTheme.extensions.values,
          const OperationSurfaceTheme(useDashboardGlass: true),
        ],
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: inheritedTheme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: widget.appBar,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const TrainingAmbientComparison(
              variant: TrainingAmbientVariant.kineticEngine,
            ),
            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: widget.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
