import 'package:flutter/material.dart';

/// Stable identifiers for the NEW THEME route-level presentation entrypoints.
/// The feature pages beneath them intentionally continue to use the same
/// repositories, records, and operation services as STANDARD.
enum NewThemeScreen {
  dashboard,
  finalizedDashboard,
  morning,
  food,
  activity,
  training,
  commandCenter,
  dataCenterHistory,
  bodyHistory,
  nutritionHistory,
  digestiveHistory,
  activityHistory,
  sleepHistory,
  trainingAnalyticsHistory,
  dailyAggregateRecords,
  dailyAggregateDetail,
  backupRestore,
  orloSync,
  profile,
  weatherSettings,
  reminders,
  about,
  system,
  deviceSettings,
  animationsSandbox,
  bodyMapSvgPreview,
  bootSequencePreview,
  bootSequenceCalibration,
  deviceTransfer,
  systemMonitoring,
  startupDiagnostic,
  operationSync,
  historicalTrainingImport,
  historicalDnsImport,
  logConfirmationReview,
  logConfirmationDetail,
}

/// An isolated visual scope for the NEW THEME copy. This intentionally owns
/// presentation identity without cloning any formal data or business logic.
class NewThemePresentation extends InheritedWidget {
  const NewThemePresentation({
    super.key,
    required this.screen,
    required super.child,
  });

  final NewThemeScreen screen;

  static NewThemePresentation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NewThemePresentation>();

  @override
  bool updateShouldNotify(NewThemePresentation oldWidget) =>
      oldWidget.screen != screen;
}

/// The separate route-level entrypoint for every current STANDARD screen.
/// V1 intentionally preserves the STANDARD snapshot inside this scope; future
/// NEW THEME visual implementations can branch by [screen] without affecting
/// STANDARD routes or feature data.
class NewThemeScreenEntry extends StatelessWidget {
  const NewThemeScreenEntry({
    super.key,
    required this.screen,
    required this.child,
  });

  final NewThemeScreen screen;
  final Widget child;

  @override
  Widget build(BuildContext context) => NewThemePresentation(
    screen: screen,
    child: KeyedSubtree(
      key: ValueKey('new-theme-screen-${screen.name}'),
      child: child,
    ),
  );
}
