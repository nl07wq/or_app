import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../themes/base_camp/base_camp_presentation.dart';
import '../../themes/base_camp/base_camp_retro_terminal.dart';
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
    final baseCamp = BaseCampPresentation.isActive(context);
    final showAmbient = !baseCamp;
    final appBarHeight =
        appBar.preferredSize.height + MediaQuery.paddingOf(context).top;
    final base = Theme.of(context);
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (showAmbient)
            const RepaintBoundary(child: FoodAmbientComparison()),
          Padding(
            padding: EdgeInsets.only(top: appBarHeight),
            child: baseCamp
                ? BaseCampTerminalDisplay(
                    margin: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: body,
                  )
                : body,
          ),
        ],
      ),
    );
    if (baseCamp) {
      return BaseCampRetroTerminalScreen(
        screenKey: 'food-feature',
        child: scaffold,
      );
    }
    return Theme(
      data: base.copyWith(
        extensions: <ThemeExtension<dynamic>>[
          OperationSurfaceTheme(
            useDashboardGlass: !baseCamp,
            useClassicTerminal: baseCamp,
          ),
        ],
      ),
      child: scaffold,
    );
  }
}

PreferredSizeWidget foodFeatureAppBar({
  required String title,
  Widget? leading,
  List<Widget>? actions,
  FoodVfdScaleDisplayMode mode = FoodVfdScaleDisplayMode.normal,
  bool automaticallyImplyLeading = false,
}) => _FoodFeatureAppBar(
  title: title,
  leading: leading,
  actions: actions,
  mode: mode,
  automaticallyImplyLeading: automaticallyImplyLeading,
);

class _FoodFeatureAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _FoodFeatureAppBar({
    required this.title,
    required this.leading,
    required this.actions,
    required this.mode,
    required this.automaticallyImplyLeading,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final FoodVfdScaleDisplayMode mode;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final baseCamp = BaseCampPresentation.isActive(context);
    return AppBar(
      centerTitle: true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      actions: actions,
      backgroundColor: baseCamp ? null : const Color(0xCC0D1219),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      title: baseCamp
          ? Text(title)
          : FoodVfdScaleDisplayTitle(label: title, mode: mode),
    );
  }
}
