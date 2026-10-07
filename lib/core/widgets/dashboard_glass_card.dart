import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'operation_card.dart';

/// The production Dashboard card-glass material.
///
/// This is intentionally the source of truth for surfaces that need the same
/// baseline. It preserves the Dashboard's transparent Card, gradient, border,
/// radius, and depth treatment without adding blur or a new tint.
class DashboardGlassCard extends StatelessWidget {
  const DashboardGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.selectable = false,
    this.padding = AppSpacing.cardPadding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selectable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: Colors.transparent,
        cardTheme: Theme.of(context).cardTheme.copyWith(
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: OperationCard(
        onTap: onTap,
        selectable: selectable,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.large,
            gradient: gradient(scheme),
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
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  static LinearGradient gradient(
    ColorScheme scheme, {
    Color? stateColor,
    bool stateActive = false,
  }) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      (stateColor ?? scheme.primary).withValues(
        alpha: stateActive || stateColor != null ? .11 : .085,
      ),
      scheme.surface.withValues(alpha: .24),
      scheme.surfaceContainerHigh.withValues(alpha: .13),
    ],
  );
}
