import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'global_touch_ripple.dart';

/// Opt-in material policy for a route family that uses the established
/// Dashboard glass surface. It intentionally changes no route unless that
/// route adds this extension to its local [Theme].
@immutable
class OperationSurfaceTheme extends ThemeExtension<OperationSurfaceTheme> {
  const OperationSurfaceTheme({this.useDashboardGlass = false});

  final bool useDashboardGlass;

  @override
  OperationSurfaceTheme copyWith({bool? useDashboardGlass}) =>
      OperationSurfaceTheme(
        useDashboardGlass: useDashboardGlass ?? this.useDashboardGlass,
      );

  @override
  OperationSurfaceTheme lerp(
    covariant ThemeExtension<OperationSurfaceTheme>? other,
    double t,
  ) => t < .5 ? this : (other as OperationSurfaceTheme? ?? this);
}

class OperationCard extends StatefulWidget {
  final Widget child;

  final VoidCallback? onTap;

  final bool selectable;

  final EdgeInsetsGeometry padding;

  final EdgeInsetsGeometry margin;

  final BorderRadius? borderRadius;

  /// Preserves this card's established spacing while letting an opt-in child
  /// blur the route ambient instead of an opaque intermediate surface.
  final bool transparentSurface;

  const OperationCard({
    super.key,
    required this.child,
    this.onTap,
    this.selectable = false,
    this.padding = AppSpacing.cardPadding,
    this.margin = AppSpacing.cardMargin,
    this.borderRadius,
    this.transparentSurface = false,
  });

  @override
  State<OperationCard> createState() => _OperationCardState();
}

class _OperationCardState extends State<OperationCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? AppRadius.large;
    final dashboardGlass =
        Theme.of(
          context,
        ).extension<OperationSurfaceTheme>()?.useDashboardGlass ??
        false;
    final cardBody = _cardBody();
    return MouseRegion(
      cursor: widget.selectable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Card(
        margin: widget.margin,
        elevation: widget.transparentSurface || dashboardGlass ? 0 : 6,
        color: widget.transparentSurface || dashboardGlass
            ? Colors.transparent
            : Theme.of(context).cardColor,
        shadowColor: widget.transparentSurface || dashboardGlass
            ? Colors.transparent
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: widget.selectable && _hovering
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.20)
                : Colors.transparent,
          ),
        ),
        child: dashboardGlass
            ? DecoratedBox(
                decoration: _dashboardReferenceDecoration(
                  Theme.of(context).colorScheme,
                  borderRadius,
                ),
                child: widget.onTap == null
                    ? cardBody
                    : ActionableFeedbackButton(enabled: true, child: cardBody),
              )
            : widget.onTap == null
            ? cardBody
            : ActionableFeedbackButton(enabled: true, child: cardBody),
      ),
    );
  }

  // Mirrors DashboardGlassCard.decoration without a circular widget import.
  // Keep this route-scoped use aligned with the accepted Dashboard material.
  static BoxDecoration _dashboardReferenceDecoration(
    ColorScheme scheme,
    BorderRadius borderRadius,
  ) => BoxDecoration(
    borderRadius: borderRadius,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        scheme.primary.withValues(alpha: .085),
        scheme.surface.withValues(alpha: .24),
        scheme.surfaceContainerHigh.withValues(alpha: .13),
      ],
    ),
    border: Border.all(color: scheme.primary.withValues(alpha: .16)),
    boxShadow: [
      BoxShadow(
        color: scheme.primary.withValues(alpha: .055),
        blurRadius: 18,
        offset: const Offset(-2, -2),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: .34),
        blurRadius: 18,
        offset: const Offset(4, 8),
      ),
    ],
  );

  Widget _cardBody() {
    final borderRadius = widget.borderRadius ?? AppRadius.large;
    return InkWell(
      borderRadius: borderRadius,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: widget.selectable && _hovering
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.04)
              : Colors.transparent,
        ),
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
  }
}
