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

  const frames = [0, 1100, 2000, 2800, 3600, 4400, 5000, 6000, 6600, 8000];
  for (final concept in BootSendSequenceConcept.values) {
    for (final milliseconds in frames) {
      testWidgets('${concept.name} ${milliseconds}ms golden', (tester) async {
        await _pumpSandbox(tester);
        if (concept != BootSendSequenceConcept.assemblyMatrix) {
          await tester.tap(find.text(_selectorText(concept)));
          await tester.pump();
        }
        await tester.pump(Duration(milliseconds: milliseconds));
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
