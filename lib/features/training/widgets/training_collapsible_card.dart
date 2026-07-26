import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';

class TrainingCollapsibleCard extends StatelessWidget {
  const TrainingCollapsibleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.isExpanded,
    required this.onToggle,
    required this.headerKey,
    required this.contentKey,
    required this.semanticsLabel,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? summary;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Key headerKey;
  final Key contentKey;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    void handleToggle() {
      FocusManager.instance.primaryFocus?.unfocus();
      onToggle();
    }

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            expanded: isExpanded,
            label: semanticsLabel,
            onTap: handleToggle,
            child: InkWell(
              key: headerKey,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              excludeFromSemantics: true,
              onTap: handleToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.cyanAccent, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (summary != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: Text(
                                summary!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    key: contentKey,
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: child,
                  )
                : SizedBox.shrink(key: contentKey),
          ),
        ],
      ),
    );
  }
}
