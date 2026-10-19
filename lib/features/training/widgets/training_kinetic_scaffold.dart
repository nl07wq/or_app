import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';

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
  static const _backgroundImage = AssetImage(
    TrainingAmbientComparison.kineticEngineBackgroundAsset,
  );
  bool _didPrecache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    // Starts decoding before the first route transition that needs the image.
    // The painter remains visible while the browser finishes decoding it.
    precacheImage(_backgroundImage, context).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
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
