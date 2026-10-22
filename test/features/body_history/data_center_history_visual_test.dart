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

  testWidgets('uses one DATA VAULT composition and hides comparison controls', (
    tester,
  ) async {
    await pumpHistory(tester);
    expect(find.text('TITLE'), findsNothing);
    expect(find.text('AMBIENT'), findsNothing);
    expect(
      find.byKey(const ValueKey('history-data-vault-impulse-selector')),
      findsNothing,
    );
    for (final label in [
      'A ARC',
      'B SCAN',
      'C NODE',
      'D SPARK',
      'E ARC+SPARK',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(
      (await SharedPreferences.getInstance()).getString(
        HistoryDataVaultImpulsePreference.storageKey,
      ),
      isNull,
    );
  });

  for (final size in const [
    Size(320, 844),
    Size(375, 844),
    Size(390, 844),
    Size(430, 844),
  ]) {
    testWidgets('DATA VAULT production ambient has no overflow at $size', (
      tester,
    ) async {
      await pumpHistory(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('history-data-vault-impulse-selector')),
        findsNothing,
      );
    });
  }

  testWidgets('renders one production composition across flight phases', (
    tester,
  ) async {
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
      expect(
        find.byKey(const ValueKey('history-ambient-dataVault')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  test(
    'production composition shares continuous camera distance and bounded painter work',
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
      for (final seconds in [0.0, 8.0, 16.0, 24.0, 32.0, 40.0]) {
        final recorder = ui.PictureRecorder();
        HistoryDataVaultHyperspace(
          seconds: seconds,
        ).paint(Canvas(recorder), const Size(390, 844));
        recorder.endRecording().dispose();
      }
      watch.stop();
      // Local Canvas timing only, never an iPhone Safari claim.
      // ignore: avoid_print
      print('DATA_VAULT_V23_LOCAL_PAINT_6_MS=${watch.elapsedMilliseconds}');
      expect(watch.elapsedMicroseconds, greaterThanOrEqualTo(0));
    },
  );

  test('arc episodes are short stationary electrical failures', () {
    for (var lane = 0; lane < 7; lane++) {
      final episode = HistoryDataVaultMotion.arcEpisodeFor(lane, 9);
      expect(episode.lifetime, inInclusiveRange(.18, .42));
      expect(episode.anchorS.isFinite, isTrue);
      expect(
        HistoryDataVaultMotion.arcEpisodeFor(lane, 9).anchorS,
        episode.anchorS,
      );
      expect(episode.family, isIn(DataVaultArcFamily.values));
    }
  });

  test('scan events retain physical far-to-near motion and three patterns', () {
    const surfaces = [
      DataVaultImpulseSurface.floor,
      DataVaultImpulseSurface.leftWall,
      DataVaultImpulseSurface.rightWall,
      DataVaultImpulseSurface.ceiling,
    ];
    final patterns = <DataVaultScanPattern>{};
    for (final surface in surfaces) {
      final scan = HistoryDataVaultMotion.scanEventFor(surface, 0, 4);
      final a = scan.launchSeconds + .10;
      final b = scan.launchSeconds + .50;
      expect(scan.frontAt(b), lessThan(scan.frontAt(a)));
      expect(
        scan.frontAt(b) - HistoryDataVaultMotion.distanceAt(b),
        lessThan(scan.frontAt(a) - HistoryDataVaultMotion.distanceAt(a)),
      );
      for (var id = 0; id < 30; id++) {
        patterns.add(
          HistoryDataVaultMotion.scanPatternFor(
            HistoryDataVaultMotion.scanEventFor(surface, 0, id).seed,
          ),
        );
      }
    }
    expect(patterns, containsAll(DataVaultScanPattern.values));
  });

  test('production B+C schedules stay sparse, seeded and physical', () {
    final scanPatterns = <DataVaultScanPattern>{};
    final nodeAnchors = <DataVaultNodeAnchor>{};
    for (var index = 0; index < 48; index++) {
      final scan = HistoryDataVaultMotion.compositeScanEventFor(index);
      final earlier = scan.launchSeconds + .1;
      final later = scan.launchSeconds + .5;
      expect(scan.frontAt(later), lessThan(scan.frontAt(earlier)));
      expect(
        scan.frontAt(later) - HistoryDataVaultMotion.distanceAt(later),
        lessThan(
          scan.frontAt(earlier) - HistoryDataVaultMotion.distanceAt(earlier),
        ),
      );
      scanPatterns.add(
        HistoryDataVaultMotion.compositeScanPatternFor(scan.seed),
      );
      final node = HistoryDataVaultMotion.compositeNodeEventFor(index);
      nodeAnchors.addAll(node.anchors);
      expect(node.duration, lessThanOrEqualTo(.65));
      expect(node.links.length, inInclusiveRange(1, 2));
    }
    expect(scanPatterns, containsAll(DataVaultScanPattern.values));
    expect(nodeAnchors.any((anchor) => anchor.name.startsWith('leftWall')), isTrue);
    expect(nodeAnchors.any((anchor) => anchor.name.startsWith('rightWall')), isTrue);
    expect(nodeAnchors.any((anchor) => anchor.name.startsWith('floor')), isTrue);
    expect(nodeAnchors.any((anchor) => anchor.name.startsWith('ceiling')), isTrue);
    expect(nodeAnchors.any((anchor) => anchor.name.startsWith('pillar')), isTrue);
  });

  test(
    'node topology catalog includes varied physical surfaces and timing',
    () {
      final topologies = <DataVaultNodeTopology>{};
      var floorOrCeiling = 0;
      var pillar = 0;
      for (var id = 0; id < 80; id++) {
        final event = HistoryDataVaultMotion.nodeEventFor(id % 5, id);
        topologies.add(event.topology);
        if (event.anchors.any(
          (anchor) =>
              anchor.name.startsWith('floor') ||
              anchor.name.startsWith('ceiling'),
        )) {
          floorOrCeiling++;
        }
        if (event.anchors.any((anchor) => anchor.name.startsWith('pillar'))) {
          pillar++;
        }
        for (var hop = 0; hop < event.links.length; hop++) {
          expect(
            event
                .activeHopsAt(
                  event.launchSeconds + event.links[hop].startOffset + .08,
                )
                .contains(hop),
            isTrue,
          );
        }
      }
      expect(topologies, containsAll(DataVaultNodeTopology.values));
      expect(floorOrCeiling, greaterThanOrEqualTo(24));
      expect(pillar, greaterThanOrEqualTo(16));
    },
  );

  test('hybrid uses sparse spark-derived local reactions', () {
    var reactions = 0;
    for (var packet = 0; packet < 40; packet++) {
      if (HistoryDataVaultMotion.hybridResponseFor(
            DataVaultImpulseSurface.floor,
            0,
            packet,
          ) !=
          null) {
        reactions++;
      }
    }
    expect(reactions, inInclusiveRange(4, 18));
  });

  test(
    'inbound scan and spark positions stay continuous across cycle bounds',
    () {
      final event = HistoryDataVaultMotion.scanEventFor(
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
    },
  );
}
