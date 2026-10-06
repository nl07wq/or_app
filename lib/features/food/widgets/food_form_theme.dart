import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Route-local, immutable presentation tokens shared by FOOD ENTRY and FOOD
/// DATABASE add/edit forms. Domain data and controllers stay owned by each
/// screen; only the compact visual language is shared here.
abstract final class FoodFormMetrics {
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
    final labelStyle = labelTextStyle.copyWith(
      color: theme.inputDecorationTheme.labelStyle?.color,
    );
    return theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: fieldContentPadding,
        labelStyle: labelStyle,
        floatingLabelStyle: labelStyle,
      ),
      textTheme: theme.textTheme.copyWith(
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: valueFontSize),
        bodyMedium: theme.textTheme.bodyMedium?.copyWith(
          fontSize: valueFontSize,
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
