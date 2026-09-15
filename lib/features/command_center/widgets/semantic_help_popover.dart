import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

enum ContextPopoverEdge { left, right }

ContextPopoverEdge contextPopoverEdgeFor({
  required Rect triggerRect,
  required Size viewportSize,
}) => triggerRect.center.dx < viewportSize.width / 2
    ? ContextPopoverEdge.left
    : ContextPopoverEdge.right;

class SemanticHelpPopover extends StatefulWidget {
  const SemanticHelpPopover({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.child,
    this.secondary,
    this.descriptionColor,
    this.offset = Offset.zero,
    this.constraints = const BoxConstraints(minWidth: 220, maxWidth: 300),
    this.visibleAnchorKey,
  });

  final String id;
  final String title;
  final String description;
  final String? secondary;
  final Color? descriptionColor;
  final Offset offset;
  final BoxConstraints constraints;
  final GlobalKey? visibleAnchorKey;
  final Widget child;

  @override
  State<SemanticHelpPopover> createState() => _SemanticHelpPopoverState();
}

class _SemanticHelpPopoverState extends State<SemanticHelpPopover> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  void _dismiss() {
    _entry?.remove();
    _entry = null;
  }

  void _showContextualPopover() {
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final anchorBox =
        widget.visibleAnchorKey?.currentContext?.findRenderObject()
            as RenderBox?;
    if (overlayBox == null || anchorBox == null) return;

    final anchorTopLeft = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final anchorRect = anchorTopLeft & anchorBox.size;
    final overlaySize = overlayBox.size;
    final safeInset = AppSpacing.sm;
    final availableWidth = overlaySize.width - safeInset * 2;
    final popoverWidth = widget.constraints.minWidth
        .clamp(0.0, availableWidth)
        .toDouble();
    final edge = contextPopoverEdgeFor(
      triggerRect: anchorRect,
      viewportSize: overlaySize,
    );
    final popoverLeft = switch (edge) {
      ContextPopoverEdge.left => safeInset,
      ContextPopoverEdge.right => overlaySize.width - safeInset - popoverWidth,
    };

    _dismiss();
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
            ),
          ),
          Positioned(
            left: popoverLeft,
            top: anchorRect.bottom + widget.offset.dy,
            width: popoverWidth,
            child: Material(
              key: ValueKey('semantic-help-popover-${widget.id}'),
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _PopoverContent(
                  title: widget.title,
                  description: widget.description,
                  secondary: widget.secondary,
                  descriptionColor: widget.descriptionColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.visibleAnchorKey == null) {
      return PopupMenuButton<void>(
        key: ValueKey('semantic-help-anchor-${widget.id}'),
        tooltip: '${widget.title}の説明',
        position: PopupMenuPosition.under,
        offset: widget.offset,
        constraints: widget.constraints,
        itemBuilder: (context) => [
          PopupMenuItem<void>(
            key: ValueKey('semantic-help-popover-${widget.id}'),
            enabled: false,
            padding: const EdgeInsets.all(16),
            child: _PopoverContent(
              title: widget.title,
              description: widget.description,
              secondary: widget.secondary,
              descriptionColor: widget.descriptionColor,
            ),
          ),
        ],
        child: widget.child,
      );
    }

    return GestureDetector(
      key: ValueKey('semantic-help-anchor-${widget.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: _showContextualPopover,
      child: widget.child,
    );
  }
}

class _PopoverContent extends StatelessWidget {
  const _PopoverContent({
    required this.title,
    required this.description,
    this.secondary,
    this.descriptionColor,
  });

  final String title;
  final String description;
  final String? secondary;
  final Color? descriptionColor;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(description, style: TextStyle(color: descriptionColor)),
      if (secondary != null) ...[
        const SizedBox(height: 8),
        Text(secondary!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ],
  );
}
