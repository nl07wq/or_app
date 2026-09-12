import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/services/body_map_geometry_tuner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const side = 'front';
  const leftId = 'front-shoulder-left';
  const rightId = 'front-shoulder-right';
  final leftPath = Path()..addOval(const Rect.fromLTWH(55, 75, 18, 24));
  final rightPath = Path()..addOval(const Rect.fromLTWH(127, 75, 18, 24));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('creates a baseline CURRENT draft and valid paths for every preset', () {
    final controller = BodyMapGeometryTunerController(
      baselineCommit: 'baseline',
    );
    final baseline = controller.pathFor(
      side: side,
      regionId: leftId,
      basePath: leftPath,
    );
    expect(baseline.contains(const Offset(64, 87)), isTrue);
    final draft = controller.draftFor(side, leftId)!;
    expect(draft.shape, BodyMapGeometryShape.current);
    expect(draft.scaleX, 1);
    expect(draft.scaleY, 1);

    for (final shape in BodyMapGeometryShape.values) {
      controller.update(draft.copyWith(shape: shape));
      final path = controller.pathFor(
        side: side,
        regionId: leftId,
        basePath: leftPath,
      );
      expect(path.getBounds().isEmpty, isFalse, reason: shape.name);
      expect(
        path.contains(path.getBounds().center),
        isTrue,
        reason: shape.name,
      );
    }
  });

  test(
    'linked bilateral edit mirrors x and rotation while preserving size',
    () {
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'baseline',
      );
      controller
        ..pathFor(side: side, regionId: leftId, basePath: leftPath)
        ..pathFor(side: side, regionId: rightId, basePath: rightPath);
      final left = controller.draftFor(side, leftId)!;
      controller.update(
        left.copyWith(x: 70, width: 22, height: 30, rotationDeg: -20),
      );
      final right = controller.draftFor(side, rightId)!;
      expect(right.x, 130);
      expect(right.width, 22);
      expect(right.height, 30);
      expect(right.rotationDeg, 20);
    },
  );

  test(
    'reset, persistence, and deterministic copy retain only changed drafts',
    () async {
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'abc123',
      );
      controller.pathFor(side: side, regionId: leftId, basePath: leftPath);
      final changed = controller.draftFor(side, leftId)!;
      controller.update(
        changed.copyWith(shape: BodyMapGeometryShape.ellipse, x: 68),
      );
      await Future<void>.delayed(Duration.zero);

      final reloaded = BodyMapGeometryTunerController(baselineCommit: 'abc123');
      await reloaded.load();
      reloaded.pathFor(side: side, regionId: leftId, basePath: leftPath);
      final restored = reloaded.draftFor(side, leftId)!;
      expect(restored.shape, BodyMapGeometryShape.ellipse);
      expect(restored.x, 68);

      final output = reloaded.copyAllChanges({
        BodyMapGeometryTunerController.keyFor(side, leftId): leftPath
            .getBounds(),
      });
      expect(output, contains('baselineCommit: abc123'));
      expect(output, contains('regionId: $leftId'));
      expect(output, contains('shape: ELLIPSE'));
      expect(output, contains('x: 68.00'));

      reloaded.resetRegion(side, leftId);
      reloaded.pathFor(side: side, regionId: leftId, basePath: leftPath);
      final reset = reloaded.draftFor(side, leftId)!;
      expect(reloaded.isChanged(reset, leftPath.getBounds()), isFalse);
    },
  );

  test(
    'copy-all output follows the prescribed front then back region order',
    () {
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'baseline',
      );
      const glute = 'back-glutes-left';
      const calf = 'back-calves-left';
      controller
        ..pathFor(side: 'back', regionId: calf, basePath: leftPath)
        ..pathFor(side: 'back', regionId: glute, basePath: leftPath)
        ..pathFor(side: side, regionId: leftId, basePath: leftPath);
      controller
        ..update(controller.draftFor('back', calf)!.copyWith(x: 71))
        ..update(controller.draftFor('back', glute)!.copyWith(x: 72))
        ..update(controller.draftFor(side, leftId)!.copyWith(x: 73));
      final output = controller.copyAllChanges({
        BodyMapGeometryTunerController.keyFor('back', calf): leftPath
            .getBounds(),
        BodyMapGeometryTunerController.keyFor('back', glute): leftPath
            .getBounds(),
        BodyMapGeometryTunerController.keyFor(side, leftId): leftPath
            .getBounds(),
      });
      expect(output.indexOf(leftId), lessThan(output.indexOf(glute)));
      expect(output.indexOf(glute), lessThan(output.indexOf(calf)));
    },
  );

  test(
    'preserves a mismatched baseline as stale without applying it',
    () async {
      final old = BodyMapGeometryTunerController(baselineCommit: '2fb726a');
      old.pathFor(side: side, regionId: leftId, basePath: leftPath);
      old.update(old.draftFor(side, leftId)!.copyWith(x: 70));
      await Future<void>.delayed(Duration.zero);

      final baked = BodyMapGeometryTunerController(baselineCommit: 'baked-v1');
      await baked.load();
      final neutral = baked.pathFor(
        side: side,
        regionId: leftId,
        basePath: leftPath,
      );
      expect(baked.hasStaleDraft, isTrue);
      expect(neutral.contains(const Offset(64, 87)), isTrue);
      expect(baked.copyStaleDraft(), contains('draftBaselineCommit: 2fb726a'));
    },
  );

  test(
    'composite trapezius keeps two components as one visible hit region',
    () {
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'baked',
      );
      const id = 'back-trapezius';
      final diamond = Path()
        ..moveTo(100, 62)
        ..lineTo(115, 86)
        ..lineTo(100, 110)
        ..lineTo(85, 86)
        ..close();
      controller.pathFor(side: 'back', regionId: id, basePath: diamond);
      expect(
        controller.addComponent('back', id, BodyMapGeometryShape.rect),
        isTrue,
      );
      final draft = controller.draftFor('back', id)!;
      controller.updateComponent(
        'back',
        id,
        1,
        draft.effectiveComponents[1].copyWith(y: 68, width: 20),
      );
      final path = controller.pathFor(
        side: 'back',
        regionId: id,
        basePath: diamond,
      );
      expect(path.contains(const Offset(100, 86)), isTrue);
      expect(path.contains(const Offset(100, 68)), isTrue);
      final copied = controller.copyRegion(controller.draftFor('back', id)!);
      expect(copied, contains('shape: COMPOSITE'));
      expect(copied, contains('component-1'));
      expect(controller.deleteComponent('back', id, 1), isTrue);
      expect(controller.deleteComponent('back', id, 0), isFalse);
    },
  );

  test(
    'exports a locked composite region through copy-region and copy-all',
    () {
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'composite-export',
      );
      const id = 'back-trapezius';
      final diamond = Path()
        ..moveTo(100, 62)
        ..lineTo(115, 86)
        ..lineTo(100, 110)
        ..lineTo(85, 86)
        ..close();
      controller.pathFor(side: 'back', regionId: id, basePath: diamond);
      expect(
        controller.addComponent('back', id, BodyMapGeometryShape.rect),
        isTrue,
      );
      final composite = controller.draftFor('back', id)!;
      controller.update(composite.copyWith(locked: true));
      final locked = controller.draftFor('back', id)!;

      final region = controller.copyRegion(locked);
      final all = controller.copyAllChanges({
        BodyMapGeometryTunerController.keyFor('back', id): diamond.getBounds(),
      });
      for (final output in <String>[region, all]) {
        expect(output, contains('shape: COMPOSITE'));
        expect(output, contains('mirrorLinked: true'));
        expect(output, contains('componentId: component-0'));
        expect(output, contains('componentId: component-1'));
        expect(output, contains('shape: RECT'));
        expect(output, contains('locked: true'));
      }
      expect(all.split('regionId: $id').length - 1, 1);
    },
  );

  test('copy-all preserves mixed locked single and composite drafts', () {
    final controller = BodyMapGeometryTunerController(
      baselineCommit: 'mixed-export',
    );
    const singleId = 'front-shoulder-left';
    const compositeId = 'back-trapezius';
    final diamond = Path()
      ..moveTo(100, 62)
      ..lineTo(115, 86)
      ..lineTo(100, 110)
      ..lineTo(85, 86)
      ..close();
    controller
      ..pathFor(side: 'front', regionId: singleId, basePath: leftPath)
      ..pathFor(side: 'back', regionId: compositeId, basePath: diamond);
    controller.update(
      controller
          .draftFor('front', singleId)!
          .copyWith(shape: BodyMapGeometryShape.ellipse, locked: true),
    );
    expect(
      controller.addComponent(
        'back',
        compositeId,
        BodyMapGeometryShape.roundedRect,
      ),
      isTrue,
    );
    controller.update(
      controller.draftFor('back', compositeId)!.copyWith(locked: true),
    );

    final output = controller.copyAllChanges({
      BodyMapGeometryTunerController.keyFor('front', singleId): leftPath
          .getBounds(),
      BodyMapGeometryTunerController.keyFor('back', compositeId): diamond
          .getBounds(),
    });
    expect(output.indexOf(singleId), lessThan(output.indexOf(compositeId)));
    expect(output, contains('shape: ELLIPSE'));
    expect(output.split('regionId: $compositeId').length - 1, 1);
    expect(output, contains('shape: COMPOSITE'));
    expect(output, contains('shape: ROUNDED_RECT'));
  });

  test('persists composite components without changing their export', () async {
    final controller = BodyMapGeometryTunerController(
      baselineCommit: 'persist-composite',
    );
    const id = 'back-trapezius';
    final diamond = Path()
      ..moveTo(100, 62)
      ..lineTo(115, 86)
      ..lineTo(100, 110)
      ..lineTo(85, 86)
      ..close();
    controller.pathFor(side: 'back', regionId: id, basePath: diamond);
    expect(
      controller.addComponent('back', id, BodyMapGeometryShape.rect),
      isTrue,
    );
    await Future<void>.delayed(Duration.zero);

    final reloaded = BodyMapGeometryTunerController(
      baselineCommit: 'persist-composite',
    );
    await reloaded.load();
    reloaded.pathFor(side: 'back', regionId: id, basePath: diamond);
    final restored = reloaded.draftFor('back', id)!;
    expect(restored.effectiveComponents, hasLength(2));
    expect(restored.effectiveComponents[1].shape, BodyMapGeometryShape.rect);
    expect(
      reloaded.copyAllChanges({
        BodyMapGeometryTunerController.keyFor('back', id): diamond.getBounds(),
      }),
      contains('shape: COMPOSITE'),
    );
  });
}
