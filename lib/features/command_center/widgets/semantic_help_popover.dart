import 'package:flutter/material.dart';

class SemanticHelpPopover extends StatelessWidget {
  const SemanticHelpPopover({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.child,
    this.secondary,
  });

  final String id;
  final String title;
  final String description;
  final String? secondary;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopupMenuButton<void>(
    key: ValueKey('semantic-help-anchor-$id'),
    tooltip: '$titleの説明',
    position: PopupMenuPosition.under,
    constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
    itemBuilder: (context) => [
      PopupMenuItem<void>(
        key: ValueKey('semantic-help-popover-$id'),
        enabled: false,
        padding: const EdgeInsets.all(16),
        child: Column(
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
            Text(description),
            if (secondary != null) ...[
              const SizedBox(height: 8),
              Text(secondary!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    ],
    child: child,
  );
}
