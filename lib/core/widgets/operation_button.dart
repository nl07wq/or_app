import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
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

  const OperationButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.role = OperationActionRole.secondary,
    this.reportUnavailableTap = false,
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
          elevation: 4,
          foregroundColor: foregroundColor,
          disabledForegroundColor: Theme.of(context).disabledColor,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        ),
        child: Listener(
          onPointerDown: onPressed == null
              ? null
              : (event) => GlobalTouchRipple.claimSuccess(event.pointer),
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
      ),
    );
    if (onPressed != null) {
      return SemanticFeedbackRegion(child: button);
    }
    if (!reportUnavailableTap) return button;
    return SemanticFeedbackRegion(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => GlobalTouchRipple.claimFailure(event.pointer),
        child: button,
      ),
    );
  }
}
