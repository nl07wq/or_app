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
    await tester.tap(find.text('VOXEL INTEGRATION'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('boot-send-sequence-monitor')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 2800));
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
      expect(
        find.byKey(const ValueKey('boot-send-sequence-monitor')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  const frames = [
    0,
    600,
    1200,
    1800,
    2400,
    3000,
    3500,
    4100,
    5000,
    6000,
    7200,
    8400,
  ];
  for (final concept in BootSendSequenceConcept.values) {
    for (final milliseconds in frames) {
      testWidgets('${concept.name} ${milliseconds}ms golden', (tester) async {
        await _pumpSandbox(tester);
        if (concept != BootSendSequenceConcept.assemblyMatrix) {
          await tester.tap(find.text(_selectorText(concept)));
          await tester.pump();
        }
        await _pumpTimeline(tester, milliseconds);
        await expectLater(
          find.byKey(const ValueKey('boot-send-sequence-monitor')),
          matchesGoldenFile(
            'goldens/boot_send_${concept.name}_${milliseconds}ms.png',
          ),
        );
      });
    }
  }
}

Future<void> _pumpTimeline(WidgetTester tester, int milliseconds) async {
  if (milliseconds <= 6000) {
    await tester.pump(Duration(milliseconds: milliseconds));
    return;
  }
  await tester.pump(const Duration(milliseconds: 5999));
  // Deliver construction completion before advancing the completion-only
  // controller that owns post-build rotation and particles.
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(Duration(milliseconds: milliseconds - 6000));
}

String _selectorText(BootSendSequenceConcept concept) => switch (concept) {
  BootSendSequenceConcept.assemblyMatrix => 'ASSEMBLY MATRIX',
  BootSendSequenceConcept.voxelIntegration => 'VOXEL INTEGRATION',
  BootSendSequenceConcept.polyhedralFold => 'POLYHEDRAL FOLD',
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
