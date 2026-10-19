import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'global_touch_ripple.dart';

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
    return MouseRegion(
      cursor: widget.selectable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Card(
        margin: widget.margin,
        elevation: widget.transparentSurface ? 0 : 6,
        color: widget.transparentSurface
            ? Colors.transparent
            : Theme.of(context).cardColor,
        shadowColor: widget.transparentSurface ? Colors.transparent : null,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: widget.selectable && _hovering
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.20)
                : Colors.transparent,
          ),
        ),
        child: widget.onTap == null
            ? _cardBody()
            : ActionableFeedbackButton(enabled: true, child: _cardBody()),
      ),
    );
  }

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
