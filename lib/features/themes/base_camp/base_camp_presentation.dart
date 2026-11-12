import 'package:flutter/material.dart';

import 'base_camp_retro_theme.dart';

/// Stable identifiers for the BASE CAMP route-level presentation entrypoints.
/// The feature pages beneath them intentionally continue to use the same
/// repositories, records, and operation services as STANDARD.
enum BaseCampScreen {
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
  diagnostics,
  startupDiagnostic,
  dashboardDiagnostic,
  operationSync,
  historicalTrainingImport,
  historicalDnsImport,
  logConfirmationReview,
  logConfirmationDetail,
}

/// An isolated visual scope for the BASE CAMP copy. This intentionally owns
/// presentation identity without cloning any formal data or business logic.
class BaseCampPresentation extends InheritedWidget {
  const BaseCampPresentation({
    super.key,
    required this.screen,
    required super.child,
  });

  final BaseCampScreen screen;

  static BaseCampPresentation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BaseCampPresentation>();

  /// MaterialPageRoute descendants receive the application-level BASE CAMP
  /// theme even though they do not inherit a marker from the previous route.
  static bool isActive(BuildContext context) =>
      maybeOf(context) != null ||
      BaseCampRetroTheme.isApplied(Theme.of(context));

  @override
  bool updateShouldNotify(BaseCampPresentation oldWidget) =>
      oldWidget.screen != screen;
}

/// The separate route-level entrypoint for every current STANDARD screen.
/// V1 intentionally preserves the STANDARD snapshot inside this scope; future
/// BASE CAMP visual implementations can branch by [screen] without affecting
/// STANDARD routes or feature data.
class BaseCampScreenEntry extends StatelessWidget {
  const BaseCampScreenEntry({
    super.key,
    required this.screen,
    required this.child,
  });

  final BaseCampScreen screen;
  final Widget child;

  @override
  Widget build(BuildContext context) => BaseCampPresentation(
    screen: screen,
    child: Theme(
      data: BaseCampRetroTheme.apply(Theme.of(context)),
      child: KeyedSubtree(
        key: ValueKey('base-camp-screen-${screen.name}'),
        child: child,
      ),
    ),
  );
}
