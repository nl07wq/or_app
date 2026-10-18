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
