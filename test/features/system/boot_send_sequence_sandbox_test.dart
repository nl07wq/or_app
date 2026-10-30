import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/boot_send_sequence_sandbox.dart';

void main() {
  test('fixed six-second phases use the shared timeline boundaries', () {
    expect(bootSendSequencePhase(0), BootSendSequencePhase.initializing);
    expect(bootSendSequencePhase(.2), BootSendSequencePhase.buildingData);
    expect(
      bootSendSequencePhase(2800 / 6000),
      BootSendSequencePhase.integrating,
    );
    expect(bootSendSequencePhase(4600 / 6000), BootSendSequencePhase.complete);
    expect(bootSendSequencePhase(1), BootSendSequencePhase.complete);
  });

  test('voxel geometry has 27 stable 22-unit cubes with intrinsic colors', () {
    final centers = sandboxVoxelCenters();
    expect(centers, hasLength(27));
    expect(
      centers.map((point) => '${point.x}:${point.y}:${point.z}').toSet(),
      hasLength(27),
    );
    final cube = sandboxCubeFaces(centers.first, 22);
    expect(cube, hasLength(6));
    expect(cube.every((face) => face.vertices.length == 4), isTrue);
    for (final face in cube) {
      for (var index = 0; index < 4; index++) {
        final edge = face.vertices[index] - face.vertices[(index + 1) % 4];
        expect(edge.length, closeTo(22, .0001));
      }
    }
    expect(
      sandboxVoxelColor(const SandboxVec3(0, 0, -24)),
      isNot(sandboxVoxelColor(const SandboxVec3(0, 0, 24))),
    );
    expect(
      sandboxVoxelColor(const SandboxVec3(0, 0, 24)),
      sandboxVoxelColor(const SandboxVec3(0, 0, 24)),
    );
  });

  test('pixel builder scales the nine-cell work timeline by 1.5x', () {
    expect(sandboxPixelBuilderFilledSegments(0), 0);
    expect(sandboxPixelBuilderFilledSegments(249), 0);
    expect(sandboxPixelBuilderFilledSegments(586), 0);
    expect(sandboxPixelBuilderFilledSegments(587), 1);
    expect(sandboxPixelBuilderFilledSegments(2021), 6);
    expect(sandboxPixelBuilderFilledSegments(2200), 6);
    // The last cell is supplied by the robot's fall, after its readable
    // final-act pause rather than a tenth rapid tool cycle.
    expect(sandboxPixelBuilderFilledSegments(4362), 9);
    expect(sandboxPixelBuilderFilledSegments(4364), 10);
    expect(
      sandboxPixelBuilderFinalAct(3313),
      SandboxPixelBuilderFinalAct.looking,
    );
    expect(
      sandboxPixelBuilderFinalAct(3700),
      SandboxPixelBuilderFinalAct.walking,
    );
    expect(
      sandboxPixelBuilderFinalAct(3950),
      SandboxPixelBuilderFinalAct.wobbling,
    );
    expect(
      sandboxPixelBuilderFinalAct(4250),
      SandboxPixelBuilderFinalAct.falling,
    );
    expect(sandboxPixelBuilderFinalAct(4364), SandboxPixelBuilderFinalAct.cell);
    expect(sandboxPixelBuilderCycleStartMs(6), closeTo(2453.33, .01));
    expect(
      sandboxPixelBuilderFinalActDurationMs(SandboxPixelBuilderFinale.walkIn),
      1350,
    );
    expect(
      sandboxPixelVoxelCycle(SandboxPixelBuilderFinale.walkIn).inMilliseconds,
      11414,
    );
    expect(sandboxPixelBuilderStrikeCount(0), 2);
    expect(sandboxPixelBuilderStrikeCount(2), 3);
    expect(sandboxPixelBuilderStrikeCount(5), 3);
    expect(sandboxPixelBuilderStrikeCount(8), 3);
    expect(sandboxPixelFragmentCount, 27);
    expect(
      List<int>.generate(
        sandboxPixelFragmentCount,
        sandboxPixelFragmentModule,
      ).where((module) => module < 7),
      hasLength(21),
    );
    expect(
      List<int>.generate(
        sandboxPixelFragmentCount,
        sandboxPixelFragmentModule,
      ).where((module) => module >= 7),
      hasLength(6),
    );
    for (var index = 0; index < sandboxPixelFragmentCount; index++) {
      final rect = sandboxPixelBuilderSegmentRect(
        sandboxPixelFragmentModule(index),
      );
      expect(rect.contains(sandboxPixelFragmentSource(index)), isTrue);
    }
  });

  test(
    'walk-in finale stays horizontal before integrating in the final rect',
    () {
      expect(
        sandboxPixelBuilderFinalAct(
          3700,
          finale: SandboxPixelBuilderFinale.walkIn,
        ),
        SandboxPixelBuilderFinalAct.walking,
      );
      expect(
        sandboxPixelBuilderFinalAct(
          4150,
          finale: SandboxPixelBuilderFinale.walkIn,
        ),
        SandboxPixelBuilderFinalAct.cell,
      );
      expect(
        sandboxPixelBuilderSegmentRect(9),
        const Rect.fromLTWH(254, 158, 17, 18),
      );
    },
  );

  test('message assembly uses deterministic occupied bitmap targets', () {
    for (final mode in ['BRIEF', 'DEBRIEF', 'BACKUP']) {
      final targets = sandboxMessageAssemblyTargets(mode);
      expect(targets, isNotEmpty);
      expect(targets, sandboxMessageAssemblyTargets(mode));
      expect(
        targets.every(
          (point) => const Rect.fromLTWH(24, 110, 312, 60).contains(point),
        ),
        isTrue,
      );
    }
    expect(sandboxMessageAssemblyMessage('BRIEF'), 'BRIEF RECEIVED');
    expect(sandboxMessageAssemblyMessage('DEBRIEF'), 'DEBRIEF RECEIVED');
    expect(sandboxMessageAssemblyMessage('BACKUP'), 'BACKUP COMPLETE');
  });

  test('message assembly keeps deterministic 3D cube material identities', () {
    final cubes = sandboxMessageCubes('DEBRIEF');
    expect(cubes, isNotEmpty);
    expect(cubes, sandboxMessageCubes('DEBRIEF'));
    expect(cubes.map((cube) => cube.id).toSet(), hasLength(cubes.length));
    expect(cubes.take(16).every((cube) => cube.size >= 10), isTrue);
    expect(cubes.every((cube) => cube.size > 0), isTrue);
    expect(cubes.map((cube) => cube.target).toSet(), hasLength(cubes.length));
  });

  test(
    'message assembly network is bounded, deterministic, and wave ordered',
    () {
      final targets = sandboxMessageAssemblyTargets('DEBRIEF');
      final edges = sandboxMessageNetworkEdges('DEBRIEF');
      expect(edges, isNotEmpty);
      expect(edges, sandboxMessageNetworkEdges('DEBRIEF'));
      final pairs = edges.map((edge) {
        final endpoints = [edge.a, edge.b]..sort();
        return endpoints.join(':');
      }).toSet();
      expect(pairs, hasLength(edges.length));
      final degree = List<int>.filled(targets.length, 0);
      for (final edge in edges) {
        expect(edge.a, inInclusiveRange(0, targets.length - 1));
        expect(edge.b, inInclusiveRange(0, targets.length - 1));
        expect(edge.wave, inInclusiveRange(0, 2));
        degree[edge.a]++;
        degree[edge.b]++;
      }
      expect(degree.every((value) => value <= 4), isTrue);
      expect(
        edges.map((edge) => edge.wave).toSet().length,
        greaterThanOrEqualTo(2),
      );
    },
  );

  test('message sparse graph and cube-emitted particles are deterministic', () {
    final cubes = sandboxMessageCubes('BRIEF');
    final selected = sandboxMessageSelectedNetworkEdges('BRIEF');
    final particles = sandboxMessageParticles('BRIEF');
    expect(selected, sandboxMessageSelectedNetworkEdges('BRIEF'));
    expect(selected.length, inInclusiveRange(36, 52));
    expect(
      selected.every((edge) => edge.a < cubes.length && edge.b < cubes.length),
      isTrue,
    );
    final reachable = <int>{0};
    while (true) {
      final before = reachable.length;
      for (final edge in selected) {
        if (reachable.contains(edge.a)) reachable.add(edge.b);
        if (reachable.contains(edge.b)) reachable.add(edge.a);
      }
      if (reachable.length == before) break;
    }
    for (final edge in selected) {
      expect(reachable, contains(edge.a));
      expect(reachable, contains(edge.b));
    }
    expect(selected.map((edge) => edge.wave).toSet(), containsAll([0, 1, 2]));
    expect(particles, sandboxMessageParticles('BRIEF'));
    expect(particles, hasLength(cubes.length * 6));
    expect(
      particles.every((particle) => particle.sourceId < cubes.length),
      isTrue,
    );
    expect(particles.every((particle) => particle.size >= .6), isTrue);
    expect(sandboxMessageSurfaceReveal(3200), closeTo(.12, .001));
    expect(sandboxMessageSurfaceReveal(4200), closeTo(.45, .001));
    expect(sandboxMessageSurfaceReveal(5200), closeTo(1, .001));
    expect(sandboxMessageCameraZoom(3450), closeTo(3.3, .001));
    expect(sandboxMessageCameraZoom(5650), closeTo(1, .001));
    expect(sandboxMessageScreenRoll(3350), closeTo(-72, .001));
    expect(sandboxMessageScreenRoll(5560), closeTo(0, .001));
  });

  test('voxel completion boundary always reaches both fractional finales', () {
    for (final finale in SandboxPixelBuilderFinale.values) {
      final constructionEnd = sandboxPixelVoxelConstructionEndMs(finale);
      final duration = sandboxPixelVoxelCycle(finale).inMilliseconds;
      expect(duration, constructionEnd.ceil());
      expect(
        sandboxPixelVoxelConstructionComplete(duration.toDouble(), finale),
        isTrue,
      );
      expect(
        sandboxPixelVoxelConstructionComplete(constructionEnd - .01, finale),
        isFalse,
      );
    }
  });

  test('folded net finishes as six joined 80-unit cube faces', () {
    final faces = sandboxFoldedCubeFaces(1);
    expect(faces, hasLength(6));
    final vertices = faces
        .expand((face) => face.vertices)
        .map(
          (point) => '${point.x.round()}:${point.y.round()}:${point.z.round()}',
        )
        .toSet();
    expect(vertices, hasLength(8));
    final normals = faces
        .map(
          (face) =>
              '${face.normal.x.round()}:${face.normal.y.round()}:${face.normal.z.round()}',
        )
        .toSet();
    expect(normals, {'1:0:0', '-1:0:0', '0:1:0', '0:-1:0', '0:0:1', '0:0:-1'});
    final edges = <String>{};
    for (final face in faces) {
      expect(face.vertices.toSet().length, 4);
      for (var index = 0; index < 4; index++) {
        final start = face.vertices[index];
        final end = face.vertices[(index + 1) % 4];
        final edge = start - end;
        expect(edge.length, closeTo(80, .0001));
        final endpoints = [
          '${start.x.round()}:${start.y.round()}:${start.z.round()}',
          '${end.x.round()}:${end.y.round()}:${end.z.round()}',
        ]..sort();
        edges.add(endpoints.join('|'));
      }
    }
    expect(edges, hasLength(12));
  });

  test(
    'completed voxel transform remains rigid while assigned colors remain fixed',
    () {
      final centers = sandboxVoxelCenters();
      final distance = (centers.first - centers.last).length;
      final rotatedDistance =
          (centers.first.rotateY(.8).rotateX(.2) -
                  centers.last.rotateY(.8).rotateX(.2))
              .length;
      expect(rotatedDistance, closeTo(distance, .0001));
      for (final center in centers) {
        expect(sandboxVoxelColor(center), sandboxVoxelColor(center));
      }
      expect(
        sandboxFaceShade(
          const SandboxVec3(0, 1, 0),
          const SandboxVec3(0, 1, 0),
        ),
        greaterThan(
          sandboxFaceShade(
            const SandboxVec3(1, 0, 0),
            const SandboxVec3(0, 1, 0),
          ),
        ),
      );
    },
  );

  test('matrix uses a stable center-out 36-cell order', () {
    final order = sandboxMatrixAssemblyOrder();
    expect(order, hasLength(36));
    expect(order.toSet(), hasLength(36));
    final firstDistance = math.max(
      (order.first ~/ 6 - 2.5).abs(),
      (order.first % 6 - 2.5).abs(),
    );
    final lastDistance = math.max(
      (order.last ~/ 6 - 2.5).abs(),
      (order.last % 6 - 2.5).abs(),
    );
    expect(firstDistance, lessThan(lastDistance));
    final centers = sandboxMatrixModuleCenters();
    expect(centers, hasLength(36));
    expect(sandboxMatrixAdjacencyLinks(), hasLength(60));
    final module = sandboxRectangularPrismFaces(centers.first, 13, 13, 7);
    expect(module, hasLength(6));
    expect(module.expand((face) => face.vertices).toSet(), hasLength(8));
  });

  test('fusion starts as six independent square panels and seals a cube', () {
    final initial = sandboxFusionCubeFaces(0);
    final finalFaces = sandboxFusionCubeFaces(1);
    expect(initial, hasLength(6));
    expect(finalFaces, hasLength(6));
    expect(
      initial
          .map((face) => face.vertices.reduce((a, b) => a + b) * .25)
          .toSet(),
      hasLength(6),
    );
    final vertices = finalFaces
        .expand((face) => face.vertices)
        .map(
          (point) => '${point.x.round()}:${point.y.round()}:${point.z.round()}',
        )
        .toSet();
    expect(vertices, hasLength(8));
    expect(sandboxCubeEdges(), hasLength(12));
  });

  test(
    'completed particle fields are deterministic and delayed until fade in',
    () {
      const field = SandboxParticleField(
        center: Offset(180, 140),
        spawnBounds: Rect.fromLTWH(110, 90, 140, 100),
        palette: [
          Color(0xff63d8ff),
          Color(0xffb5f3ff),
          Color(0xffa69aff),
          Color(0xffe8fcff),
        ],
        density: 18,
        motionBias: SandboxParticleMotionBias(8, 14, 6, 10),
        seed: 3102,
        elapsedTime: 0,
        depthLayer: SandboxParticleDepthLayer.side,
      );
      final initial = sandboxParticleVisuals(field);
      final replay = sandboxParticleVisuals(field.copyWith(elapsedTime: 0));
      final active = sandboxParticleVisuals(field.copyWith(elapsedTime: .35));
      expect(initial, isNotEmpty);
      expect(initial.every((particle) => particle.coreAlpha == 0), isTrue);
      expect(
        replay.map((particle) => particle.position),
        initial.map((particle) => particle.position),
      );
      final switched = sandboxParticleVisuals(
        SandboxParticleField(
          center: field.center,
          spawnBounds: field.spawnBounds,
          palette: field.palette,
          density: field.density,
          motionBias: field.motionBias,
          seed: 3103,
          elapsedTime: 0,
          depthLayer: field.depthLayer,
        ),
      );
      expect(
        switched.map((particle) => particle.position).toList(),
        isNot(equals(initial.map((particle) => particle.position).toList())),
      );
      expect(active.any((particle) => particle.coreAlpha > 0), isTrue);
    },
  );

  test('particle budgets and static reduced-motion field stay bounded', () {
    expect(sandboxParticleCount(BootSendSequenceConcept.assemblyMatrix), 12);
    expect(sandboxParticleCount(BootSendSequenceConcept.voxelIntegration), 18);
    expect(sandboxParticleCount(BootSendSequenceConcept.polyhedralFold), 15);
    const field = SandboxParticleField(
      center: Offset(180, 140),
      spawnBounds: Rect.fromLTWH(110, 90, 140, 100),
      palette: [
        Color(0xff63d8ff),
        Color(0xffb5f3ff),
        Color(0xffa69aff),
        Color(0xffe8fcff),
      ],
      density: 18,
      motionBias: SandboxParticleMotionBias(8, 14, 6, 10),
      seed: 3102,
      elapsedTime: 2,
      depthLayer: SandboxParticleDepthLayer.back,
    );
    final staticParticles = SandboxParticleDepthLayer.values
        .expand(
          (layer) => sandboxParticleVisuals(
            field.copyWith(depthLayer: layer),
            reducedMotion: true,
          ),
        )
        .toList();
    expect(staticParticles, hasLength(4));
    expect(
      staticParticles.every((particle) => particle.coreAlpha <= .35),
      isTrue,
    );
  });

  testWidgets('three selectors reset the comparison monitor and replay', (
    tester,
  ) async {
    await _pumpSandbox(tester);

    expect(find.text('ASSEMBLY MATRIX'), findsWidgets);
    expect(find.text('VOXEL INTEGRATION'), findsOneWidget);
    expect(find.text('POLYHEDRAL FOLD'), findsOneWidget);
    expect(find.text('MESSAGE ASSEMBLY'), findsOneWidget);
    await tester.tap(find.text('VOXEL INTEGRATION'));
    await tester.pump();
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('ARK'), findsOneWidget);
    expect(find.text('FALL'), findsOneWidget);
    expect(find.text('WALK-IN'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-send-sequence-monitor')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.tap(find.text('ARK'));
    await tester.pump();
    await tester.tap(find.text('WALK-IN'));
    await tester.pump();
    await tester.tap(find.text('SEND'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('boot-send-sequence-replay')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion renders each completed scene without ticking', (
    tester,
  ) async {
    await _pumpSandbox(tester, reducedMotion: true);
    expect(
      find.byKey(const ValueKey('boot-send-sequence-monitor')),
      findsOneWidget,
    );
    await tester.tap(find.text('POLYHEDRAL FOLD'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('monitor remains paintable at supported compact widths', (
    tester,
  ) async {
    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      await _pumpSandbox(tester, width: width);
      await tester.pump(const Duration(milliseconds: 5000));
      await tester.pump(const Duration(milliseconds: 7620));
      expect(
        find.byKey(const ValueKey('boot-send-sequence-monitor')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  for (final milliseconds in [0, 1700, 2880, 5200, 5450, 5700, 6200]) {
    testWidgets('ARK robot ${milliseconds}ms golden', (tester) async {
      await _pumpSandbox(tester);
      await tester.tap(find.text('VOXEL INTEGRATION'));
      await tester.pump();
      await tester.tap(find.text('ARK'));
      await tester.pump();
      await _pumpTimeline(
        tester,
        milliseconds,
        totalMilliseconds: sandboxPixelVoxelCycle(
          SandboxPixelBuilderFinale.fall,
        ).inMilliseconds,
      );
      await expectLater(
        find.byKey(const ValueKey('boot-send-sequence-monitor')),
        matchesGoldenFile('goldens/boot_send_voxel_ark_${milliseconds}ms.png'),
      );
    });
  }

  for (final appearance in SandboxRobotAppearance.values) {
    for (final finale in SandboxPixelBuilderFinale.values) {
      testWidgets('${appearance.name} ${finale.name} finale golden', (
        tester,
      ) async {
        await _pumpSandbox(tester);
        await tester.tap(find.text('VOXEL INTEGRATION'));
        await tester.pump();
        if (appearance == SandboxRobotAppearance.ark) {
          await tester.tap(find.text('ARK'));
          await tester.pump();
        }
        if (finale == SandboxPixelBuilderFinale.walkIn) {
          await tester.tap(find.text('WALK-IN'));
          await tester.pump();
        }
        await _pumpTimeline(
          tester,
          finale == SandboxPixelBuilderFinale.walkIn ? 4500 : 4000,
          totalMilliseconds: sandboxPixelVoxelCycle(finale).inMilliseconds,
        );
        await expectLater(
          find.byKey(const ValueKey('boot-send-sequence-monitor')),
          matchesGoldenFile(
            'goldens/pixel_finale_${appearance.name}_${finale.name}.png',
          ),
        );
      });
    }
  }

  for (final localMilliseconds in [930, 990, 1110, 1160, 1300]) {
    testWidgets('walk-in face tile ${localMilliseconds}ms golden', (
      tester,
    ) async {
      await _pumpSandbox(tester);
      await tester.tap(find.text('VOXEL INTEGRATION'));
      await tester.pump();
      await tester.tap(find.text('WALK-IN'));
      await tester.pump();
      await _pumpTimeline(
        tester,
        3313 + localMilliseconds,
        totalMilliseconds: sandboxPixelVoxelCycle(
          SandboxPixelBuilderFinale.walkIn,
        ).inMilliseconds,
      );
      await expectLater(
        find.byKey(const ValueKey('boot-send-sequence-monitor')),
        matchesGoldenFile(
          'goldens/pixel_finale_walk_in_${localMilliseconds}ms.png',
        ),
      );
    });
  }

  for (final mode in ['BRIEF', 'DEBRIEF', 'BACKUP']) {
    testWidgets('$mode completion icon golden', (tester) async {
      await _pumpSandbox(tester);
      await tester.tap(find.text('VOXEL INTEGRATION'));
      await tester.pump();
      await tester.tap(find.text(mode));
      await tester.pump();
      await _pumpTimeline(
        tester,
        12125,
        totalMilliseconds: sandboxPixelVoxelCycle(
          SandboxPixelBuilderFinale.fall,
        ).inMilliseconds,
      );
      await expectLater(
        find.byKey(const ValueKey('boot-send-sequence-monitor')),
        matchesGoldenFile(
          'goldens/boot_send_voxel_${mode.toLowerCase()}_icon.png',
        ),
      );
    });
  }

  for (final milliseconds in [
    900,
    1600,
    2100,
    2600,
    3200,
    3700,
    4200,
    4700,
    5100,
    5500,
    6000,
    6500,
  ]) {
    testWidgets('message assembly BRIEF ${milliseconds}ms golden', (
      tester,
    ) async {
      await _pumpSandbox(tester);
      await tester.tap(find.text('MESSAGE ASSEMBLY'));
      await tester.pump();
      await _pumpTimeline(tester, milliseconds, totalMilliseconds: 6500);
      await expectLater(
        find.byKey(const ValueKey('boot-send-sequence-monitor')),
        matchesGoldenFile(
          'goldens/message_assembly_brief_${milliseconds}ms.png',
        ),
      );
    });
  }

  for (final mode in ['BRIEF', 'DEBRIEF', 'BACKUP']) {
    testWidgets('message assembly $mode final golden', (tester) async {
      await _pumpSandbox(tester);
      await tester.tap(find.text('MESSAGE ASSEMBLY'));
      await tester.pump();
      await tester.tap(find.text(mode));
      await tester.pump();
      await _pumpTimeline(tester, 6200, totalMilliseconds: 6500);
      await expectLater(
        find.byKey(const ValueKey('boot-send-sequence-monitor')),
        matchesGoldenFile(
          'goldens/message_assembly_${mode.toLowerCase()}_final.png',
        ),
      );
    });
  }

  for (final concept in BootSendSequenceConcept.values) {
    for (final operation in TransferOperation.values) {
      final frames = concept == BootSendSequenceConcept.voxelIntegration
          ? const [
              0,
              250,
              1700,
              2880,
              4820,
              5200,
              5450,
              5700,
              5870,
              6200,
              6620,
              7720,
              10320,
              11620,
              12620,
            ]
          : concept == BootSendSequenceConcept.messageAssembly
          ? const [0, 900, 1600, 2100, 2600, 3700, 4200, 5100, 6000, 6500]
          : const [0, 800, 1600, 2800, 3500, 4500, 5300, 6000];
      final total = concept == BootSendSequenceConcept.voxelIntegration
          ? sandboxPixelVoxelCycle(
              SandboxPixelBuilderFinale.fall,
            ).inMilliseconds
          : concept == BootSendSequenceConcept.messageAssembly
          ? 6500
          : 6000;
      for (final milliseconds in frames) {
        testWidgets(
          '${concept.name} ${operation.name} ${milliseconds}ms golden',
          (tester) async {
            await _pumpSandbox(tester);
            if (concept != BootSendSequenceConcept.assemblyMatrix) {
              await tester.tap(find.text(_selectorText(concept)));
              await tester.pump();
            }
            if (operation == TransferOperation.send) {
              await tester.tap(find.text('SEND'));
              await tester.pump();
            }
            await _pumpTimeline(tester, milliseconds, totalMilliseconds: total);
            await expectLater(
              find.byKey(const ValueKey('boot-send-sequence-monitor')),
              matchesGoldenFile(
                'goldens/boot_send_${concept.name}_${operation.name}_${milliseconds}ms.png',
              ),
            );
          },
        );
      }
      testWidgets('${concept.name} ${operation.name} post-completion golden', (
        tester,
      ) async {
        await _pumpSandbox(tester);
        if (concept != BootSendSequenceConcept.assemblyMatrix) {
          await tester.tap(find.text(_selectorText(concept)));
          await tester.pump();
        }
        if (operation == TransferOperation.send) {
          await tester.tap(find.text('SEND'));
          await tester.pump();
        }
        final postCompletion =
            concept == BootSendSequenceConcept.voxelIntegration
            ? 12125
            : concept == BootSendSequenceConcept.messageAssembly
            ? 6500
            : 7200;
        await _pumpTimeline(tester, postCompletion, totalMilliseconds: total);
        await expectLater(
          find.byKey(const ValueKey('boot-send-sequence-monitor')),
          matchesGoldenFile(
            'goldens/boot_send_${concept.name}_${operation.name}_${postCompletion}ms.png',
          ),
        );
      });
    }
  }
}

Future<void> _pumpTimeline(
  WidgetTester tester,
  int milliseconds, {
  int totalMilliseconds = 6000,
}) async {
  if (milliseconds <= totalMilliseconds) {
    await tester.pump(Duration(milliseconds: milliseconds));
    return;
  }
  await tester.pump(Duration(milliseconds: totalMilliseconds - 1));
  // Deliver construction completion before advancing the completion-only
  // controller that owns post-build rotation and particles.
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(Duration(milliseconds: milliseconds - totalMilliseconds));
}

String _selectorText(BootSendSequenceConcept concept) => switch (concept) {
  BootSendSequenceConcept.assemblyMatrix => 'ASSEMBLY MATRIX',
  BootSendSequenceConcept.voxelIntegration => 'VOXEL INTEGRATION',
  BootSendSequenceConcept.polyhedralFold => 'POLYHEDRAL FOLD',
  BootSendSequenceConcept.messageAssembly => 'MESSAGE ASSEMBLY',
};

Future<void> _pumpSandbox(
  WidgetTester tester, {
  bool reducedMotion = false,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: const Scaffold(body: BootSendSequenceSandbox()),
      ),
    ),
  );
  await tester.pump();
}
