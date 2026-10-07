import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/system/pages/ambient_wildlife_v2.dart';
import 'package:or_app/features/reminders/pages/reminders_page.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/schedule/pages/calendar_page.dart';
import 'package:or_app/features/system/pages/about_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/operation_date/operation_date_test_fixture.dart';
import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late DeviceSettings originalSettings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalSettings = DeviceSettingsController.instance.value;
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, _dateKey(DateTime.now()));
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(() {
    DeviceSettingsController.instance.resetForTesting(originalSettings);
    AppRepositoryRegistry.resetForTesting();
  });

  testWidgets(
    'shared global Ripple renders on representative production surfaces',
    (tester) async {
      await _expectPassiveFeedback(
        tester,
        page: const DashboardPage(),
        passiveTarget: find.byKey(const ValueKey('dashboard-neon-brand-mark')),
      );
      await _expectPassiveFeedback(
        tester,
        page: const CalendarPage(),
        passiveTarget: find.text('CALENDAR'),
      );
      await _expectPassiveFeedback(
        tester,
        page: const RemindersPage(),
        passiveTarget: find.text('REMINDERS'),
      );
      await _expectPassiveFeedback(
        tester,
        page: const AboutPage(),
        passiveTarget: find.text('ABOUT').first,
      );
    },
  );

  testWidgets(
    'Dashboard Wildlife visibility follows settings immediately at production widths',
    (tester) async {
      final settings = DeviceSettingsController.instance;
      final stage = find.byKey(
        const ValueKey('dashboard-ambient-wildlife-stage'),
      );
      final visibility = find.byKey(
        const ValueKey('dashboard-ambient-wildlife-visibility'),
      );
      final paw = find.byKey(
        const ValueKey('dashboard-ambient-manual-trigger'),
      );

      for (final width in [320.0, 390.0, 900.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        settings.resetForTesting(
          const DeviceSettings(brightness: DeviceSettings.minimumBrightness),
        );
        await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
        await tester.pump(const Duration(milliseconds: 500));

        expect(stage, findsOneWidget, reason: 'enabled width $width');
        expect(
          find.byKey(
            const ValueKey('dashboard-ambient-wildlife-frosted-surface'),
          ),
          findsOneWidget,
          reason: 'surface width $width',
        );
        final productionState = tester
            .state<AmbientWildlifeV2ProductionStageState>(
              find.byType(AmbientWildlifeV2ProductionStage),
            );
        await tester.tap(paw);
        await tester.pump();
        expect(productionState.isActive, isTrue, reason: 'active width $width');

        settings.update(settings.value.copyWith(ambientWildlifeEnabled: false));
        await tester.pump();
        expect(
          tester.widget<Visibility>(visibility).visible,
          isFalse,
          reason: 'disabled width $width',
        );
        expect(
          tester
              .widget<IconButton>(
                find.descendant(of: paw, matching: find.byType(IconButton)),
              )
              .onPressed,
          isNull,
        );

        settings.update(settings.value.copyWith(ambientWildlifeEnabled: true));
        await tester.pump();
        expect(stage, findsOneWidget, reason: 're-enabled width $width');
        expect(tester.widget<Visibility>(visibility).visible, isTrue);
        expect(
          tester.state<AmbientWildlifeV2ProductionStageState>(
            find.byType(AmbientWildlifeV2ProductionStage),
          ),
          same(productionState),
          reason: 'state preserved width $width',
        );
        expect(
          productionState.isActive,
          isTrue,
          reason: 'resumed width $width',
        );
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}

Future<void> _expectPassiveFeedback(
  WidgetTester tester, {
  required Widget page,
  required Finder passiveTarget,
}) async {
  final audio = _RecordingAudio();
  var rippleEvents = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: GlobalTouchRipple(
        audio: audio,
        onRippleEventCreated: (_) => rippleEvents++,
        child: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  expect(passiveTarget, findsOneWidget);
  await tester.tap(passiveTarget);
  await tester.pump(const Duration(milliseconds: 32));

  expect(rippleEvents, 1);
  expect(audio.played, [TouchFeedbackSound.water]);
  expect(
    find.byKey(const ValueKey('global-touch-ripple-overlay')),
    findsOneWidget,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

class _RecordingAudio implements TouchRippleAudio {
  final played = <TouchFeedbackSound>[];

  @override
  void dispose() {}

  @override
  void playFromUserGesture(TouchFeedbackSound sound) => played.add(sound);

  @override
  void prepare() {}
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
