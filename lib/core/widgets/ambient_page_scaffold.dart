import 'package:flutter/material.dart';

/// Keeps a feature ambient behind the complete route, including a transparent
/// AppBar, without changing the route's foreground interaction tree.
class AmbientPageScaffold extends StatelessWidget {
  const AmbientPageScaffold({
    super.key,
    required this.appBar,
    required this.ambient,
    required this.body,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget appBar;
  final Widget ambient;
  final Widget body;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) => Scaffold(
    // The route material must not paint over the ambient before the
    // transparent AppBar is composited. Keeping the field inside the
    // Scaffold's extended body gives the header and content one continuous
    // render surface rather than compositing an external background beneath
    // platform-specific Scaffold/AppBar layers.
    backgroundColor: Colors.transparent,
    extendBodyBehindAppBar: true,
    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    appBar: appBar,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: ExcludeSemantics(child: ambient)),
        body,
      ],
    ),
  );
}
