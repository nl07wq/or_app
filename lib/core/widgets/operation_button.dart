import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum OperationActionRole { primary, secondary, danger }

class OperationButton extends StatelessWidget {
  final String text;

  final VoidCallback? onPressed;

  final IconData? icon;

  final OperationActionRole role;

  const OperationButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.role = OperationActionRole.secondary,
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
    return SizedBox(
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
  }
}
