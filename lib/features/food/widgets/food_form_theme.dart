import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Route-local, immutable presentation tokens shared by FOOD ENTRY and FOOD
/// DATABASE add/edit forms. Domain data and controllers stay owned by each
/// screen; only the compact visual language is shared here.
abstract final class FoodFormMetrics {
  static const pageSurface = Color(0xFF0D1219);
  static const fieldSurface = Color(0xFF17212C);
  static const nutritionSurface = Color(0xFF141D27);
  static const separator = Color(0xFF273D4B);
  static const caption = Color(0xFF83A5B8);
  static const fieldLabel = Color(0xFF7898AB);
  static const fieldValue = Color(0xFFEDF6FB);
  static const protein = Color(0xFF76C4E7);
  static const fat = Color(0xFF8EADE1);
  static const carbohydrate = Color(0xFFAAA6E2);
  static const fieldContentPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 8,
  );
  static const labelTextStyle = TextStyle(fontSize: 12);
  static const valueFontSize = 14.0;
  static const gap = SizedBox(height: AppSpacing.sm);
  static const horizontalGap = SizedBox(width: AppSpacing.sm);
  static const barcodeButtonSize = Size(84, 44);
  static const barcodeButtonPadding = EdgeInsets.symmetric(horizontal: 10);

  static ThemeData applyTo(ThemeData theme) {
    final labelStyle = labelTextStyle.copyWith(color: fieldLabel);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: separator),
    );
    return theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: fieldContentPadding,
        labelStyle: labelStyle,
        floatingLabelStyle: labelStyle,
        filled: true,
        fillColor: fieldSurface,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
        ),
        hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
          color: fieldLabel.withValues(alpha: .72),
        ),
      ),
      textTheme: theme.textTheme.copyWith(
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(
          fontSize: valueFontSize,
          color: fieldValue,
        ),
        bodyMedium: theme.textTheme.bodyMedium?.copyWith(
          fontSize: valueFontSize,
          color: fieldValue,
        ),
      ),
    );
  }
}

/// Keeps form presentation isolated to the current route subtree. It never
/// stores mutable configuration, so a database form cannot alter ENTRY after
/// a pop/return transition.
class FoodFormTheme extends StatelessWidget {
  const FoodFormTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: FoodFormMetrics.applyTo(Theme.of(context)), child: child);
}
