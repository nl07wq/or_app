import 'package:flutter/material.dart';

enum HistoryMetricColorKey {
  weight,
  bodyFat,
  intakeCalories,
  estimatedExpenditure,
  calorieBalance,
}

abstract final class HistoryMetricColorRegistry {
  static Color resolve(BuildContext context, HistoryMetricColorKey key) {
    final theme = Theme.of(context);
    return resolveFor(
      key: key,
      colorScheme: theme.colorScheme,
      brightness: theme.brightness,
    );
  }

  static Color resolveFor({
    required HistoryMetricColorKey key,
    required ColorScheme colorScheme,
    required Brightness brightness,
  }) => switch (key) {
    HistoryMetricColorKey.weight => colorScheme.primary,
    HistoryMetricColorKey.bodyFat =>
      brightness == Brightness.dark
          ? Colors.purple.shade300
          : Colors.purple.shade600,
    HistoryMetricColorKey.intakeCalories =>
      brightness == Brightness.dark
          ? Colors.orange.shade300
          : Colors.orange.shade700,
    HistoryMetricColorKey.estimatedExpenditure =>
      brightness == Brightness.dark
          ? Colors.cyan.shade300
          : Colors.cyan.shade700,
    HistoryMetricColorKey.calorieBalance =>
      brightness == Brightness.dark
          ? Colors.teal.shade300
          : Colors.teal.shade600,
  };
}
