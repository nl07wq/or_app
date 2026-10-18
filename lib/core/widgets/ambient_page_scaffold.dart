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
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(child: ExcludeSemantics(child: ambient)),
      Scaffold(
        // The route material must not paint over the ambient before the
        // transparent AppBar is composited. Keeping it outside the Scaffold
        // also makes the status-bar and header share the same field.
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: appBar,
        body: body,
      ),
    ],
  );
}
