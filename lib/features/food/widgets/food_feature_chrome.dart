import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import 'food_ambient_comparison.dart';
import 'food_vfd_scale_display_title.dart';

/// Feature-local FOOD chrome. It keeps one shared Continuous Circulation
/// world behind each FOOD route while allowing each route to retain its
/// existing navigation and content composition.
class FoodFeatureScaffold extends StatelessWidget {
  const FoodFeatureScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.floatingActionButton,
  });

  final PreferredSizeWidget appBar;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final appBarHeight =
        appBar.preferredSize.height + MediaQuery.paddingOf(context).top;
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        extensions: const <ThemeExtension<dynamic>>[
          OperationSurfaceTheme(useDashboardGlass: true),
        ],
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(child: FoodAmbientComparison()),
            Padding(
              padding: EdgeInsets.only(top: appBarHeight),
              child: body,
            ),
          ],
        ),
      ),
    );
  }
}

AppBar foodFeatureAppBar({
  required String title,
  Widget? leading,
  List<Widget>? actions,
  FoodVfdScaleDisplayMode mode = FoodVfdScaleDisplayMode.normal,
  bool automaticallyImplyLeading = false,
}) => AppBar(
  centerTitle: true,
  automaticallyImplyLeading: automaticallyImplyLeading,
  leading: leading,
  actions: actions,
  backgroundColor: const Color(0xCC0D1219),
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  title: FoodVfdScaleDisplayTitle(label: title, mode: mode),
);
