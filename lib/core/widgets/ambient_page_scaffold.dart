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
      // This must be outside Scaffold.body. On iOS, a body's layout region
      // can begin below the AppBar even when the AppBar itself is transparent.
      // Keeping the production ambient at route scope guarantees that the
      // status-bar, header, and content share one continuous field.
      Positioned.fill(child: ExcludeSemantics(child: ambient)),
      Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: appBar,
        body: body,
      ),
    ],
  );
}
