import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'dashboard_glass_card.dart';
import 'global_touch_ripple.dart';

enum OperationActionRole { primary, secondary, danger }

class OperationButton extends StatelessWidget {
  final String text;

  final VoidCallback? onPressed;

  final IconData? icon;

  final OperationActionRole role;

  /// Lets an explicitly unavailable control report a non-mutating attempted
  /// action while retaining its disabled visual and accessibility semantics.
  final bool reportUnavailableTap;

  /// Defers semantic result feedback until the callback has validated or
  /// persisted its operation. The callback resolves through the shared
  /// [ActionableFeedbackRegion] API, never by choosing a sound asset.
  final bool deferFeedback;

  /// Allows an enclosing production glass surface to remain visible while
  /// retaining the button's established size, text, and interaction contract.
  final bool transparentSurface;
  final bool dashboardGlass;

  /// Limits comparison-only controls to their requested audio route without
  /// emitting a COMMAND confirmation for the diagnostic control itself.
  final ActionableFeedbackRole feedbackRole;
  final VoidCallback? onUnavailableTap;

  const OperationButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.role = OperationActionRole.secondary,
    this.reportUnavailableTap = false,
    this.deferFeedback = false,
    this.transparentSurface = false,
    this.dashboardGlass = false,
    this.feedbackRole = ActionableFeedbackRole.command,
    this.onUnavailableTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = onPressed == null
        ? Theme.of(context).disabledColor
        : switch (role) {
            OperationActionRole.primary => colorScheme.primary,
            OperationActionRole.secondary => AppTextStyles.label.color!,
            OperationActionRole.danger => colorScheme.error,
          };
    final button = SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: transparentSurface ? 0 : 4,
          backgroundColor: transparentSurface || dashboardGlass
              ? Colors.transparent
              : null,
          shadowColor: transparentSurface || dashboardGlass
              ? Colors.transparent
              : null,
          surfaceTintColor: transparentSurface || dashboardGlass
              ? Colors.transparent
              : null,
          foregroundColor: foregroundColor,
          disabledForegroundColor: Theme.of(context).disabledColor,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: foregroundColor),
              SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: AppTextStyles.label.copyWith(color: foregroundColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final surfaced = dashboardGlass
        ? Container(
            decoration: DashboardGlassCard.decoration(
              colorScheme,
              borderRadius: AppRadius.medium,
            ),
            child: button,
          )
        : button;
    if (onPressed != null) {
      return ActionableFeedbackRegion(
        deferResolution: deferFeedback,
        role: feedbackRole,
        child: surfaced,
      );
    }
    if (!reportUnavailableTap) return surfaced;
    return ActionableFeedbackRegion(
      result: ActionableFeedbackResult.unavailable,
      onPointerDown: onUnavailableTap,
      child: surfaced,
    );
  }
}
