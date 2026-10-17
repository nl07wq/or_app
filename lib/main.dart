import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/active_session_heartbeat.dart';
import 'core/services/device_settings_controller.dart';
import 'core/services/startup_diagnostic.dart';
import 'features/notifications/services/notification_profile_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

/// Notifications are an optional post-startup integration.  They must never
/// prevent Flutter from rendering its first frame when browser storage is
/// unavailable or a previous PWA session left it in a transient failure state.
Future<void> _initializeNotificationProfile(
  StartupDiagnostic diagnostic,
) async {
  try {
    await NotificationProfileController.instance.initialize();
    diagnostic.record('DART', 'NOTIFICATION_PROFILE_INITIALIZED');
  } catch (error) {
    diagnostic.record(
      'DART',
      'NOTIFICATION_PROFILE_INITIALIZATION_FAILED',
      fields: {'errorType': error.runtimeType.toString()},
    );
  }
}
