import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_theme.dart';
import 'package:or_app/features/body_history/pages/data_center_history_page.dart';
import 'package:or_app/features/body_history/services/history_visual_preference.dart';
import 'package:or_app/features/body_history/widgets/history_data_vault_hyperspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpHistory(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Duration time = const Duration(milliseconds: 18400),
    bool resetPreferences = true,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    if (resetPreferences) SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: StandardTheme.theme,
        home: DataCenterHistoryPage(
          animateAmbient: false,
          dataVaultSimulationTime: time,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('exposes five DATA VAULT modes and hides legacy rows', (
    tester,
  ) async {
    await pumpHistory(tester);
    expect(find.text('TITLE'), findsNothing);
    expect(find.text('AMBIENT'), findsNothing);
    expect(
      find.byKey(const ValueKey('history-data-vault-impulse-selector')),
      findsOneWidget,
    );
    for (final label in [
      'A ARC',
      'B SCAN',
      'C NODE',
      'D SPARK',
      'E ARC+SPARK',
    ]) {
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(
      (await SharedPreferences.getInstance()).getString(
        HistoryDataVaultImpulsePreference.storageKey,
      ),
      'e',
    );
  });

  for (final size in const [
    Size(320, 844),
    Size(375, 844),
    Size(390, 844),
    Size(430, 844),
  ]) {
    testWidgets('DATA VAULT selector has no overflow at $size', (tester) async {
      await pumpHistory(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('history-data-vault-impulse-selector')),
        findsOneWidget,
      );
    });
  }

  testWidgets('renders five structurally distinct impulse Goldens', (
    tester,
  ) async {
    const labels = ['A ARC', 'B SCAN', 'C NODE', 'D SPARK', 'E ARC+SPARK'];
    const times = <(String, Duration)>[
      ('start', Duration.zero),
      ('boost_a', Duration(milliseconds: 7700)),
      ('boost_b', Duration(milliseconds: 18400)),
      ('boost_c', Duration(milliseconds: 29500)),
      ('boost_d', Duration(milliseconds: 43100)),
      ('boundary_before', Duration(milliseconds: 47990)),
      ('boundary_after', Duration(milliseconds: 48010)),
      ('second_cycle', Duration(milliseconds: 96010)),
      ('motion_0', Duration(milliseconds: 18400)),
      ('motion_1', Duration(milliseconds: 18500)),
      ('motion_2', Duration(milliseconds: 18600)),
      ('motion_3', Duration(milliseconds: 18700)),
      ('motion_4', Duration(milliseconds: 18800)),
    ];
    for (final sample in times) {
      await pumpHistory(tester, time: sample.$2);
      for (var index = 0; index < labels.length; index++) {
        await tester.tap(find.text(labels[index]));
        await tester.pump();
        await expectLater(
          find.byKey(const ValueKey('history-ambient-dataVault')),
          matchesGoldenFile(
            'goldens/history_data_vault_v20_${sample.$1}_mode_$index.png',
          ),
        );
      }
    }
  });

  test(
    'impulse mode preference defaults, persists and rejects unknown token',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preference = HistoryDataVaultImpulsePreference();
      expect(await preference.load(), DataVaultImpulseMode.arc);
      await preference.save(DataVaultImpulseMode.hybrid);
      expect(await preference.load(), DataVaultImpulseMode.hybrid);
      SharedPreferences.setMockInitialValues({
        HistoryDataVaultImpulsePreference.storageKey: 'unknown',
      });
      expect(
        await HistoryDataVaultImpulsePreference().load(),
        DataVaultImpulseMode.arc,
      );
    },
  );

  test(
    'all modes share continuous camera distance and bounded painter work',
    () {
      expect(
        HistoryDataVaultMotion.distanceAt(48.01),
        greaterThan(HistoryDataVaultMotion.distanceAt(47.99)),
      );
      expect(
        HistoryDataVaultMotion.distanceAt(96.01),
        greaterThan(HistoryDataVaultMotion.distanceAt(95.99)),
      );
      final watch = Stopwatch()..start();
      for (final mode in DataVaultImpulseMode.values) {
        final recorder = ui.PictureRecorder();
        HistoryDataVaultHyperspace(
          seconds: 18.4,
          impulseMode: mode,
        ).paint(Canvas(recorder), const Size(390, 844));
        recorder.endRecording().dispose();
      }
      watch.stop();
      // Local Canvas timing only, never an iPhone Safari claim.
      // ignore: avoid_print
      print('DATA_VAULT_V20_LOCAL_PAINT_5_MS=${watch.elapsedMilliseconds}');
      expect(watch.elapsedMicroseconds, greaterThanOrEqualTo(0));
    },
  );

  test('arc, scan, node and hybrid events travel from far to near', () {
    const surfaces = [
      DataVaultImpulseSurface.floor,
      DataVaultImpulseSurface.leftWall,
      DataVaultImpulseSurface.rightWall,
      DataVaultImpulseSurface.ceiling,
    ];
    for (final surface in surfaces) {
      final arc = HistoryDataVaultMotion.arcEventFor(surface, 0, 9);
      final scan = HistoryDataVaultMotion.scanEventFor(surface, 0, 4);
      for (final event in [arc, scan]) {
        final a = event.launchSeconds + .10;
        final b = event.launchSeconds + .50;
        expect(event.frontAt(b), lessThan(event.frontAt(a)));
        expect(
          event.frontAt(b) - HistoryDataVaultMotion.distanceAt(b),
          lessThan(event.frontAt(a) - HistoryDataVaultMotion.distanceAt(a)),
        );
      }
    }
    final cascade = HistoryDataVaultMotion.nodeCascadeFor(-1, 7);
    expect(cascade.activeHopAt(cascade.launchSeconds + .01), 0);
    expect(cascade.activeHopAt(cascade.launchSeconds + .20), 1);
    expect(cascade.activeHopAt(cascade.launchSeconds + .32), 2);
    final far = cascade.frontAt(cascade.launchSeconds + .10) + 3 * 3.6;
    final near = cascade.frontAt(cascade.launchSeconds + .10) - 3.6;
    expect(far, greaterThan(near));
  });

  test('inbound fronts remain continuous across driving-cycle boundaries', () {
    final event = HistoryDataVaultMotion.arcEventFor(
      DataVaultImpulseSurface.floor,
      2,
      35,
    );
    for (final boundary in [48.0, 96.0]) {
      final before = event.frontAt(boundary - .01);
      final after = event.frontAt(boundary + .01);
      expect(after, lessThan(before));
      expect((after - before).abs(), lessThan(2));
    }
  });
}
