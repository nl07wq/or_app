import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/app_clock.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/activity/activity_entry_page.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final today = DateTime(2026, 11, 25);
    AppClock.setSystemNowForTesting(() => today);
    database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-11-25');
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(() {
    AppClock.resetForTesting();
    AppRepositoryRegistry.resetForTesting();
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });

  for (final negative in <bool>[false, true]) {
    final mode = negative ? 'inv' : 'light';
    testWidgets('ACTIVITY V2 $mode numeric LCD renderer', (tester) async {
      await _pumpActivity(tester, width: 390, height: 844, negative: negative);

      expect(find.text('Previous day Carry Over deduction'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('activity-v2-capture')),
        matchesGoldenFile('goldens/activity_entry_v2_${mode}_numeric_390.png'),
      );
    });
  }

  testWidgets('ACTIVITY V2 digestive rows and pressed key renderer', (
    tester,
  ) async {
    await _pumpActivity(tester, width: 320, height: 844, negative: false);

    final amountNormal = find.text('普通').first;
    await tester.ensureVisible(amountNormal);
    await tester.tap(amountNormal);
    await tester.pump();

    final shape = find.text('普通便');
    await tester.ensureVisible(shape);
    await tester.tap(shape);
    await tester.pump();

    final relief = find.text('普通').last;
    await tester.ensureVisible(relief);
    await tester.tap(relief);
    await tester.pump();

    final pressed = find.text('多量');
    await tester.ensureVisible(pressed);
    final gesture = await tester.startGesture(tester.getCenter(pressed));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.getTopLeft(find.text('DIGESTIVE')).dy, greaterThan(55));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('activity-v2-capture')),
      matchesGoldenFile('goldens/activity_entry_v2_digestive_pressed_320.png'),
    );
    await gesture.cancel();
  });

  for (final size in const <Size>[Size(320, 568), Size(844, 390)]) {
    testWidgets('ACTIVITY V2 remains scrollable without overflow at $size', (
      tester,
    ) async {
      await _pumpActivity(
        tester,
        width: size.width,
        height: size.height,
        negative: false,
      );
      final digestive = find.text('DIGESTIVE');
      await tester.ensureVisible(digestive);
      await tester.pump();
      expect(digestive, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpActivity(
  WidgetTester tester, {
  required double width,
  required double height,
  required bool negative,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  DeviceSettingsController.instance.resetForTesting(
    DeviceSettings(baseCampLcdNegative: negative),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: const ValueKey('activity-v2-capture'),
        child: BaseCampScreenEntry(
          screen: BaseCampScreen.activity,
          child: const ActivityEntryPage(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
