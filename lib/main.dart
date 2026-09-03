import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/active_session_heartbeat.dart';
import 'core/services/startup_diagnostic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
}
