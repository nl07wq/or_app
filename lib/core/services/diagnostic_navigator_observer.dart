import 'package:flutter/material.dart';

import 'system_diagnostics.dart';

/// Read-only navigation observer. It does not replace, redirect, reject, or
/// otherwise participate in route resolution.
class DiagnosticNavigatorObserver extends NavigatorObserver {
  DiagnosticNavigatorObserver({SystemDiagnostics? diagnostics})
    : _diagnostics = diagnostics ?? SystemDiagnostics.instance;

  final SystemDiagnostics _diagnostics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('push', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('pop', previousRoute, route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _record('replace', newRoute, oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('remove', previousRoute, route);
  }

  void _record(
    String action,
    Route<dynamic>? requested,
    Route<dynamic>? previous,
  ) {
    _diagnostics.recordNavigation(
      action: action,
      previousRoute: previous?.settings.name,
      requestedRoute: requested?.settings.name,
      routeType: requested?.runtimeType.toString(),
    );
  }
}
