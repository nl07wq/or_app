import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/startup_diagnostic.dart';
import 'core/services/startup_entry_classifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostic = StartupDiagnostic.instance;
  diagnostic.beginRun();
  diagnostic.record(
    'DART',
    'DART_MAIN_ENTER',
    fields: {'bootSessionClaim': diagnostic.bootSessionClaim()},
  );
  final startupEntry = StartupEntryClassifier.instance
      .classifyAtDocumentStart();
  diagnostic.record(
    'DART',
    'STARTUP_ENTRY_CLASSIFIED',
    fields: {
      'classification': startupEntry.classification.name,
      'persistentMarkerPresent': startupEntry.markerPresent,
      'previousPageHideAgeMs': startupEntry.previousPageHideAgeMs,
    },
  );
  diagnostic.record('DART', 'RUN_APP_REQUESTED');

  runApp(const OperationRebootApp());
}
