import 'package:flutter/material.dart';

import 'app.dart';
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
  diagnostic.record('DART', 'RUN_APP_REQUESTED');

  runApp(const OperationRebootApp());
}
