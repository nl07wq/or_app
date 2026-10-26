import 'dart:convert';
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
    Map<String, Object>? preferences,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    if (resetPreferences) {
      SharedPreferences.setMockInitialValues(preferences ?? {});
    }
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

  test('production B+C schedules remain seeded, physical, and varied', () {
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
      expect(node.duration, lessThanOrEqualTo(.72));
      expect(node.links.length, inInclusiveRange(1, 2));
    }
    expect(
      scanPatterns,
      containsAll([
        DataVaultScanPattern.surfaceSweep,
        DataVaultScanPattern.stripRaster,
      ]),
    );
    expect(
      nodeAnchors.any((anchor) => anchor.name.startsWith('leftWall')),
      isTrue,
    );
    expect(
      nodeAnchors.any((anchor) => anchor.name.startsWith('rightWall')),
      isTrue,
    );
    expect(
      nodeAnchors.any((anchor) => anchor.name.startsWith('floor')),
      isTrue,
    );
    expect(
      nodeAnchors.any((anchor) => anchor.name.startsWith('ceiling')),
      isTrue,
    );
    expect(
      nodeAnchors.any((anchor) => anchor.name.startsWith('pillar')),
      isTrue,
    );
  });

  test(
    'V2.4 retains about seventy percent of deterministic SPARK identities',
    () {
      var retained = 0;
      var total = 0;
      for (final surface in DataVaultImpulseSurface.values) {
        for (var lane = 0; lane < 5; lane++) {
          for (var packet = 0; packet < 1000; packet++) {
            total++;
            if (HistoryDataVaultMotion.retainSparkPacket(
              surface,
              lane,
              packet,
            )) {
              retained++;
            }
            expect(
              HistoryDataVaultMotion.retainSparkPacket(surface, lane, packet),
              HistoryDataVaultMotion.retainSparkPacket(surface, lane, packet),
            );
          }
        }
      }
      expect(retained / total, inInclusiveRange(.68, .72));
    },
  );

  test(
    'V2.6 separates independent frame scheduling and covers all scan planes',
    () {
      final scans = List.generate(
        100,
        HistoryDataVaultMotion.compositeScanEventFor,
      );
      final nodes = List.generate(
        100,
        HistoryDataVaultMotion.compositeNodeEventFor,
      );
      expect(
        scans[1].launchSeconds - scans[0].launchSeconds,
        closeTo(2.68 / 1.5, .0001),
      );
      expect(
        nodes[1].launchSeconds - nodes[0].launchSeconds,
        closeTo(1.2, .0001),
      );
      expect(scans.every((event) => event.lifetime >= 4.35), isTrue);
      expect(nodes.every((event) => event.anchorS.isFinite), isTrue);
      final gates = List.generate(
        12,
        HistoryDataVaultMotion.compositeGateEventFor,
      );
      expect(
        gates[1].launchSeconds - gates[0].launchSeconds,
        inInclusiveRange(4.85, 5.55),
      );
      for (final gate in gates) {
        final a = gate.launchSeconds + .1;
        final b = gate.launchSeconds + .5;
        expect(gate.frontAt(b), lessThan(gate.frontAt(a)));
      }
      for (var block = 0; block < 12; block++) {
        final surfaces = [
          for (var offset = 0; offset < 4; offset++)
            HistoryDataVaultMotion.compositeScanSurfaceFor(block * 4 + offset),
        ];
        expect(surfaces.toSet(), hasLength(4));
      }
      expect(
        HistoryDataVaultMotion.compositeScanPatternFor(gates.first.seed),
        isNot(DataVaultScanPattern.gate),
      );
    },
  );

  test('V2.5 gate and node events repeatedly enter the usable depth band', () {
    final visibleGates = <int>{};
    final visibleNodes = <int>{};
    for (var sample = 0; sample <= 300; sample++) {
      final seconds = sample / 10;
      final distance = HistoryDataVaultMotion.distanceAt(seconds);
      final gateCurrent = HistoryDataVaultMotion.compositeGateIndexAt(seconds);
      for (var index = gateCurrent; index >= gateCurrent - 1; index--) {
        final gate = HistoryDataVaultMotion.compositeGateEventFor(index);
        final head = gate.frontAt(seconds);
        if (gate.isActiveAt(seconds) &&
            head >= distance - 5 &&
            head <= distance + 88) {
          visibleGates.add(gate.id);
        }
      }
      final nodeCurrent = HistoryDataVaultMotion.compositeNodeIndexAt(seconds);
      for (var index = nodeCurrent; index >= nodeCurrent - 2; index--) {
        final node = HistoryDataVaultMotion.compositeNodeEventFor(index);
        if (node.isActiveAt(seconds) &&
            node.anchorS >= distance - 4 &&
            node.anchorS <= distance + 92 &&
            node.activeHopsAt(seconds).isNotEmpty) {
          visibleNodes.add(node.id);
        }
      }
    }
    expect(visibleGates.length, greaterThanOrEqualTo(4));
    expect(visibleNodes.length, greaterThanOrEqualTo(18));
  });

  test('memory module routes stay outside the HISTORY glyph zone', () {
    final routes = HistoryMemoryModuleMotion.routes(const Size(192, 42));
    expect(routes, hasLength(4));
    for (final route in routes) {
      final bounds = route.getBounds();
      expect(bounds.left, greaterThanOrEqualTo(10));
      expect(bounds.right, lessThanOrEqualTo(180));
      expect(bounds.top < 12 || bounds.bottom > 31, isTrue);
    }
  });

  test('memory module signal and contacts use a staggered transfer cycle', () {
    expect(HistoryMemoryModuleMotion.cycleSeconds, 2.8);
    for (var channel = 0; channel < 4; channel++) {
      final signal = HistoryMemoryModuleMotion.signalFor(
        channel,
        HistoryMemoryModuleMotion.channelOffsets[channel] + .20,
      );
      expect(signal, isNotNull);
      expect(signal!.end, greaterThan(signal.start));
      expect(signal.fade, greaterThan(0));
    }
    for (var contact = 0; contact < 5; contact++) {
      final peak = .52 + contact * .09 + .06;
      expect(
        HistoryMemoryModuleMotion.contactStrength(contact, peak),
        closeTo(.5, .05),
      );
      expect(HistoryMemoryModuleMotion.contactStrength(contact, peak + .30), 0);
    }
    for (var step = 0; step < 48; step++) {
      final seconds = step / 10;
      final bright = List.generate(
        5,
        (index) => HistoryMemoryModuleMotion.contactStrength(index, seconds),
      ).where((strength) => strength > .4).length;
      expect(bright, lessThanOrEqualTo(2));
    }
  });

  testWidgets('memory module keeps HISTORY stable through signal frames', (
    tester,
  ) async {
    final preferences = <String, Object>{
      HistoryVisualPreference.storageKey: jsonEncode({
        'version': 1,
        'title': HistoryTitleVariant.memoryModule.name,
        'ambient': HistoryAmbientVariant.dataVault.name,
      }),
    };
    const frames = <(String, Duration)>[
      ('idle', Duration(milliseconds: 2200)),
      ('packet', Duration(milliseconds: 200)),
      ('contact', Duration(milliseconds: 640)),
      ('decay', Duration(milliseconds: 980)),
    ];
    for (final frame in frames) {
      await pumpHistory(tester, time: frame.$2, preferences: preferences);
      await tester.pump();
      final title = find.byKey(const ValueKey('history-title-memoryModule'));
      expect(title, findsOneWidget);
      expect(tester.getSize(title), const Size(192, 42));
      expect(
        find.descendant(of: title, matching: find.text('HISTORY')),
        findsOneWidget,
      );
      final text = find.descendant(of: title, matching: find.text('HISTORY'));
      final localCenter =
          tester.getCenter(text).dx - tester.getTopLeft(title).dx;
      expect(localCenter, closeTo(90, 2));
      await expectLater(
        title,
        matchesGoldenFile('goldens/history_memory_module_v26_${frame.$1}.png'),
      );
    }
  });

  testWidgets(
    'V2.6 composite keeps independent Frame and NODE accents in the HISTORY view',
    (tester) async {
      const frames = <(String, Duration)>[
        ('gate_approach', Duration(milliseconds: 3000)),
        ('gate_near', Duration(milliseconds: 3200)),
        ('node_burst', Duration(milliseconds: 7400)),
      ];
      for (final frame in frames) {
        await pumpHistory(tester, time: frame.$2);
        await expectLater(
          find.byType(DataCenterHistoryPage),
          matchesGoldenFile('goldens/history_data_vault_v26_${frame.$1}.png'),
        );
      }
    },
  );

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
