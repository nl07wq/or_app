import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'first Flutter frame is not gated by notification profile initialization',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      final runApp = source.indexOf('runApp(');
      final notificationStart = source.indexOf(
        'unawaited(_initializeNotificationProfile(diagnostic));',
      );

      expect(runApp, greaterThanOrEqualTo(0));
      expect(notificationStart, greaterThan(runApp));
      expect(
        source.indexOf(
          'await NotificationProfileController.instance.initialize();',
        ),
        greaterThan(runApp),
      );
      expect(source, contains('NOTIFICATION_PROFILE_INITIALIZATION_FAILED'));
      expect(
        source,
        contains('startBackgroundRecovery()'),
        reason: 'configured profiles must reconcile after repository startup',
      );
      expect(
        source.indexOf(
          'final initialization = initializationService.initialize();',
        ),
        lessThan(
          source.indexOf('DeviceSettingsController.instance.initialize,'),
        ),
        reason: 'database and device settings startup must overlap',
      );
      expect(
        source,
        contains('initializationService: initializationService'),
        reason: 'the prestarted single-flight service must own StartupGate',
      );
    },
  );

  test('release-matched main bundle is preloaded after worker recovery', () {
    final source = File('web/index.html').readAsStringSync();
    final recovery = source.indexOf(
      'window.__orAppStartupRecovery.finally(function ()',
    );
    final preload = source.indexOf("mainPreload.rel = 'preload'");
    final versionedMain = source.indexOf(
      "mainPreload.href = 'main.dart.js?or_app_release=__OR_APP_RELEASE__'",
    );
    final bootstrap = source.indexOf(
      "bootstrap.src = 'flutter_bootstrap.js?or_app_release=__OR_APP_RELEASE__'",
    );

    expect(recovery, greaterThanOrEqualTo(0));
    expect(preload, greaterThan(recovery));
    expect(versionedMain, greaterThan(preload));
    expect(bootstrap, greaterThan(versionedMain));
    expect(source, contains("mainPreload.as = 'script'"));
    expect(source, contains("mainPreload.fetchPriority = 'high'"));
    expect(source, contains('mainPreloadRequestedMs'));
    expect(source, contains('mainPreloadLoadedMs'));
  });

  test('pre-Dart evidence is bounded and survives an interrupted launch', () {
    final source = File('web/index.html').readAsStringSync();

    expect(source, contains('or_app.pre_dart_evidence.v1'));
    expect(source, contains('records.slice(-5)'));
    expect(source, contains("status: 'document_started'"));
    expect(source, contains("window.__orAppMarkPreDart = function"));
    expect(source, contains("'bootstrap_requested'"));
    expect(source, contains("'bootstrap_loaded'"));
    expect(source, contains("'main_preload_loaded'"));
    expect(source, contains("'main_preload_failed'"));
  });

  test('custom Flutter bootstrap separates evaluation and engine timing', () {
    final source = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(source, contains('onEntrypointLoaded'));
    expect(source, contains('entrypointLoadedMs'));
    expect(source, contains('engineInitializeStartMs'));
    expect(source, contains('engineInitializeCompleteMs'));
    expect(source, contains('runAppStartMs'));
    expect(source, contains('runAppCompleteMs'));
    expect(source, contains('await engineInitializer.initializeEngine()'));
    expect(source, contains('await appRunner.runApp()'));
  });
}
