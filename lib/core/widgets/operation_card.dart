import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class OperationCard extends StatefulWidget {
  final Widget child;

  final VoidCallback? onTap;

  final bool selectable;

  const OperationCard({
    super.key,
    required this.child,
    this.onTap,
    this.selectable = false,
  });

  @override
  State<OperationCard> createState() => _OperationCardState();
}

class _OperationCardState extends State<OperationCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.selectable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Card(
        margin: AppSpacing.cardMargin,
        elevation: 6,
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.large,
          side: BorderSide(
            color: widget.selectable && _hovering
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.20)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadius.large,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: AppRadius.large,
              color: widget.selectable && _hovering
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.04)
                  : Colors.transparent,
            ),
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
