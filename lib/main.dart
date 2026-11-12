import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/active_session_heartbeat.dart';
import 'core/services/device_settings_controller.dart';
import 'core/services/startup_diagnostic.dart';
import 'core/services/system_diagnostics.dart';
import 'features/notifications/services/notification_profile_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final systemDiagnostics = SystemDiagnostics.instance;
  systemDiagnostics
    ..beginSession()
    ..installGlobalErrorHandlers()
    ..record('APPLICATION', 'DART_MAIN_ENTER');
  _installFlutterErrorDiagnostics(systemDiagnostics);
  await DeviceSettingsController.instance.initialize();
  final diagnostic = StartupDiagnostic.instance;
  diagnostic.beginRun();
  diagnostic.record(
    'DART',
    'DART_MAIN_ENTER',
    fields: {'bootSessionClaim': diagnostic.bootSessionClaim()},
  );
  final activeSession = ActiveSessionHeartbeat.instance;
  final session = activeSession.classifyAtStartup();
  diagnostic.record(
    'DART',
    'ACTIVE_SESSION_HEARTBEAT_CLASSIFIED',
    fields: {
      'classification': session.classification.name,
      'heartbeatPresent': session.heartbeatPresent,
      'heartbeatAgeMs': session.heartbeatAgeMs,
      'sessionTimeoutMs': ActiveSessionHeartbeat.sessionTimeout.inMilliseconds,
    },
  );
  activeSession.start();
  diagnostic.record('DART', 'RUN_APP_REQUESTED');

  runApp(const OperationRebootApp());
  unawaited(_initializeNotificationProfile(diagnostic));
}

void _installFlutterErrorDiagnostics(SystemDiagnostics diagnostics) {
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    diagnostics.record(
      'FLUTTER',
      'FLUTTER_ERROR',
      fields: <String, Object?>{
        'exceptionType': details.exception.runtimeType.toString(),
        'exception': _boundedDiagnosticText(details.exceptionAsString(), 2000),
        if (details.library != null) 'library': details.library,
        if (details.context != null) 'context': details.context.toString(),
      },
    );
    if (previousFlutterHandler != null) {
      previousFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    diagnostics.record(
      'DART',
      'UNHANDLED_ASYNC_ERROR',
      fields: <String, Object?>{
        'errorType': error.runtimeType.toString(),
        'error': _boundedDiagnosticText(error.toString(), 2000),
        'stack': _boundedDiagnosticText(stackTrace.toString(), 6000),
      },
    );
    return previousPlatformHandler?.call(error, stackTrace) ?? false;
  };
}

String _boundedDiagnosticText(String value, int limit) => value.length <= limit
    ? value
    : '${value.substring(0, limit)}\n...[TRUNCATED]';

/// Notifications are an optional post-startup integration.  They must never
/// prevent Flutter from rendering its first frame when browser storage is
/// unavailable or a previous PWA session left it in a transient failure state.
Future<void> _initializeNotificationProfile(
  StartupDiagnostic diagnostic,
) async {
  try {
    await NotificationProfileController.instance.initialize();
    unawaited(NotificationProfileController.instance.startBackgroundRecovery());
    diagnostic.record('DART', 'NOTIFICATION_PROFILE_INITIALIZED');
  } catch (error) {
    diagnostic.record(
      'DART',
      'NOTIFICATION_PROFILE_INITIALIZATION_FAILED',
      fields: {'errorType': error.runtimeType.toString()},
    );
  }
}
